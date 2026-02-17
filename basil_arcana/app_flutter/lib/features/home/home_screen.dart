import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_version.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_bridge.dart';
import '../../core/telegram/telegram_user_profile.dart';
import '../../core/telemetry/web_error_reporter.dart';
import '../../core/utils/pdf_file_actions.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../data/repositories/energy_topup_repository.dart';
import '../../data/repositories/home_insights_repository.dart';
import '../../data/repositories/sofia_consent_repository.dart';
import '../../state/providers.dart';
import '../../state/reading_flow_controller.dart';
import '../cards/cards_screen.dart';
import '../astro/compatibility_flow_screen.dart';
import '../astro/natal_chart_flow_screen.dart';
import '../history/query_history_screen.dart';
import 'self_analysis_report_service.dart';
import 'widgets/self_analysis_report_cta_section.dart';
import '../settings/settings_screen.dart';
import '../spread/spread_screen.dart';

const String _settingsBoxName = 'settings';
const String _sofiaConsentKey = 'sofiaConsentDecision';
const String _sofiaConsentAccepted = 'accepted';
const String _sofiaConsentRejected = 'rejected';
const String _splashOnboardingSeenKey = 'splashOnboardingSeenV1';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionKey = GlobalKey();
  ProviderSubscription<ReadingFlowState>? _readingFlowSubscription;
  _SofiaConsentState _sofiaConsentState = _SofiaConsentState.undecided;
  bool _sendingConsent = false;
  bool _hasQueryHistory = false;
  bool _loadingStreak = true;
  HomeStreakStats _streakStats = HomeStreakStats.empty;
  String? _dailyCardInterpretation;
  String? _dailyCardInterpretationCardId;
  bool _reportFlowInFlight = false;
  bool _loadingReportEntitlements = false;
  bool _hasYearlyReportAccess = false;
  bool _didRequestOnboarding = false;
  late final AnimationController _fieldGlowController;
  late final AnimationController _titleShimmerController;

  @override
  void initState() {
    super.initState();
    _fieldGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _titleShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _sofiaConsentState = _readSofiaConsentState();
    _focusNode.addListener(_handleFocusChange);
    final initialQuestion = ref.read(readingFlowControllerProvider).question;
    if (initialQuestion.isNotEmpty) {
      _controller.text = initialQuestion;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingIfNeeded();
    });
    _loadStreakStats();
    _loadReportEntitlements();
    _loadQueryHistoryAvailability();
    _readingFlowSubscription = ref.listenManual<ReadingFlowState>(
      readingFlowControllerProvider,
      (prev, next) {
        if (_controller.text == next.question) {
          return;
        }
        _controller.value = _controller.value.copyWith(
          text: next.question,
          selection: TextSelection.collapsed(offset: next.question.length),
          composing: TextRange.empty,
        );
        setState(() {});
      },
    );
  }

  Future<void> _loadQueryHistoryAvailability() async {
    try {
      final history =
          await ref.read(queryHistoryRepositoryProvider).fetchRecent(limit: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasQueryHistory = history.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasQueryHistory = false;
      });
    }
  }

  Future<void> _loadStreakStats() async {
    if (!_loadingStreak) {
      setState(() {
        _loadingStreak = true;
      });
    }
    try {
      final streak =
          await ref.read(homeInsightsRepositoryProvider).fetchStreakStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _streakStats = streak;
        _loadingStreak = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingStreak = false;
      });
    }
  }

  Future<void> _loadReportEntitlements() async {
    if (_loadingReportEntitlements) {
      return;
    }
    setState(() {
      _loadingReportEntitlements = true;
    });
    try {
      final dashboard =
          await ref.read(userDashboardRepositoryProvider).fetchDashboard();
      final hasYearly = dashboard.services.any((service) {
        if (service.type != 'year_unlimited' && service.type != 'unlimited') {
          return false;
        }
        if (service.status.isNotEmpty &&
            service.status.toLowerCase() != 'active') {
          return false;
        }
        final expiresAt = service.expiresAt;
        return expiresAt == null || expiresAt.isAfter(DateTime.now());
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _hasYearlyReportAccess = hasYearly;
        _loadingReportEntitlements = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReportEntitlements = false;
      });
    }
  }

  bool _isReportFreeByEntitlements() {
    if (_streakStats.awarenessLocked) {
      return true;
    }
    final energy = ref.read(energyProvider);
    final ent = UserEntitlements(
      promoCodes: energy.promoCodeActive ? {'LUCY100'} : const {},
      hasActiveYearlySubscription: _hasYearlyReportAccess,
    );
    return isReportFree(ent);
  }

  ({DateTime from, DateTime to}) _reportWindow() {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    return (from: from, to: to);
  }

  Future<void> _onGenerateReportTap({
    required _HomeStreakCopy copy,
    required DeckType selectedDeck,
  }) async {
    if (_reportFlowInFlight) {
      return;
    }
    setState(() {
      _reportFlowInFlight = true;
    });
    try {
      final l10n = AppLocalizations.of(context);
      final window = _reportWindow();
      final readings = ref.read(readingsRepositoryProvider).getReadings();
      final allTimeStats = ref.read(cardStatsRepositoryProvider).getAllCounts();
      final reportService = ref.read(selfAnalysisReportServiceProvider);
      final samples = reportService.extractRecentSamples(
        readings: readings,
        fromDate: window.from,
        toDate: window.to,
        selectedDeck: selectedDeck,
      );
      final statsCount = reportService.countDeckCardsInStats(
        allTimeStats: allTimeStats,
        selectedDeck: selectedDeck,
      );
      final effectiveCount = max(samples.length, statsCount);
      if (effectiveCount < SelfAnalysisReportService.minCardsThreshold) {
        await _showInsufficientDataDialog(copy);
        return;
      }

      final isFree = _isReportFreeByEntitlements();
      if (!isFree) {
        final confirmed = await _showReportConfirmationDialog(copy);
        if (!confirmed || !mounted) {
          return;
        }
        final paid = await _purchaseSelfAnalysisReportAccess(l10n: l10n);
        if (!paid || !mounted) {
          return;
        }
      }

      final userId =
          readTelegramUserProfile()?.userId.toString() ?? 'telegram_unknown';
      final locale = Localizations.localeOf(context).languageCode;
      final report = await reportService.generateSelfAnalysisReport(
        userId: userId,
        fromDate: window.from,
        toDate: window.to,
        readings: readings,
        fallbackAllTimeStats: allTimeStats,
        selectedDeck: selectedDeck,
        locale: locale,
      );
      if (!mounted) {
        return;
      }
      await _showReportReadyDialog(copy: copy, report: report);
    } catch (error) {
      WebErrorReporter.instance
          .report('SelfAnalysisReportFlowError: ${error.toString()}');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.reportGenerateFailed)),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _reportFlowInFlight = false;
      });
    }
  }

  Future<void> _showInsufficientDataDialog(_HomeStreakCopy copy) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(copy.reportInsufficientTitle),
          content: Text(copy.reportInsufficientBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(copy.closeLabel),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showReportConfirmationDialog(_HomeStreakCopy copy) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.reportConfirmTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  copy.reportConfirmBody,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppPrimaryButton(
                        label: copy.reportConfirmContinue,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppGhostButton(
                        label: copy.reportConfirmCancel,
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return accepted == true;
  }

  Future<bool> _purchaseSelfAnalysisReportAccess({
    required AppLocalizations l10n,
  }) async {
    if (!TelegramBridge.isAvailable) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.energyTopUpOnlyInTelegram)),
      );
      return false;
    }
    try {
      final topUpRepo = ref.read(energyTopUpRepositoryProvider);
      final invoice =
          await topUpRepo.createInvoice(EnergyPackId.selfAnalysisReport);
      final status = await TelegramBridge.openInvoice(invoice.invoiceLink);
      try {
        await topUpRepo.confirmInvoiceResult(
          payload: invoice.payload,
          status: status,
        );
      } catch (_) {}
      if (!mounted) {
        return false;
      }
      switch (status) {
        case 'paid':
          return true;
        case 'cancelled':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.energyTopUpPaymentCancelled)),
          );
          return false;
        case 'pending':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.energyTopUpPaymentPending)),
          );
          return false;
        case 'failed':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.energyTopUpPaymentFailed)),
          );
          return false;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
          );
          return false;
      }
    } on EnergyTopUpRepositoryException {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
      );
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
      );
      return false;
    }
  }

  Future<void> _showReportReadyDialog({
    required _HomeStreakCopy copy,
    required SelfAnalysisReportResult report,
  }) async {
    final fileDate = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = 'self_analysis_report_$fileDate.pdf';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.reportReadyTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  report.summarySnippet,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Builder(
                  builder: (_) {
                    final lang =
                        Localizations.localeOf(sheetContext).languageCode;
                    final exportLabel = lang == 'ru'
                        ? 'Скачать / поделиться PDF'
                        : lang == 'kk'
                            ? 'PDF жүктеу / бөлісу'
                            : 'Download / share PDF';
                    return AppPrimaryButton(
                      label: exportLabel,
                      onPressed: () async {
                        await exportPdfFile(
                          bytes: report.pdfBytes,
                          fileName: fileName,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _SofiaConsentState _readSofiaConsentState() {
    final box = Hive.box<String>(_settingsBoxName);
    final value = box.get(_sofiaConsentKey) ?? '';
    if (value == _sofiaConsentAccepted) {
      return _SofiaConsentState.accepted;
    }
    if (value == _sofiaConsentRejected) {
      return _SofiaConsentState.rejected;
    }
    return _SofiaConsentState.undecided;
  }

  Future<void> _setSofiaConsentState(_SofiaConsentState nextState) async {
    if (_sendingConsent) {
      return;
    }
    final box = Hive.box<String>(_settingsBoxName);
    final previous = _sofiaConsentState;
    setState(() {
      _sofiaConsentState = nextState;
      _sendingConsent = true;
    });
    try {
      await box.put(_sofiaConsentKey, nextState.storageValue);
      final decision = nextState == _SofiaConsentState.accepted
          ? SofiaConsentDecision.accepted
          : SofiaConsentDecision.rejected;
      await ref.read(sofiaConsentRepositoryProvider).submitDecision(decision);
    } catch (_) {
      await box.put(_sofiaConsentKey, previous.storageValue);
      if (!mounted) {
        return;
      }
      setState(() {
        _sofiaConsentState = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_SofiaCopy.resolve(context).submitError),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingConsent = false;
      });
    }
  }

  Future<void> _showSofiaInfoModal() async {
    final copy = _SofiaCopy.resolve(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final showActions = _sofiaConsentState == _SofiaConsentState.undecided;
        final isConsentFlow = showActions;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy.modalTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: copy.closeLabel,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConsentFlow
                        ? copy.consentModalBody
                        : copy.profileModalBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.85),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isConsentFlow
                        ? copy.consentModalScope
                        : copy.profileModalScope,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 14),
                  const SofiaPromoCard(compact: true),
                  if (showActions) ...[
                    const SizedBox(height: 14),
                    AppPrimaryButton(
                      label: copy.acceptButton,
                      onPressed: _sendingConsent
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await _setSofiaConsentState(
                                _SofiaConsentState.accepted,
                              );
                            },
                    ),
                    const SizedBox(height: 10),
                    AppGhostButton(
                      label: copy.rejectButton,
                      onPressed: _sendingConsent
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await _setSofiaConsentState(
                                _SofiaConsentState.rejected,
                              );
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOnboardingIfNeeded() async {
    if (!mounted || _didRequestOnboarding) {
      return;
    }
    _didRequestOnboarding = true;
    final box = Hive.box<String>(_settingsBoxName);
    final alreadySeen = (box.get(_splashOnboardingSeenKey) ?? '').isNotEmpty;
    if (alreadySeen || !mounted) {
      return;
    }
    final copy = _HomeOnboardingCopy.resolve(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Onboarding',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                backgroundColor: colorScheme.surface.withValues(alpha: 0.98),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.38),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: Theme.of(dialogContext)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        copy.subtitle,
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                      ),
                      const SizedBox(height: 16),
                      _OnboardingBullet(
                        title: copy.itemLenormand,
                        subtitle: copy.itemLenormandHint,
                      ),
                      const SizedBox(height: 8),
                      _OnboardingBullet(
                        title: copy.itemCompatibility,
                        subtitle: copy.itemCompatibilityHint,
                      ),
                      const SizedBox(height: 8),
                      _OnboardingBullet(
                        title: copy.itemNatal,
                        subtitle: copy.itemNatalHint,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await box.put(_splashOnboardingSeenKey, 'seen');
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(copy.closeButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _readingFlowSubscription?.close();
    _fieldGlowController.dispose();
    _titleShimmerController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyExample(String example) {
    _controller.text = example;
    ref.read(readingFlowControllerProvider.notifier).setQuestion(example);
    setState(() {});
  }

  void _clearQuestion() {
    _controller.clear();
    ref.read(readingFlowControllerProvider.notifier).setQuestion('');
    setState(() {});
  }

  void _handleFocusChange() {
    setState(() {});
    if (!_focusNode.hasFocus) {
      return;
    }
    final context = _questionKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final deckId = ref.watch(deckProvider);
    final cardsAsync = ref.watch(cardsAllProvider);
    final quickTopics = [
      l10n.homeQuickTopicRelationships,
      l10n.homeQuickTopicMoney,
      l10n.homeQuickTopicFuture,
      l10n.homeQuickTopicGrowth,
      l10n.homeQuickTopicWeatherTomorrow,
    ];
    final hasQuestion = _controller.text.trim().isNotEmpty;
    final copy = _SofiaCopy.resolve(context);
    final featureCopy = _HomeFeatureCopy.resolve(context);
    final streakCopy = _HomeStreakCopy.resolve(context);
    final deckHint = _deckHint(l10n, deckId);
    final cards = cardsAsync.maybeWhen(
        data: (list) => list, orElse: () => const <CardModel>[]);
    final topCards = _topCards(cards);
    final dailyCard = _resolveDailyCard(cards, deckId);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primaryColor = colorScheme.primary;
    final disabledColor = Color.lerp(primaryColor, colorScheme.surface, 0.45)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompactScreen = screenHeight < 760;
    final questionMinLines = isCompactScreen ? 3 : 5;
    final questionMaxLines = isCompactScreen ? 4 : 6;

    return Scaffold(
      appBar: buildEnergyTopBar(
        context,
        showBack: false,
        onSettings: () {
          Navigator.pushNamed(
            context,
            SettingsScreen.routeName,
            arguments: const AppRouteConfig(showBackButton: true),
          ).then((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _sofiaConsentState = _readSofiaConsentState();
            });
          });
        },
        leadingFallback: const Center(
          child: Text(
            '🔮',
            style: TextStyle(fontSize: 21),
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _ShimmerTitle(
                            text: l10n.homeDescription,
                            animation: _titleShimmerController,
                            baseStyle: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.86),
                                  fontWeight: FontWeight.w400,
                                ),
                            shimmerColor:
                                colorScheme.primary.withValues(alpha: 0.95),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _fieldGlowController,
                      builder: (context, child) {
                        final pulse =
                            0.15 + (_fieldGlowController.value * 0.85);
                        return Container(
                          key: _questionKey,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.34 + (0.28 * pulse)),
                                blurRadius: 34 + (24 * pulse),
                                spreadRadius: 2 + (3 * pulse),
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.16 + (0.2 * pulse)),
                                blurRadius: 60 + (36 * pulse),
                                spreadRadius: 3 + (4 * pulse),
                                offset: const Offset(0, 0),
                              ),
                            ],
                            border: Border.all(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.72 + (0.2 * pulse)),
                              width: 2.1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: questionMaxLines,
                                minLines: questionMinLines,
                                decoration: InputDecoration(
                                  hintText: l10n.homeQuestionPlaceholder,
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    48,
                                    isCompactScreen ? 34 : 40,
                                  ),
                                  alignLabelWithHint: true,
                                ),
                                onChanged: (value) {
                                  ref
                                      .read(
                                        readingFlowControllerProvider.notifier,
                                      )
                                      .setQuestion(value);
                                  setState(() {});
                                },
                              ),
                              Positioned(
                                left: 14,
                                bottom: 12,
                                child: Text(
                                  deckHint,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.62),
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                              ),
                              if (hasQuestion)
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _InlineIconButton(
                                        icon: Icons.close,
                                        tooltip: l10n.homeClearQuestionTooltip,
                                        onTap: _clearQuestion,
                                      ),
                                      const SizedBox(width: 8),
                                      _InlineIconButton(
                                        icon: Icons.arrow_forward,
                                        tooltip: l10n.homeContinueButton,
                                        onTap: () =>
                                            _handlePrimaryAction(hasQuestion),
                                        backgroundColor: colorScheme.primary
                                            .withValues(alpha: 0.2),
                                        iconColor: colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            quickTopics.length + (_hasQueryHistory ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          if (_hasQueryHistory && index == 0) {
                            return _RecentQueriesChip(
                              tooltip: l10n.homeRecentQueriesButton,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  QueryHistoryScreen.routeName,
                                ).then((_) => _loadQueryHistoryAvailability());
                              },
                            );
                          }
                          final topic =
                              quickTopics[_hasQueryHistory ? index - 1 : index];
                          return _ExampleChip(
                            text: topic,
                            onTap: () => _applyExample(topic),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _FeatureSquareCard(
                            assetIconPath: 'assets/icon/home_natal.svg',
                            iconOffsetY: 1.5,
                            title: featureCopy.natalTitle,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings:
                                      appRouteSettings(showBackButton: true),
                                  builder: (_) => const NatalChartFlowScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FeatureSquareCard(
                            assetIconPath: 'assets/icon/home_compatibility.svg',
                            title: featureCopy.compatibilityTitle,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings:
                                      appRouteSettings(showBackButton: true),
                                  builder: (_) =>
                                      const CompatibilityFlowScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FeatureSquareCard(
                            assetIconPath: 'assets/icon/home_library.svg',
                            title: featureCopy.libraryTitle,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings:
                                      appRouteSettings(showBackButton: true),
                                  builder: (_) => const CardsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryFeatureCard(
                            assetIconPath:
                                'assets/icon/home_streak_electric.svg',
                            pulseBadge: false,
                            flickerIcon: !_loadingStreak &&
                                _streakStats.currentStreakDays > 1,
                            title: _loadingStreak
                                ? streakCopy.tileLoadingTitle
                                : streakCopy
                                    .tileTitle(_streakStats.currentStreakDays),
                            subtitle: _loadingStreak
                                ? streakCopy.tileLoadingSubtitle
                                : streakCopy.tileSubtitle,
                            onTap: () => _showStreakModal(
                              copy: streakCopy,
                              topCards: topCards,
                              cards: cards,
                              selectedDeck: deckId,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SecondaryFeatureCard(
                            assetIconPath: 'assets/icon/home_daily.svg',
                            title: streakCopy.dailyCardTileTitle,
                            subtitle:
                                dailyCard?.name ?? streakCopy.dailyCardFallback,
                            onTap: dailyCard == null
                                ? null
                                : () => _showDailyCardModal(
                                      dailyCard: dailyCard,
                                      copy: streakCopy,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sofiaConsentState == _SofiaConsentState.undecided)
                _SofiaConsentCard(
                  copy: copy,
                  isBusy: _sendingConsent,
                  compact: true,
                  onOpenInfo: _showSofiaInfoModal,
                  onAccept: () => _setSofiaConsentState(
                    _SofiaConsentState.accepted,
                  ),
                  onReject: () => _setSofiaConsentState(
                    _SofiaConsentState.rejected,
                  ),
                )
              else
                _SofiaInfoCard(
                  copy: copy,
                  compact: true,
                  onTap: _showSofiaInfoModal,
                ),
              const SizedBox(height: 10),
              _PrimaryActionButton(
                isActive: hasQuestion,
                primaryColor: primaryColor,
                disabledColor: disabledColor,
                label: l10n.homeContinueButton,
                onPressed: () => _handlePrimaryAction(hasQuestion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_TopCardStat> _topCards(List<CardModel> cards) {
    final stats = ref.read(cardStatsRepositoryProvider).getAllCounts();
    if (stats.isEmpty || cards.isEmpty) {
      return const [];
    }
    final byId = {for (final card in cards) card.id: card};
    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = <_TopCardStat>[];
    for (final entry in entries) {
      final card = byId[entry.key];
      final name = card?.name ?? entry.key;
      top.add(
        _TopCardStat(
          name: name,
          count: entry.value,
          imageUrl: card?.imageUrl ?? '',
        ),
      );
      if (top.length == 3) {
        break;
      }
    }
    return top;
  }

  CardModel? _resolveDailyCard(List<CardModel> cards, DeckType deckId) {
    if (cards.isEmpty) {
      return null;
    }
    final filtered = cards
        .where(
          (card) => matchesPrimaryDeckSelection(
            selectedDeck: deckId,
            cardDeck: card.deckId,
          ),
        )
        .toList();
    final strictDeck =
        deckId == DeckType.lenormand || deckId == DeckType.crowley;
    if (strictDeck && filtered.isEmpty) {
      return null;
    }
    final source = filtered.isEmpty ? cards : filtered;
    final now = DateTime.now().toUtc();
    final dayKey =
        DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    final index = Random(dayKey).nextInt(source.length);
    return source[index];
  }

  _EnergyProfileData _buildEnergyProfile({
    required List<CardModel> cards,
    required List<_TopCardStat> topCards,
    required DeckType selectedDeck,
  }) {
    final readings = ref.read(readingsRepositoryProvider).getReadings();
    final allTimeStats = ref.read(cardStatsRepositoryProvider).getAllCounts();
    final cardById = <String, CardModel>{
      for (final card in cards) canonicalCardId(card.id): card,
    };
    final now = DateTime.now();
    final sampled = <_ProfileEntry>[];

    for (final reading in readings) {
      final ageDays = now.difference(reading.createdAt).inDays;
      if (ageDays > 90) {
        continue;
      }
      for (final drawn in reading.drawnCards) {
        final normalizedId = canonicalCardId(drawn.cardId);
        if (!_matchesProfileDeck(normalizedId, selectedDeck)) {
          continue;
        }
        sampled.add(
          _ProfileEntry(
            cardId: normalizedId,
            cardName: drawn.cardName.trim(),
            createdAt: reading.createdAt,
          ),
        );
      }
    }

    sampled.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final cardsWindow = sampled.take(30).toList();
    if (cardsWindow.isEmpty) {
      return _buildEnergyProfileFromAllTimeStats(
        allTimeStats: allTimeStats,
        cardById: cardById,
        topCards: topCards,
        selectedDeck: selectedDeck,
      );
    }

    final suitWeights = <_ElementKind, double>{
      _ElementKind.wands: 0,
      _ElementKind.cups: 0,
      _ElementKind.swords: 0,
      _ElementKind.pentacles: 0,
    };
    final frequencyWeighted = <String, double>{};
    final frequencyNames = <String, String>{};
    final monthlyRepeats = <String, int>{};

    double majorWeight = 0;
    double totalTarotWeight = 0;

    for (final entry in cardsWindow) {
      final ageDays = now.difference(entry.createdAt).inDays;
      final weight = ageDays <= 7
          ? 1.5
          : ageDays <= 30
              ? 1.0
              : 0.5;
      final normalizedId = entry.cardId;

      if (_isTarotCard(normalizedId)) {
        totalTarotWeight += weight;
      }
      if (_isMajorArcana(normalizedId)) {
        majorWeight += weight;
      }

      final element = _bucketByDeck(
        cardId: normalizedId,
        selectedDeck: selectedDeck,
      );
      if (element != null) {
        suitWeights[element] = (suitWeights[element] ?? 0) + weight;
      }

      final resolvedName = entry.cardName.isNotEmpty
          ? entry.cardName
          : cardById[normalizedId]?.name ?? normalizedId;
      frequencyNames[normalizedId] = resolvedName;
      frequencyWeighted[normalizedId] =
          (frequencyWeighted[normalizedId] ?? 0) + weight;

      if (ageDays <= 30) {
        monthlyRepeats[normalizedId] = (monthlyRepeats[normalizedId] ?? 0) + 1;
      }
    }

    final totalElementsWeight = suitWeights.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final elementPercents = <_ElementKind, int>{};
    for (final entry in suitWeights.entries) {
      final percent = totalElementsWeight <= 0
          ? 0
          : ((entry.value / totalElementsWeight) * 100).round();
      elementPercents[entry.key] = percent.clamp(0, 100);
    }

    final sortedElements = elementPercents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantElement =
        sortedElements.isNotEmpty ? sortedElements.first.key : null;
    final supportElement =
        sortedElements.length > 1 ? sortedElements[1].key : null;
    final majorPercent = selectedDeck == DeckType.lenormand ||
            selectedDeck == DeckType.crowley
        ? _concentrationPercent(suitWeights)
        : totalTarotWeight <= 0
            ? 0
            : ((majorWeight / totalTarotWeight) * 100).round().clamp(0, 100);

    final majorPool = frequencyWeighted.entries
        .where((entry) => _isMajorArcana(entry.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final allPool = frequencyWeighted.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dominantArchetypeId = majorPool.isNotEmpty
        ? majorPool.first.key
        : allPool.isNotEmpty
            ? allPool.first.key
            : null;
    final dominantArchetypeName = dominantArchetypeId == null
        ? null
        : frequencyNames[dominantArchetypeId] ?? dominantArchetypeId;

    final repeatedSignals = monthlyRepeats.entries
        .where((entry) => entry.value >= 3)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final signalList = <_RepeatedCardSignal>[
      for (final entry in repeatedSignals)
        _RepeatedCardSignal(
          cardName: frequencyNames[entry.key] ?? entry.key,
          count30d: entry.value,
        ),
    ];
    if (signalList.isEmpty) {
      for (final card in topCards) {
        if (card.count >= 3) {
          signalList.add(
            _RepeatedCardSignal(
              cardName: card.name,
              count30d: card.count,
            ),
          );
        }
      }
    }

    return _EnergyProfileData(
      deckType: selectedDeck,
      sampledCardsCount: cardsWindow.length,
      elementPercents: elementPercents,
      dominantElement: dominantElement,
      supportElement: supportElement,
      majorArcanaPercent: majorPercent,
      dominantArchetype: dominantArchetypeName,
      repeatedSignals: signalList,
    );
  }

  _EnergyProfileData _buildEnergyProfileFromAllTimeStats({
    required Map<String, int> allTimeStats,
    required Map<String, CardModel> cardById,
    required List<_TopCardStat> topCards,
    required DeckType selectedDeck,
  }) {
    final suitWeights = <_ElementKind, double>{
      _ElementKind.wands: 0,
      _ElementKind.cups: 0,
      _ElementKind.swords: 0,
      _ElementKind.pentacles: 0,
    };
    final frequency = <String, double>{};
    final names = <String, String>{};

    var majorWeight = 0.0;
    var totalTarotWeight = 0.0;
    var sampledCardsCount = 0;

    for (final entry in allTimeStats.entries) {
      final normalizedId = canonicalCardId(entry.key);
      if (!_matchesProfileDeck(normalizedId, selectedDeck)) {
        continue;
      }
      final count = entry.value;
      if (count <= 0) {
        continue;
      }
      final weight = count.toDouble();
      sampledCardsCount += count;
      frequency[normalizedId] = (frequency[normalizedId] ?? 0) + weight;
      names[normalizedId] = cardById[normalizedId]?.name ?? normalizedId;

      if (_isTarotCard(normalizedId)) {
        totalTarotWeight += weight;
      }
      if (_isMajorArcana(normalizedId)) {
        majorWeight += weight;
      }
      final element = _bucketByDeck(
        cardId: normalizedId,
        selectedDeck: selectedDeck,
      );
      if (element != null) {
        suitWeights[element] = (suitWeights[element] ?? 0) + weight;
      }
    }

    if (sampledCardsCount == 0) {
      return const _EnergyProfileData.empty();
    }

    final totalElementsWeight = suitWeights.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final elementPercents = <_ElementKind, int>{};
    for (final entry in suitWeights.entries) {
      final percent = totalElementsWeight <= 0
          ? 0
          : ((entry.value / totalElementsWeight) * 100).round();
      elementPercents[entry.key] = percent.clamp(0, 100);
    }

    final sortedElements = elementPercents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantElement =
        sortedElements.isNotEmpty ? sortedElements.first.key : null;
    final supportElement =
        sortedElements.length > 1 ? sortedElements[1].key : null;

    final majorPercent = selectedDeck == DeckType.lenormand ||
            selectedDeck == DeckType.crowley
        ? _concentrationPercent(suitWeights)
        : totalTarotWeight <= 0
            ? 0
            : ((majorWeight / totalTarotWeight) * 100).round().clamp(0, 100);

    final majorPool = frequency.entries
        .where((entry) => _isMajorArcana(entry.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final allPool = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dominantArchetypeId = majorPool.isNotEmpty
        ? majorPool.first.key
        : allPool.isNotEmpty
            ? allPool.first.key
            : null;
    final dominantArchetypeName = dominantArchetypeId == null
        ? null
        : names[dominantArchetypeId] ?? dominantArchetypeId;

    final repeatedSignals = <_RepeatedCardSignal>[
      for (final entry in allTimeStats.entries)
        if (entry.value >= 3 &&
            _matchesProfileDeck(canonicalCardId(entry.key), selectedDeck))
          _RepeatedCardSignal(
            cardName: names[canonicalCardId(entry.key)] ??
                cardById[canonicalCardId(entry.key)]?.name ??
                entry.key,
            count30d: entry.value,
          ),
    ]..sort((a, b) => b.count30d.compareTo(a.count30d));

    if (repeatedSignals.isEmpty) {
      for (final card in topCards) {
        if (card.count >= 3) {
          repeatedSignals.add(
            _RepeatedCardSignal(
              cardName: card.name,
              count30d: card.count,
            ),
          );
        }
      }
    }

    return _EnergyProfileData(
      deckType: selectedDeck,
      sampledCardsCount: sampledCardsCount,
      elementPercents: elementPercents,
      dominantElement: dominantElement,
      supportElement: supportElement,
      majorArcanaPercent: majorPercent,
      dominantArchetype: dominantArchetypeName,
      repeatedSignals: repeatedSignals,
    );
  }

  bool _matchesProfileDeck(String cardId, DeckType selectedDeck) {
    if (selectedDeck == DeckType.crowley) {
      return cardId.startsWith('ac_');
    }
    if (selectedDeck == DeckType.lenormand) {
      return cardId.startsWith('lenormand_');
    }
    return _isTarotCard(cardId);
  }

  bool _isTarotCard(String cardId) {
    return cardId.startsWith('major_') ||
        cardId.startsWith('ac_') ||
        cardId.startsWith('wands_') ||
        cardId.startsWith('cups_') ||
        cardId.startsWith('swords_') ||
        cardId.startsWith('pentacles_');
  }

  bool _isMajorArcana(String cardId) {
    return cardId.startsWith('major_') || cardId.startsWith('ac_');
  }

  _ElementKind? _bucketByDeck({
    required String cardId,
    required DeckType selectedDeck,
  }) {
    if (selectedDeck == DeckType.lenormand) {
      return _lenormandBucket(cardId);
    }
    if (selectedDeck == DeckType.crowley) {
      return _crowleyBucket(cardId);
    }
    return _elementByCardId(cardId);
  }

  _ElementKind? _elementByCardId(String cardId) {
    if (cardId.startsWith('wands_')) {
      return _ElementKind.wands;
    }
    if (cardId.startsWith('cups_')) {
      return _ElementKind.cups;
    }
    if (cardId.startsWith('swords_')) {
      return _ElementKind.swords;
    }
    if (cardId.startsWith('pentacles_')) {
      return _ElementKind.pentacles;
    }
    return null;
  }

  _ElementKind? _crowleyBucket(String cardId) {
    if (!cardId.startsWith('ac_')) {
      return null;
    }
    final parts = cardId.split('_');
    if (parts.length < 3) {
      return null;
    }
    final number = int.tryParse(parts[1]);
    if (number == null) {
      return null;
    }
    if (number <= 5) {
      return _ElementKind.wands;
    }
    if (number <= 11) {
      return _ElementKind.cups;
    }
    if (number <= 17) {
      return _ElementKind.swords;
    }
    return _ElementKind.pentacles;
  }

  _ElementKind? _lenormandBucket(String cardId) {
    if (!cardId.startsWith('lenormand_')) {
      return null;
    }
    final parts = cardId.split('_');
    if (parts.length < 3) {
      return null;
    }
    final number = int.tryParse(parts[1]);
    if (number == null) {
      return null;
    }
    const movement = <int>{1, 2, 3, 9, 12, 17, 22, 27};
    const bonds = <int>{13, 16, 18, 24, 25, 28, 29};
    const material = <int>{4, 5, 14, 15, 19, 20, 30, 33, 34, 35};
    if (movement.contains(number)) {
      return _ElementKind.wands;
    }
    if (bonds.contains(number)) {
      return _ElementKind.cups;
    }
    if (material.contains(number)) {
      return _ElementKind.pentacles;
    }
    return _ElementKind.swords;
  }

  int _concentrationPercent(Map<_ElementKind, double> weights) {
    final total = weights.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return 0;
    }
    final peak = weights.values.fold<double>(0, max);
    return ((peak / total) * 100).round().clamp(0, 100);
  }

  Future<void> _showStreakModal({
    required _HomeStreakCopy copy,
    required List<_TopCardStat> topCards,
    required List<CardModel> cards,
    required DeckType selectedDeck,
  }) async {
    final energyCopy = _EnergyProfileCopy.resolve(context);
    final profile = _buildEnergyProfile(
      cards: cards,
      topCards: topCards,
      selectedDeck: selectedDeck,
    );

    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy.modalTitle,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: copy.closeLabel,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          label: copy.currentStreakLabel,
                          value: copy.daysCountLabel(
                            _streakStats.currentStreakDays,
                          ),
                          tone: _StatPillTone.green,
                          loading: _loadingStreak,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatPill(
                          label: copy.bestStreakLabel,
                          value: copy.daysCountLabel(
                            _streakStats.longestStreakDays,
                          ),
                          tone: _StatPillTone.blue,
                          loading: _loadingStreak,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AwarenessPill(
                          label: copy.awarenessLabel,
                          value: _streakStats.awarenessPercent,
                          locked: _streakStats.awarenessLocked,
                          shimmer: _titleShimmerController,
                          loading: _loadingStreak,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_loadingStreak && _streakStats.lastActiveAt != null)
                    Text(
                      copy.lastActiveLabel(_streakStats.lastActiveAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.68),
                          ),
                    ),
                  const SizedBox(height: 14),
                  SelfAnalysisReportCtaSection(
                    title: copy.reportSectionTitle,
                    body: copy.reportSectionBody,
                    paidLabel: copy.reportPaidCta,
                    freeLabel: copy.reportFreeCta,
                    helper: '',
                    isFree: _isReportFreeByEntitlements(),
                    isLoading:
                        _reportFlowInFlight || _loadingReportEntitlements,
                    isEnabled: !_loadingStreak,
                    onPressed: () => _onGenerateReportTap(
                      copy: copy,
                      selectedDeck: selectedDeck,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_loadingStreak)
                            _HomeMagicLoadingCard(
                              label: copy.streakLoadingSubtitle,
                            )
                          else
                            _EnergyProfileCard(
                              copy: energyCopy,
                              profile: profile,
                              streakDays: _streakStats.currentStreakDays,
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDailyCardModal({
    required CardModel dailyCard,
    required _HomeStreakCopy copy,
  }) async {
    final rootContext = context;
    final hasCache = _dailyCardInterpretationCardId == dailyCard.id &&
        (_dailyCardInterpretation?.trim().isNotEmpty ?? false);
    final locale = Localizations.localeOf(context).languageCode;
    final requestFuture = hasCache
        ? null
        : ref.read(homeInsightsRepositoryProvider).fetchDailyCardInterpretation(
              card: dailyCard,
              locale: locale,
            );

    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy.dailyCardModalTitle,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: copy.closeLabel,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                      color: colorScheme.surfaceVariant.withValues(alpha: 0.16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 112,
                          child: AspectRatio(
                            aspectRatio: 0.68,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                dailyCard.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.32),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.14),
                                ),
                                child: Text(
                                  copy.dailyCardBadgeLabel,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dailyCard.name,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dailyCard.meaning.general.trim().isEmpty
                                    ? copy.dailyCardFallback
                                    : dailyCard.meaning.general.trim(),
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.8),
                                      height: 1.38,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    copy.dailyCardInsightTitle,
                    style:
                        Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: requestFuture,
                      initialData: hasCache ? _dailyCardInterpretation : null,
                      builder: (builderContext, snapshot) {
                        final hasValue = snapshot.hasData &&
                            (snapshot.data?.trim().isNotEmpty ?? false);
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !hasValue) {
                          return _HomeMagicLoadingCard(
                            label: copy.dailyCardPending,
                          );
                        }
                        final resolved = hasValue
                            ? snapshot.data!.trim()
                            : copy.dailyCardError;
                        if (_dailyCardInterpretationCardId != dailyCard.id ||
                            _dailyCardInterpretation != resolved) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _dailyCardInterpretationCardId = dailyCard.id;
                              _dailyCardInterpretation = resolved;
                            });
                          });
                        }
                        return SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: colorScheme.surfaceVariant
                                  .withValues(alpha: 0.13),
                              border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.68),
                              ),
                            ),
                            child: Text(
                              resolved,
                              style: Theme.of(builderContext)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.92),
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DailyCardConversionBlock(
                    copy: copy,
                    onStartReading: () {
                      final question = copy.dailyCardQuestion(dailyCard.name);
                      _controller.text = question;
                      ref
                          .read(readingFlowControllerProvider.notifier)
                          .setQuestion(question);
                      Navigator.of(sheetContext).pop();
                      Navigator.push(
                        rootContext,
                        MaterialPageRoute(
                          settings: appRouteSettings(showBackButton: false),
                          builder: (_) => const SpreadScreen(),
                        ),
                      );
                    },
                    onSofiaTap: () async {
                      Navigator.of(sheetContext).pop();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 140),
                      );
                      if (!mounted) {
                        return;
                      }
                      await _showSofiaInfoModal();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePrimaryAction(bool hasQuestion) {
    if (!hasQuestion) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: false),
        builder: (_) => const SpreadScreen(),
      ),
    );
  }

  String _deckHint(AppLocalizations l10n, DeckType deckId) {
    return switch (deckId) {
      DeckType.lenormand => '${l10n.deckLabel}: ${l10n.deckLenormandName}',
      DeckType.crowley => '${l10n.deckLabel}: ${l10n.deckCrowleyName}',
      _ => '${l10n.deckLabel}: ${l10n.deckTarotRiderWaite}',
    };
  }
}

enum _SofiaConsentState {
  undecided(''),
  accepted(_sofiaConsentAccepted),
  rejected(_sofiaConsentRejected);

  const _SofiaConsentState(this.storageValue);

  final String storageValue;
}

class _ShimmerTitle extends StatelessWidget {
  const _ShimmerTitle({
    required this.text,
    required this.animation,
    required this.baseStyle,
    required this.shimmerColor,
  });

  final String text;
  final Animation<double> animation;
  final TextStyle? baseStyle;
  final Color shimmerColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final shift =
                (-bounds.width) + (bounds.width * 2 * animation.value);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.72),
                Colors.white.withValues(alpha: 0.92),
                shimmerColor,
                Colors.white.withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(
              Rect.fromLTWH(
                shift,
                bounds.top,
                bounds.width,
                bounds.height,
              ),
            );
          },
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: baseStyle?.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

class _OnboardingBullet extends StatelessWidget {
  const _OnboardingBullet({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text('✨'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeOnboardingCopy {
  const _HomeOnboardingCopy({
    required this.title,
    required this.subtitle,
    required this.itemLenormand,
    required this.itemLenormandHint,
    required this.itemCompatibility,
    required this.itemCompatibilityHint,
    required this.itemNatal,
    required this.itemNatalHint,
    required this.closeButton,
  });

  final String title;
  final String subtitle;
  final String itemLenormand;
  final String itemLenormandHint;
  final String itemCompatibility;
  final String itemCompatibilityHint;
  final String itemNatal;
  final String itemNatalHint;
  final String closeButton;

  static String _buildVersionSubtitle() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return 'v$appVersion • $day.$month.$year';
  }

  static _HomeOnboardingCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final subtitle = _buildVersionSubtitle();
    if (code == 'ru') {
      return _HomeOnboardingCopy(
        title: 'The real magic',
        subtitle: subtitle,
        itemLenormand: 'Гадание по колоде Ленорман',
        itemLenormandHint: 'Выбери колоду в профиле',
        itemCompatibility: 'Проверка совместимости пары',
        itemCompatibilityHint: 'Попробуй бесплатно',
        itemNatal: 'Чтение натальной карты',
        itemNatalHint: 'Попробуй бесплатно',
        closeButton: 'Отлично',
      );
    }
    if (code == 'kk') {
      return _HomeOnboardingCopy(
        title: 'The real magic',
        subtitle: subtitle,
        itemLenormand: 'Ленорман колодасы бойынша болжау',
        itemLenormandHint: 'Колоданы профильден таңда',
        itemCompatibility: 'Жұп үйлесімділігін тексеру',
        itemCompatibilityHint: 'Тегін байқап көр',
        itemNatal: 'Наталдық картаны оқу',
        itemNatalHint: 'Тегін байқап көр',
        closeButton: 'Керемет',
      );
    }
    return _HomeOnboardingCopy(
      title: 'The real magic',
      subtitle: subtitle,
      itemLenormand: 'Lenormand card reading',
      itemLenormandHint: 'Choose deck in profile',
      itemCompatibility: 'Couple compatibility check',
      itemCompatibilityHint: 'Try it for free',
      itemNatal: 'Natal chart reading',
      itemNatalHint: 'Try it for free',
      closeButton: 'Great',
    );
  }
}

class _TopCardStat {
  const _TopCardStat({
    required this.name,
    required this.count,
    required this.imageUrl,
  });

  final String name;
  final int count;
  final String imageUrl;
}

enum _ElementKind { wands, cups, swords, pentacles }

class _ProfileEntry {
  const _ProfileEntry({
    required this.cardId,
    required this.cardName,
    required this.createdAt,
  });

  final String cardId;
  final String cardName;
  final DateTime createdAt;
}

class _RepeatedCardSignal {
  const _RepeatedCardSignal({
    required this.cardName,
    required this.count30d,
  });

  final String cardName;
  final int count30d;
}

class _EnergyProfileData {
  const _EnergyProfileData({
    required this.deckType,
    required this.sampledCardsCount,
    required this.elementPercents,
    required this.dominantElement,
    required this.supportElement,
    required this.majorArcanaPercent,
    required this.dominantArchetype,
    required this.repeatedSignals,
  });

  final DeckType deckType;
  final int sampledCardsCount;
  final Map<_ElementKind, int> elementPercents;
  final _ElementKind? dominantElement;
  final _ElementKind? supportElement;
  final int majorArcanaPercent;
  final String? dominantArchetype;
  final List<_RepeatedCardSignal> repeatedSignals;

  bool get hasCards => sampledCardsCount > 0;

  const _EnergyProfileData.empty()
      : deckType = DeckType.all,
        sampledCardsCount = 0,
        elementPercents = const {},
        dominantElement = null,
        supportElement = null,
        majorArcanaPercent = 0,
        dominantArchetype = null,
        repeatedSignals = const [];
}

class _EnergyProfileCopy {
  const _EnergyProfileCopy({
    required this.title,
    required this.subtitle,
    required this.emptyState,
    required this.elementsTitleRider,
    required this.elementsTitleLenormand,
    required this.elementsTitleCrowley,
    required this.destinyTitleRider,
    required this.destinyTitleAlt,
    required this.destinyLowRider,
    required this.destinyHighRider,
    required this.destinyLowAlt,
    required this.destinyHighAlt,
    required this.archetypeTitle,
    required this.archetypeFallback,
    required this.repeatsTitle,
    required this.repeatsFallback,
    required this.sampleWindowLabel,
    required this.elementAction,
    required this.elementEmotion,
    required this.elementMind,
    required this.elementMatter,
    required this.lenormandMovement,
    required this.lenormandRelations,
    required this.lenormandChallenges,
    required this.lenormandMaterial,
    required this.crowleyImpulse,
    required this.crowleyChoice,
    required this.crowleyTransformation,
    required this.crowleyIntegration,
    required this.phaseSummaryFallback,
    required this.archetypeDescriptionFallback,
  });

  final String title;
  final String subtitle;
  final String emptyState;
  final String elementsTitleRider;
  final String elementsTitleLenormand;
  final String elementsTitleCrowley;
  final String destinyTitleRider;
  final String destinyTitleAlt;
  final String destinyLowRider;
  final String destinyHighRider;
  final String destinyLowAlt;
  final String destinyHighAlt;
  final String archetypeTitle;
  final String archetypeFallback;
  final String repeatsTitle;
  final String repeatsFallback;
  final String sampleWindowLabel;
  final String elementAction;
  final String elementEmotion;
  final String elementMind;
  final String elementMatter;
  final String lenormandMovement;
  final String lenormandRelations;
  final String lenormandChallenges;
  final String lenormandMaterial;
  final String crowleyImpulse;
  final String crowleyChoice;
  final String crowleyTransformation;
  final String crowleyIntegration;
  final String phaseSummaryFallback;
  final String archetypeDescriptionFallback;

  String circleTitle(DeckType deckType) {
    if (deckType == DeckType.lenormand) {
      return elementsTitleLenormand;
    }
    if (deckType == DeckType.crowley) {
      return elementsTitleCrowley;
    }
    return elementsTitleRider;
  }

  String destinyTitle(DeckType deckType) {
    if (deckType == DeckType.lenormand || deckType == DeckType.crowley) {
      return destinyTitleAlt;
    }
    return destinyTitleRider;
  }

  String destinySummary(DeckType deckType, int percent) {
    final high = percent >= 38;
    if (deckType == DeckType.lenormand || deckType == DeckType.crowley) {
      return high ? destinyHighAlt : destinyLowAlt;
    }
    return high ? destinyHighRider : destinyLowRider;
  }

  String elementLabel(DeckType deckType, _ElementKind kind) {
    if (deckType == DeckType.lenormand) {
      switch (kind) {
        case _ElementKind.wands:
          return lenormandMovement;
        case _ElementKind.cups:
          return lenormandRelations;
        case _ElementKind.swords:
          return lenormandChallenges;
        case _ElementKind.pentacles:
          return lenormandMaterial;
      }
    }
    if (deckType == DeckType.crowley) {
      switch (kind) {
        case _ElementKind.wands:
          return crowleyImpulse;
        case _ElementKind.cups:
          return crowleyChoice;
        case _ElementKind.swords:
          return crowleyTransformation;
        case _ElementKind.pentacles:
          return crowleyIntegration;
      }
    }
    switch (kind) {
      case _ElementKind.wands:
        return elementAction;
      case _ElementKind.cups:
        return elementEmotion;
      case _ElementKind.swords:
        return elementMind;
      case _ElementKind.pentacles:
        return elementMatter;
    }
  }

  String phaseSummary({
    required DeckType deckType,
    required _ElementKind? dominant,
    required _ElementKind? support,
  }) {
    if (dominant == null) {
      return phaseSummaryFallback;
    }
    final dominantLabel = elementLabel(deckType, dominant).toLowerCase();
    if (support == null) {
      if (title.startsWith('Твой')) {
        return 'Сейчас доминирует $dominantLabel. Это твой основной вектор периода.';
      }
      if (title.startsWith('Сенің')) {
        return 'Қазір $dominantLabel басым. Осы кезеңнің негізгі бағыты осы.';
      }
      return 'Your pattern is led by $dominantLabel right now.';
    }
    final supportLabel = elementLabel(deckType, support).toLowerCase();
    if (title.startsWith('Твой')) {
      return 'Ты в фазе, где $dominantLabel ведёт, а $supportLabel поддерживает движение.';
    }
    if (title.startsWith('Сенің')) {
      return '$dominantLabel алда, ал $supportLabel оны қолдап тұр.';
    }
    return 'You are in a phase where $dominantLabel leads and $supportLabel supports it.';
  }

  String archetypeDescription(String cardName) {
    if (title.startsWith('Твой')) {
      return 'Ведущий архетип сейчас: $cardName. Используй его как ориентир для решений ближайших дней.';
    }
    if (title.startsWith('Сенің')) {
      return 'Қазір жетекші архетип: $cardName. Жақын күндердегі шешімдерде осыны бағдар етіңіз.';
    }
    return 'Your current leading archetype is $cardName. Use it as a compass for near-term decisions.';
  }

  String localeHint(int streakDays) {
    if (title.startsWith('Твой')) {
      return 'Серия $streakDays дней усиливает точность профиля.';
    }
    if (title.startsWith('Сенің')) {
      return '$streakDays күндік серия профиль дәлдігін арттырады.';
    }
    return '$streakDays-day streak improves profile precision.';
  }

  static _EnergyProfileCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _EnergyProfileCopy(
        title: 'Твой текущий энергетический паттерн',
        subtitle: 'Аналитика по последним раскладам',
        emptyState:
            'Пока мало данных. Сделай несколько раскладов, и профиль начнет заполняться.',
        elementsTitleRider: 'Круг стихий',
        elementsTitleLenormand: 'Круг сюжетов',
        elementsTitleCrowley: 'Круг арканических фаз',
        destinyTitleRider: 'Уровень судьбоносности',
        destinyTitleAlt: 'Интенсивность паттерна',
        destinyLowRider: 'Фоновая фаза: многое в твоих руках',
        destinyHighRider: 'Период судьбоносных сдвигов',
        destinyLowAlt: 'Паттерн мягкий и распределенный',
        destinyHighAlt: 'Паттерн концентрированный и сильный',
        archetypeTitle: 'Доминирующий архетип',
        archetypeFallback: 'Архетип пока формируется',
        repeatsTitle: 'Повторяющиеся сигналы (30 дней)',
        repeatsFallback: 'Явных повторов пока нет.',
        sampleWindowLabel: 'На основе последних 30 карт',
        elementAction: 'Жезлы',
        elementEmotion: 'Кубки',
        elementMind: 'Мечи',
        elementMatter: 'Пентакли',
        lenormandMovement: 'Движение',
        lenormandRelations: 'Связи',
        lenormandChallenges: 'Испытания',
        lenormandMaterial: 'Ресурсы',
        crowleyImpulse: 'Импульс',
        crowleyChoice: 'Выбор',
        crowleyTransformation: 'Трансформация',
        crowleyIntegration: 'Интеграция',
        phaseSummaryFallback:
            'Профиль еще набирает статистику, поэтому вывод пока нейтральный.',
        archetypeDescriptionFallback:
            'Когда накопится больше раскладов, здесь появится твой ведущий архетип периода.',
      );
    }
    if (code == 'kk') {
      return const _EnergyProfileCopy(
        title: 'Сенің ағымдағы энергия паттернің',
        subtitle: 'Соңғы раскладтар аналитикасы',
        emptyState:
            'Дерек әлі аз. Бірнеше расклад жасаңыз, профиль біртіндеп толады.',
        elementsTitleRider: 'Стихиялар шеңбері',
        elementsTitleLenormand: 'Сюжеттер шеңбері',
        elementsTitleCrowley: 'Аркан фазалары шеңбері',
        destinyTitleRider: 'Тағдырлық кезең деңгейі',
        destinyTitleAlt: 'Паттерн қарқындылығы',
        destinyLowRider: 'Фондық фаза: бәрі өз қолыңда',
        destinyHighRider: 'Тағдырлық өзгеріс кезеңі',
        destinyLowAlt: 'Паттерн жұмсақ әрі таралған',
        destinyHighAlt: 'Паттерн шоғырланған әрі күшті',
        archetypeTitle: 'Басым архетип',
        archetypeFallback: 'Архетип әлі қалыптасып жатыр',
        repeatsTitle: 'Қайталанатын сигналдар (30 күн)',
        repeatsFallback: 'Айқын қайталанулар әзірге жоқ.',
        sampleWindowLabel: 'Соңғы 30 карта негізінде',
        elementAction: 'Таяқтар',
        elementEmotion: 'Кубоктар',
        elementMind: 'Қылыштар',
        elementMatter: 'Пентакльдер',
        lenormandMovement: 'Қозғалыс',
        lenormandRelations: 'Байланыстар',
        lenormandChallenges: 'Сынақтар',
        lenormandMaterial: 'Ресурстар',
        crowleyImpulse: 'Импульс',
        crowleyChoice: 'Таңдау',
        crowleyTransformation: 'Трансформация',
        crowleyIntegration: 'Интеграция',
        phaseSummaryFallback:
            'Профиль әлі статистика жинап жатыр, сондықтан қорытынды бейтарап.',
        archetypeDescriptionFallback:
            'Көбірек расклад болғанда осы жерде жетекші архетип көрсетіледі.',
      );
    }
    return const _EnergyProfileCopy(
      title: 'Your current energy pattern',
      subtitle: 'Analytics from recent readings',
      emptyState:
          'Not enough data yet. Complete a few readings and this profile will fill in.',
      elementsTitleRider: 'Element wheel',
      elementsTitleLenormand: 'Story wheel',
      elementsTitleCrowley: 'Arcana phase wheel',
      destinyTitleRider: 'Fate intensity',
      destinyTitleAlt: 'Pattern intensity',
      destinyLowRider: 'Background phase: you hold the steering wheel',
      destinyHighRider: 'Destiny-shaping phase',
      destinyLowAlt: 'Pattern is distributed and soft',
      destinyHighAlt: 'Pattern is concentrated and intense',
      archetypeTitle: 'Dominant archetype',
      archetypeFallback: 'Archetype is forming',
      repeatsTitle: 'Recurring signals (30 days)',
      repeatsFallback: 'No strong repeats yet.',
      sampleWindowLabel: 'Based on your latest 30 cards',
      elementAction: 'Wands',
      elementEmotion: 'Cups',
      elementMind: 'Swords',
      elementMatter: 'Pentacles',
      lenormandMovement: 'Movement',
      lenormandRelations: 'Connections',
      lenormandChallenges: 'Challenges',
      lenormandMaterial: 'Resources',
      crowleyImpulse: 'Impulse',
      crowleyChoice: 'Choice',
      crowleyTransformation: 'Transformation',
      crowleyIntegration: 'Integration',
      phaseSummaryFallback:
          'The profile is still collecting signal, so the summary stays neutral for now.',
      archetypeDescriptionFallback:
          'As more readings accumulate, your leading archetype will appear here.',
    );
  }
}

class _HomeStreakCopy {
  const _HomeStreakCopy({
    required this.tileLoadingTitle,
    required this.tileLoadingSubtitle,
    required this.tileSubtitle,
    required this.modalTitle,
    required this.currentStreakLabel,
    required this.bestStreakLabel,
    required this.awarenessLabel,
    required this.dailyCardTileTitle,
    required this.dailyCardModalTitle,
    required this.dailyCardFallback,
    required this.dailyCardPending,
    required this.dailyCardError,
    required this.dailyCardBadgeLabel,
    required this.dailyCardInsightTitle,
    required this.dailyCardActionsTitle,
    required this.dailyCardPrimaryCta,
    required this.dailyCardSecondaryCta,
    required this.dailyCardQuestionPrefix,
    required this.streakLoadingSubtitle,
    required this.reportSectionTitle,
    required this.reportSectionBody,
    required this.reportPaidCta,
    required this.reportFreeCta,
    required this.reportHelper,
    required this.reportInsufficientTitle,
    required this.reportInsufficientBody,
    required this.reportConfirmTitle,
    required this.reportConfirmBody,
    required this.reportConfirmContinue,
    required this.reportConfirmCancel,
    required this.reportReadyTitle,
    required this.reportOpenPdf,
    required this.reportSharePdf,
    required this.reportGenerateFailed,
    required this.lastActivePrefix,
    required this.closeLabel,
    required this.dayUnit,
  });

  final String tileLoadingTitle;
  final String tileLoadingSubtitle;
  final String tileSubtitle;
  final String modalTitle;
  final String currentStreakLabel;
  final String bestStreakLabel;
  final String awarenessLabel;
  final String dailyCardTileTitle;
  final String dailyCardModalTitle;
  final String dailyCardFallback;
  final String dailyCardPending;
  final String dailyCardError;
  final String dailyCardBadgeLabel;
  final String dailyCardInsightTitle;
  final String dailyCardActionsTitle;
  final String dailyCardPrimaryCta;
  final String dailyCardSecondaryCta;
  final String dailyCardQuestionPrefix;
  final String streakLoadingSubtitle;
  final String reportSectionTitle;
  final String reportSectionBody;
  final String reportPaidCta;
  final String reportFreeCta;
  final String reportHelper;
  final String reportInsufficientTitle;
  final String reportInsufficientBody;
  final String reportConfirmTitle;
  final String reportConfirmBody;
  final String reportConfirmContinue;
  final String reportConfirmCancel;
  final String reportReadyTitle;
  final String reportOpenPdf;
  final String reportSharePdf;
  final String reportGenerateFailed;
  final String lastActivePrefix;
  final String closeLabel;
  final String Function(int) dayUnit;

  String dailyCardQuestion(String cardName) {
    final name = cardName.trim();
    if (name.isEmpty) {
      return dailyCardFallback;
    }
    return '$dailyCardQuestionPrefix "$name"?';
  }

  String tileTitle(int days) {
    final normalizedDays = days < 1 ? 1 : days;
    return '$normalizedDays ${dayUnit(normalizedDays)}';
  }

  String daysCountLabel(int days) {
    final normalizedDays = days < 0 ? 0 : days;
    return '$normalizedDays ${dayUnit(normalizedDays)}';
  }

  String lastActiveLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$lastActivePrefix: $day.$month.$year';
  }

  static _HomeStreakCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _HomeStreakCopy(
        tileLoadingTitle: '...',
        tileLoadingSubtitle: 'Загружаем streak...',
        tileSubtitle: 'Ритм и статистика',
        modalTitle: 'Твой ритм',
        currentStreakLabel: 'В потоке',
        bestStreakLabel: 'Рекорд',
        awarenessLabel: 'Осознанность',
        dailyCardTileTitle: 'Карта дня',
        dailyCardModalTitle: 'Карта дня',
        dailyCardFallback: 'Подбираем карту...',
        dailyCardPending: 'Смотрим, что карта дня значит именно для тебя…',
        dailyCardError: 'Не получилось получить трактовку. Попробуй еще раз.',
        dailyCardBadgeLabel: 'Энергия дня',
        dailyCardInsightTitle: 'Трактовка',
        dailyCardActionsTitle: 'Сделать следующий шаг',
        dailyCardPrimaryCta: 'Сделать расклад по карте',
        dailyCardSecondaryCta: 'Личная консультация Софии',
        dailyCardQuestionPrefix:
            'Какой следующий шаг мне сделать сегодня, учитывая карту',
        streakLoadingSubtitle: 'Подтягиваем актуальный streak...',
        reportSectionTitle: 'Личный отчет',
        reportSectionBody:
            'Личный коуч-отчёт на основе твоих раскладов за 30 дней.',
        reportPaidCta: 'Получить отчет (PDF) — 200 ⭐',
        reportFreeCta: 'Получить отчет (PDF) — бесплатно',
        reportHelper: 'На основе истории раскладов за 30 дней',
        reportInsufficientTitle: 'Недостаточно данных',
        reportInsufficientBody:
            'Нужно минимум 10 карт за последние 30 дней. Сделай ещё пару раскладов — и вернись сюда.',
        reportConfirmTitle: 'Сформировать отчет?',
        reportConfirmBody:
            'Мы соберём PDF-отчёт по твоим раскладам за 30 дней. Стоимость — 200 ⭐.',
        reportConfirmContinue: 'Продолжить',
        reportConfirmCancel: 'Отмена',
        reportReadyTitle: 'Отчет готов',
        reportOpenPdf: 'Открыть PDF',
        reportSharePdf: 'Поделиться',
        reportGenerateFailed:
            'Не получилось сформировать PDF после оплаты. Напиши в поддержку, мы поможем.',
        lastActivePrefix: 'Последняя активность',
        closeLabel: 'Закрыть',
        dayUnit: _ruDayUnit,
      );
    }
    if (code == 'kk') {
      return const _HomeStreakCopy(
        tileLoadingTitle: '...',
        tileLoadingSubtitle: 'Streak жүктелуде...',
        tileSubtitle: 'Серия мен статистика',
        modalTitle: 'Сенің streak',
        currentStreakLabel: 'Қазір',
        bestStreakLabel: 'Рекорд',
        awarenessLabel: 'Саналылық',
        dailyCardTileTitle: 'Күн картасы',
        dailyCardModalTitle: 'Күн картасы',
        dailyCardFallback: 'Карта таңдалып жатыр...',
        dailyCardPending: 'Күн картасының саған не айтатынын қарап жатырмыз…',
        dailyCardError: 'Түсіндірмені алу мүмкін болмады. Қайта көріңіз.',
        dailyCardBadgeLabel: 'Күн энергиясы',
        dailyCardInsightTitle: 'Түсіндірме',
        dailyCardActionsTitle: 'Келесі қадам',
        dailyCardPrimaryCta: 'Карта бойынша расклад жасау',
        dailyCardSecondaryCta: 'Софиямен жеке консультация',
        dailyCardQuestionPrefix:
            'Осы картаға сүйеніп, бүгін мен қандай келесі қадам жасауым керек',
        streakLoadingSubtitle: 'Өзекті streak жүктелуде...',
        reportSectionTitle: 'Жеке есеп',
        reportSectionBody:
            'Соңғы 30 күндегі раскладтарың бойынша коуч-есеп: паттерндер, баланс, жұмсақ ұсыныстар.',
        reportPaidCta: 'Есепті алу (PDF) — 200 ⭐',
        reportFreeCta: 'Есепті алу (PDF) — тегін',
        reportHelper: 'Соңғы 30 күндегі расклад тарихы негізінде',
        reportInsufficientTitle: 'Дерек жеткіліксіз',
        reportInsufficientBody:
            'Соңғы 30 күнде кемінде 10 карта қажет. Тағы бірнеше расклад жасап, қайта оралыңыз.',
        reportConfirmTitle: 'Есепті жасау керек пе?',
        reportConfirmBody:
            'Соңғы 30 күндегі раскладтарыңыз бойынша PDF-есеп жасаймыз. Бағасы — 200 ⭐.',
        reportConfirmContinue: 'Жалғастыру',
        reportConfirmCancel: 'Бас тарту',
        reportReadyTitle: 'Есеп дайын',
        reportOpenPdf: 'PDF ашу',
        reportSharePdf: 'Бөлісу',
        reportGenerateFailed:
            'Төлемнен кейін PDF құрастыру мүмкін болмады. Қолдауға жазыңыз, көмектесеміз.',
        lastActivePrefix: 'Соңғы белсенділік',
        closeLabel: 'Жабу',
        dayUnit: _kkDayUnit,
      );
    }
    return const _HomeStreakCopy(
      tileLoadingTitle: '...',
      tileLoadingSubtitle: 'Loading streak...',
      tileSubtitle: 'Streak and stats',
      modalTitle: 'Your streak',
      currentStreakLabel: 'Current',
      bestStreakLabel: 'Best',
      awarenessLabel: 'Awareness',
      dailyCardTileTitle: 'Daily card',
      dailyCardModalTitle: 'Daily card',
      dailyCardFallback: 'Selecting card...',
      dailyCardPending: 'Reading what this card means for you today...',
      dailyCardError: 'Could not load interpretation. Try again.',
      dailyCardBadgeLabel: 'Energy of the day',
      dailyCardInsightTitle: 'Interpretation',
      dailyCardActionsTitle: 'Take the next step',
      dailyCardPrimaryCta: 'Start a reading from this card',
      dailyCardSecondaryCta: 'Personal consultation with Sofia',
      dailyCardQuestionPrefix:
          'What next step should I take today based on the card',
      streakLoadingSubtitle: 'Loading latest streak...',
      reportSectionTitle: 'Personal report',
      reportSectionBody:
          'Coach-style report based on your last 30 days of readings: patterns, balance, and gentle recommendations.',
      reportPaidCta: 'Get report (PDF) — 200 ⭐',
      reportFreeCta: 'Get report (PDF) — free',
      reportHelper: 'Based on your reading history for the last 30 days',
      reportInsufficientTitle: 'Not enough data',
      reportInsufficientBody:
          'You need at least 10 cards in the last 30 days. Do a few more readings and come back.',
      reportConfirmTitle: 'Generate report?',
      reportConfirmBody:
          'We will build a PDF report from your last 30 days of readings. Price — 200 ⭐.',
      reportConfirmContinue: 'Continue',
      reportConfirmCancel: 'Cancel',
      reportReadyTitle: 'Report is ready',
      reportOpenPdf: 'Open PDF',
      reportSharePdf: 'Share',
      reportGenerateFailed:
          'Could not generate PDF after payment. Please contact support and we will help.',
      lastActivePrefix: 'Last activity',
      closeLabel: 'Close',
      dayUnit: _enDayUnit,
    );
  }
}

class _DailyCardConversionBlock extends StatelessWidget {
  const _DailyCardConversionBlock({
    required this.copy,
    required this.onStartReading,
    required this.onSofiaTap,
  });

  final _HomeStreakCopy copy;
  final VoidCallback onStartReading;
  final VoidCallback onSofiaTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
        color: colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.dailyCardActionsTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          AppPrimaryButton(
            label: copy.dailyCardPrimaryCta,
            onPressed: onStartReading,
          ),
          const SizedBox(height: 8),
          AppGhostButton(
            label: copy.dailyCardSecondaryCta,
            onPressed: onSofiaTap,
          ),
        ],
      ),
    );
  }
}

class _SecondaryFeatureCard extends StatelessWidget {
  const _SecondaryFeatureCard({
    this.icon,
    this.assetIconPath,
    this.pulseBadge = false,
    this.flickerIcon = false,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : assert(icon != null || assetIconPath != null);

  final IconData? icon;
  final String? assetIconPath;
  final bool pulseBadge;
  final bool flickerIcon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceVariant.withValues(alpha: 0.2),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            _IconCircleBadge(
              size: 30,
              pulse: pulseBadge,
              flickerChild: flickerIcon,
              child: Transform.translate(
                offset: const Offset(0, 0),
                child: assetIconPath != null
                    ? SvgPicture.asset(
                        assetIconPath!,
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFF4EEFF),
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: const Color(0xFFF4EEFF),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.74),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.tone,
    this.loading = false,
  });

  final String label;
  final String value;
  final _StatPillTone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone.gradient(colorScheme),
        ),
        border: Border.all(
          color: tone.border(colorScheme),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _AwarenessPill extends StatelessWidget {
  const _AwarenessPill({
    required this.label,
    required this.value,
    required this.locked,
    required this.shimmer,
    this.loading = false,
  });

  final String label;
  final int value;
  final bool locked;
  final Animation<double> shimmer;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = value.clamp(30, 100);
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: locked ? colorScheme.primary : null,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF77B8FF).withValues(alpha: locked ? 0.3 : 0.24),
            const Color(0xFFA9D5FF).withValues(alpha: locked ? 0.34 : 0.28),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7DBBFF).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (locked && percent == 100)
            _ShimmerTitle(
              text: '$percent%',
              animation: shimmer,
              baseStyle: textStyle,
              shimmerColor: colorScheme.primary,
            )
          else
            Text(
              '$percent%',
              style: textStyle,
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _EnergyProfileCard extends StatelessWidget {
  const _EnergyProfileCard({
    required this.copy,
    required this.profile,
    required this.streakDays,
  });

  final _EnergyProfileCopy copy;
  final _EnergyProfileData profile;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCrowley = profile.deckType == DeckType.crowley;
    final isLenormand = profile.deckType == DeckType.lenormand;
    final palette = isCrowley
        ? const [
            Color(0xFFC8B47C),
            Color(0xFF9DABC0),
            Color(0xFF8E98A9),
            Color(0xFFB3A07A),
          ]
        : isLenormand
            ? const [
                Color(0xFF7ABAE2),
                Color(0xFFC7A9C9),
                Color(0xFFA9ADCD),
                Color(0xFF8EBAA6),
              ]
            : const [
                Color(0xFFE28E67),
                Color(0xFF77B7DA),
                Color(0xFFD6D7E5),
                Color(0xFFD0B46D),
              ];
    final slices = [
      _EnergySlice(
        label: copy.elementLabel(profile.deckType, _ElementKind.wands),
        percent: profile.elementPercents[_ElementKind.wands] ?? 0,
        color: palette[0],
      ),
      _EnergySlice(
        label: copy.elementLabel(profile.deckType, _ElementKind.cups),
        percent: profile.elementPercents[_ElementKind.cups] ?? 0,
        color: palette[1],
      ),
      _EnergySlice(
        label: copy.elementLabel(profile.deckType, _ElementKind.swords),
        percent: profile.elementPercents[_ElementKind.swords] ?? 0,
        color: palette[2],
      ),
      _EnergySlice(
        label: copy.elementLabel(profile.deckType, _ElementKind.pentacles),
        percent: profile.elementPercents[_ElementKind.pentacles] ?? 0,
        color: palette[3],
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.38),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
            colorScheme.primary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${copy.subtitle} · ${copy.sampleWindowLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: 12),
          if (!profile.hasCards) ...[
            Text(
              copy.emptyState,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
            ),
          ] else ...[
            _EnergySectionTitle(text: copy.circleTitle(profile.deckType)),
            const SizedBox(height: 8),
            Row(
              children: [
                _EnergyDonutChart(
                  slices: slices,
                  centerLabel: '${profile.sampledCardsCount}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final slice in slices)
                        _EnergyLegendRow(
                          color: slice.color,
                          label: slice.label,
                          percent: slice.percent,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              copy.phaseSummary(
                deckType: profile.deckType,
                dominant: profile.dominantElement,
                support: profile.supportElement,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.86),
                  ),
            ),
            const SizedBox(height: 14),
            _EnergySectionTitle(text: copy.destinyTitle(profile.deckType)),
            const SizedBox(height: 8),
            _FateIntensityBar(value: profile.majorArcanaPercent),
            const SizedBox(height: 6),
            Text(
              copy.destinySummary(
                profile.deckType,
                profile.majorArcanaPercent,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.84),
                  ),
            ),
            const SizedBox(height: 14),
            _EnergySectionTitle(text: copy.archetypeTitle),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.dominantArchetype ?? copy.archetypeFallback,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.dominantArchetype == null
                        ? copy.archetypeDescriptionFallback
                        : copy.archetypeDescription(profile.dominantArchetype!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _EnergySectionTitle(text: copy.repeatsTitle),
            const SizedBox(height: 8),
            if (profile.repeatedSignals.isEmpty)
              Text(
                copy.repeatsFallback,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final signal in profile.repeatedSignals.take(4))
                    _SignalChip(
                      label: signal.cardName,
                      value: signal.count30d,
                    ),
                ],
              ),
            if (streakDays > 1) ...[
              const SizedBox(height: 10),
              Text(
                copy.localeHint(streakDays),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EnergySectionTitle extends StatelessWidget {
  const _EnergySectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _EnergyLegendRow extends StatelessWidget {
  const _EnergyLegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
            ),
          ),
          Text(
            '$percent%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _FateIntensityBar extends StatelessWidget {
  const _FateIntensityBar({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0, 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 11,
            value: clamped / 100,
            backgroundColor: colorScheme.surface.withValues(alpha: 0.42),
            valueColor: AlwaysStoppedAnimation<Color>(
              clamped >= 38 ? const Color(0xFFB26AFF) : colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        '$label · ${value}x',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EnergyDonutChart extends StatelessWidget {
  const _EnergyDonutChart({
    required this.slices,
    required this.centerLabel,
  });

  final List<_EnergySlice> slices;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return SizedBox(
          width: 126,
          height: 126,
          child: CustomPaint(
            painter: _DonutChartPainter(
              slices: slices,
              trackColor: colorScheme.surface.withValues(alpha: 0.45),
              progress: progress,
            ),
            child: Center(
              child: Text(
                centerLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _StatPillTone {
  green,
  blue;

  List<Color> gradient(ColorScheme colorScheme) {
    return switch (this) {
      _StatPillTone.green => [
          const Color(0xFF7ED6B4).withValues(alpha: 0.22),
          const Color(0xFF5EAE95).withValues(alpha: 0.18),
        ],
      _StatPillTone.blue => [
          const Color(0xFF7EBEFF).withValues(alpha: 0.22),
          const Color(0xFF6E9FD6).withValues(alpha: 0.18),
        ],
    };
  }

  Color border(ColorScheme colorScheme) {
    return switch (this) {
      _StatPillTone.green => const Color(0xFF79D0AF).withValues(alpha: 0.45),
      _StatPillTone.blue => const Color(0xFF75B6F2).withValues(alpha: 0.45),
    };
  }
}

class _EnergySlice {
  const _EnergySlice({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;
}

Color _mixColor(Color a, Color b, double t) {
  return Color.fromARGB(
    lerpDouble(a.a, b.a, t)!.round(),
    lerpDouble(a.r, b.r, t)!.round(),
    lerpDouble(a.g, b.g, t)!.round(),
    lerpDouble(a.b, b.b, t)!.round(),
  );
}

Color _soften(Color color, {double amount = 0.22}) {
  return _mixColor(color, Colors.white, amount.clamp(0.0, 1.0));
}

Color _deepen(Color color, {double amount = 0.14}) {
  return _mixColor(color, Colors.black, amount.clamp(0.0, 1.0));
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.slices,
    required this.trackColor,
    required this.progress,
  });

  final List<_EnergySlice> slices;
  final Color trackColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.13;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, pi * 2, false, trackPaint);

    var start = -pi / 2;
    final safeProgress = progress.clamp(0.0, 1.0);
    for (final slice in slices) {
      if (slice.percent <= 0) {
        continue;
      }
      final fullSweep = (slice.percent / 100) * pi * 2;
      final sweep = fullSweep * safeProgress;
      if (sweep <= 0.001) {
        start += fullSweep;
        continue;
      }
      final base = slice.color;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [
            _soften(base),
            base,
            _deepen(base),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect);
      canvas.drawArc(rect, start, max(0, sweep - 0.035), false, paint);
      start += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progress != progress;
  }
}

class _HomeMagicLoadingCard extends StatelessWidget {
  const _HomeMagicLoadingCard({
    this.label,
  });

  final String? label;

  String _label(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Подожди пару секунд…';
    }
    if (code == 'kk') {
      return 'Бірнеше секунд күте тұр…';
    }
    return 'Give me a couple of seconds...';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label ?? _label(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SofiaConsentCard extends StatelessWidget {
  const _SofiaConsentCard({
    required this.copy,
    required this.isBusy,
    required this.onOpenInfo,
    required this.onAccept,
    required this.onReject,
    this.compact = false,
  });

  final _SofiaCopy copy;
  final bool isBusy;
  final VoidCallback onOpenInfo;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onOpenInfo,
      child: Ink(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceVariant
              .withValues(alpha: compact ? 0.18 : 0.26),
          border: Border.all(
            color:
                colorScheme.outlineVariant.withValues(alpha: compact ? 0.7 : 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.consentTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface
                          .withValues(alpha: compact ? 0.72 : 0.78),
                    ),
                children: [
                  TextSpan(text: '${copy.consentBodyPrefix} '),
                  TextSpan(
                    text: copy.sofiaName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  TextSpan(text: ' ${copy.consentBodySuffix}'),
                ],
              ),
            ),
            SizedBox(height: compact ? 8 : 10),
            Row(
              children: [
                Expanded(
                  child: AppSmallButton(
                    label: copy.acceptButton,
                    onPressed: isBusy ? null : onAccept,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppSmallButton(
                    label: copy.rejectButton,
                    onPressed: isBusy ? null : onReject,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SofiaInfoCard extends StatelessWidget {
  const _SofiaInfoCard({
    required this.copy,
    required this.onTap,
    this.compact = false,
  });

  final _SofiaCopy copy;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const outerRadius = 20.0;
    return InkWell(
      borderRadius: BorderRadius.circular(outerRadius),
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          color: colorScheme.surfaceVariant
              .withValues(alpha: compact ? 0.16 : 0.24),
          border: Border.all(
            color: colorScheme.outlineVariant
                .withValues(alpha: compact ? 0.68 : 1),
          ),
        ),
        child: Row(
          children: [
            Text(
              '🦹‍♀️',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                copy.infoCardTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withOpacity(0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SofiaCopy {
  const _SofiaCopy({
    required this.sofiaName,
    required this.consentTitle,
    required this.consentBodyPrefix,
    required this.consentBodySuffix,
    required this.acceptButton,
    required this.rejectButton,
    required this.infoCardTitle,
    required this.modalTitle,
    required this.consentModalBody,
    required this.consentModalScope,
    required this.profileModalBody,
    required this.profileModalScope,
    required this.submitError,
    required this.closeLabel,
  });

  final String sofiaName;
  final String consentTitle;
  final String consentBodyPrefix;
  final String consentBodySuffix;
  final String acceptButton;
  final String rejectButton;
  final String infoCardTitle;
  final String modalTitle;
  final String consentModalBody;
  final String consentModalScope;
  final String profileModalBody;
  final String profileModalScope;
  final String submitError;
  final String closeLabel;

  static _SofiaCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _SofiaCopy(
        sofiaName: '@SofiaKnoxx',
        consentTitle: 'Согласие на обработку данных',
        consentBodyPrefix: 'Передавать имя и username нашему астрологу',
        consentBodySuffix: 'для уведомлений',
        acceptButton: 'Согласен',
        rejectButton: 'Не согласен',
        infoCardTitle: 'Наш таролог-астролог София',
        modalTitle: 'Наш таролог-астролог София',
        consentModalBody:
            'Если хочешь, можешь разрешить передавать Софии твое имя и username для уведомлений. Получатель: @SofiaKnoxx.',
        consentModalScope:
            'Передаем только имя и username. Если откажешься, уходит только анонимная статистика без имени и username.',
        profileModalBody:
            'София мягко и точно разбирает даже запутанные истории: отношения, деньги, работу и внутренние качели.',
        profileModalScope:
            'Если нужен ясный вектор и честный разбор без воды, она поможет собрать картину по шагам.',
        submitError: 'Не получилось сохранить выбор. Давай еще раз.',
        closeLabel: 'Закрыть',
      );
    }
    if (code == 'kk') {
      return const _SofiaCopy(
        sofiaName: '@SofiaKnoxx',
        consentTitle: 'Деректерді өңдеуге келісім',
        consentBodyPrefix: 'Есімді біздің астрологқа',
        consentBodySuffix: 'хабарламалар үшін жіберуге рұқсат беру',
        acceptButton: 'Келісемін',
        rejectButton: 'Келіспеймін',
        infoCardTitle: 'Біздің таролог-астролог София',
        modalTitle: 'Біздің таролог-астролог София',
        consentModalBody:
            'Хабарламалар үшін тек атыңызды София маманына жіберуге рұқсат бере аласыз. Нақты алушы: @SofiaKnoxx.',
        consentModalScope:
            'Тек ат беріледі. Бас тартсаңыз, атсыз тек жинақталған статистика жіберіледі.',
        profileModalBody:
            'София күрделі жағдайларды да жұмсақ әрі нақты талдап береді.',
        profileModalScope:
            'Қатынас, ақша, мансап не ішкі күй болсын, саған айқын бағыт табуға көмектеседі.',
        submitError: 'Таңдауды сақтау мүмкін болмады. Қайтадан көріңіз.',
        closeLabel: 'Жабу',
      );
    }
    return const _SofiaCopy(
      sofiaName: '@SofiaKnoxx',
      consentTitle: 'Data Processing Consent',
      consentBodyPrefix: 'Allow sharing your name with our astrologer',
      consentBodySuffix: 'for notifications',
      acceptButton: 'Agree',
      rejectButton: 'Decline',
      infoCardTitle: 'Our Tarot Astrologer Sofia',
      modalTitle: 'Our Tarot Astrologer Sofia',
      consentModalBody:
          'You can allow sending your name and Telegram username to Sofia for notifications. Recipient: @SofiaKnoxx.',
      consentModalScope:
          'Only your name and username are shared. If you decline, only anonymous aggregate stats are sent.',
      profileModalBody:
          'Sofia can help you untangle even the most complex situation with calm and precision.',
      profileModalScope:
          'Relationships, money, career, or inner chaos: she helps you see the full picture and your next step.',
      submitError: 'Could not save your choice. Please try again.',
      closeLabel: 'Close',
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _RecentQueriesChip extends StatelessWidget {
  const _RecentQueriesChip({
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureSquareCard extends StatelessWidget {
  const _FeatureSquareCard({
    this.icon,
    this.assetIconPath,
    this.iconOffsetY = 0,
    required this.title,
    required this.onTap,
  }) : assert(icon != null || assetIconPath != null);

  final IconData? icon;
  final String? assetIconPath;
  final double iconOffsetY;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.28),
              colorScheme.surface.withOpacity(0.7),
            ],
          ),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.35),
          ),
        ),
        child: Column(
          children: [
            _IconCircleBadge(
              size: 36,
              child: Transform.translate(
                offset: Offset(0, iconOffsetY),
                child: assetIconPath != null
                    ? SvgPicture.asset(
                        assetIconPath!,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFF4EEFF),
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        size: 22,
                        color: const Color(0xFFF4EEFF),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.15,
                  ),
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircleBadge extends StatefulWidget {
  const _IconCircleBadge({
    required this.size,
    required this.child,
    this.pulse = false,
    this.flickerChild = false,
  });

  final double size;
  final Widget child;
  final bool pulse;
  final bool flickerChild;

  @override
  State<_IconCircleBadge> createState() => _IconCircleBadgeState();
}

class _IconCircleBadgeState extends State<_IconCircleBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final lampPhase = _lampPhase(t);
        final electricOpacity = lampPhase.opacity;
        final electricScale = lampPhase.scale;
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface.withValues(alpha: 0.42),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: widget.flickerChild
              ? Opacity(
                  opacity: electricOpacity.clamp(0.2, 1.0),
                  child: Transform.scale(
                    scale: electricScale,
                    child: child,
                  ),
                )
              : child,
        );
      },
      child: widget.child,
    );
  }

  ({double opacity, double scale}) _lampPhase(double t) {
    if (t < 0.46) {
      return (opacity: 0.98, scale: 1.0);
    }
    if (t < 0.62) {
      final f = (t - 0.46) / 0.16;
      final blink = sin(f * pi * 2 * 9);
      final off = blink > 0.55 || blink < -0.85;
      return (opacity: off ? 0.22 : 0.9, scale: off ? 0.94 : 1.03);
    }
    if (t < 0.82) {
      return (opacity: 0.96, scale: 1.0);
    }
    if (t < 0.93) {
      final f = (t - 0.82) / 0.11;
      final blink = sin(f * pi * 2 * 13);
      final off = blink > 0.42 || blink < -0.92;
      return (opacity: off ? 0.18 : 0.88, scale: off ? 0.92 : 1.02);
    }
    return (opacity: 0.97, scale: 1.0);
  }
}

String _ruDayUnit(int days) {
  final mod100 = days % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return 'дней';
  }
  final mod10 = days % 10;
  if (mod10 == 1) {
    return 'день';
  }
  if (mod10 >= 2 && mod10 <= 4) {
    return 'дня';
  }
  return 'дней';
}

String _kkDayUnit(int days) {
  return 'күн';
}

String _enDayUnit(int days) {
  return days == 1 ? 'day' : 'days';
}

class _HomeFeatureCopy {
  const _HomeFeatureCopy({
    required this.natalTitle,
    required this.compatibilityTitle,
    required this.libraryTitle,
  });

  final String natalTitle;
  final String compatibilityTitle;
  final String libraryTitle;

  static _HomeFeatureCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _HomeFeatureCopy(
        natalTitle: 'Натальная\nкарта',
        compatibilityTitle: 'Проверка\nпары',
        libraryTitle: 'Библиотека\nкарт',
      );
    }
    if (code == 'kk') {
      return const _HomeFeatureCopy(
        natalTitle: 'Наталдық\nкарта',
        compatibilityTitle: 'Махаббат\nүйлесімділігі',
        libraryTitle: 'Карталар\nкітапханасы',
      );
    }
    return const _HomeFeatureCopy(
      natalTitle: 'Natal\nchart',
      compatibilityTitle: 'Love\ncompatibility',
      libraryTitle: 'Cards\nlibrary',
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.isActive,
    required this.primaryColor,
    required this.disabledColor,
    required this.label,
    this.onPressed,
  });

  final bool isActive;
  final Color primaryColor;
  final Color disabledColor;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      label: label,
      onPressed: onPressed,
      backgroundColor: isActive ? primaryColor : disabledColor,
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}

class _InlineIconButton extends StatelessWidget {
  const _InlineIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBackground =
        backgroundColor ?? colorScheme.surface.withOpacity(0.85);
    final resolvedIconColor =
        iconColor ?? colorScheme.onSurface.withOpacity(0.75);
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: resolvedBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: resolvedIconColor,
          ),
        ),
      ),
    );
  }
}
