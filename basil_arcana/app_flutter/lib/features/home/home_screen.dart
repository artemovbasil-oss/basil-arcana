import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../data/models/reading_model.dart';
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
import 'vibe_prompts_screen.dart';

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
    with TickerProviderStateMixin {
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
  bool _homeInviteCardViewTracked = false;
  bool _homeReferralStatsRequested = false;
  int? _homeReferralInvited;
  int? _homeReferralCredits;
  String? _homeReferralLink;
  bool _didRequestOnboarding = false;
  final ValueNotifier<int> _streakModalRefreshTick = ValueNotifier<int>(0);
  ValueListenable<Box<ReadingModel>>? _readingsListenable;
  VoidCallback? _readingsListener;
  ValueListenable<Box<int>>? _cardStatsListenable;
  VoidCallback? _cardStatsListener;
  ValueListenable<Box<int>>? _activityStatsListenable;
  VoidCallback? _activityStatsListener;
  Timer? _streakReloadDebounce;
  bool _streakLoadInFlight = false;
  bool _streakLoadQueued = false;
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
    _loadHomeReferralStats();
    _loadQueryHistoryAvailability();
    _attachLiveStatsListeners();
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

  void _attachLiveStatsListeners() {
    _readingsListenable = ref.read(readingsRepositoryProvider).listenable();
    _readingsListener = _handleLocalStatsChanged;
    _readingsListenable?.addListener(_readingsListener!);

    _cardStatsListenable = ref.read(cardStatsRepositoryProvider).listenable();
    _cardStatsListener = _handleLocalStatsChanged;
    _cardStatsListenable?.addListener(_cardStatsListener!);

    _activityStatsListenable =
        ref.read(activityStatsRepositoryProvider).listenable();
    _activityStatsListener = _handleLocalStatsChanged;
    _activityStatsListenable?.addListener(_activityStatsListener!);
  }

  void _detachLiveStatsListeners() {
    if (_readingsListenable != null && _readingsListener != null) {
      _readingsListenable!.removeListener(_readingsListener!);
    }
    if (_cardStatsListenable != null && _cardStatsListener != null) {
      _cardStatsListenable!.removeListener(_cardStatsListener!);
    }
    if (_activityStatsListenable != null && _activityStatsListener != null) {
      _activityStatsListenable!.removeListener(_activityStatsListener!);
    }
    _readingsListenable = null;
    _readingsListener = null;
    _cardStatsListenable = null;
    _cardStatsListener = null;
    _activityStatsListenable = null;
    _activityStatsListener = null;
  }

  void _handleLocalStatsChanged() {
    if (!mounted) {
      return;
    }
    final localSnapshot = _buildLocalStreakStatsSnapshot(base: _streakStats);
    if (!_sameStreakStats(_streakStats, localSnapshot) || _loadingStreak) {
      setState(() {
        _streakStats = localSnapshot;
        _loadingStreak = false;
      });
      _refreshOpenStreakModal();
    }
    _streakReloadDebounce?.cancel();
    _streakReloadDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      _loadStreakStats();
    });
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
    if (_streakLoadInFlight) {
      _streakLoadQueued = true;
      return;
    }
    _streakLoadInFlight = true;
    if (!_loadingStreak) {
      setState(() {
        _loadingStreak = true;
      });
      _refreshOpenStreakModal();
    }
    try {
      final streak =
          await ref.read(homeInsightsRepositoryProvider).fetchStreakStats();
      if (!mounted) {
        return;
      }
      final localSnapshot = _buildLocalStreakStatsSnapshot(base: _streakStats);
      final merged = _mergeStreakStats(
        remote: streak,
        local: localSnapshot,
      );
      setState(() {
        _streakStats = merged;
        _loadingStreak = false;
      });
      _refreshOpenStreakModal();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingStreak = false;
      });
      _refreshOpenStreakModal();
    } finally {
      _streakLoadInFlight = false;
      if (_streakLoadQueued && mounted) {
        _streakLoadQueued = false;
        unawaited(_loadStreakStats());
      }
    }
  }

  HomeStreakStats _buildLocalStreakStatsSnapshot({
    required HomeStreakStats base,
  }) {
    final readings = ref.read(readingsRepositoryProvider).getReadings();
    final activity = ref.read(activityStatsRepositoryProvider);
    final allDayCounts = activity.dailyCounts();
    if (readings.isEmpty && allDayCounts.isEmpty) {
      return HomeStreakStats(
        currentStreakDays: 0,
        longestStreakDays: 0,
        activeDays: 0,
        awarenessPercent: base.awarenessPercent,
        awarenessLocked: base.awarenessLocked,
        lastActiveAt: null,
      );
    }

    final uniqueDays = readings
        .map((reading) {
          final local = reading.createdAt.toLocal();
          return DateTime(local.year, local.month, local.day);
        })
        .toSet()
        .toList();
    if (allDayCounts.isNotEmpty) {
      uniqueDays.addAll(allDayCounts.keys);
    }
    uniqueDays.sort((a, b) => b.compareTo(a));

    var currentStreak = 0;
    if (uniqueDays.isNotEmpty) {
      currentStreak = 1;
      var cursor = uniqueDays.first;
      for (var i = 1; i < uniqueDays.length; i++) {
        final day = uniqueDays[i];
        final diff = cursor.difference(day).inDays;
        if (diff == 1) {
          currentStreak += 1;
          cursor = day;
          continue;
        }
        if (diff > 1) {
          break;
        }
      }
    }

    final ascending = [...uniqueDays]..sort((a, b) => a.compareTo(b));
    var longestStreak = 0;
    var run = 0;
    DateTime? prev;
    for (final day in ascending) {
      if (prev == null) {
        run = 1;
      } else {
        final diff = day.difference(prev).inDays;
        if (diff == 1) {
          run += 1;
        } else if (diff > 1) {
          run = 1;
        }
      }
      longestStreak = max(longestStreak, run);
      prev = day;
    }

    final latestReadingAt =
        readings.isNotEmpty ? readings.first.createdAt : null;
    final latestActivityAt = activity.lastActiveAt();
    final latestCreatedAt = _latestDate(
      latestReadingAt?.toLocal(),
      latestActivityAt,
    );
    return HomeStreakStats(
      currentStreakDays: currentStreak,
      longestStreakDays: longestStreak,
      activeDays: uniqueDays.length,
      awarenessPercent: base.awarenessPercent,
      awarenessLocked: base.awarenessLocked,
      lastActiveAt: latestCreatedAt,
    );
  }

  HomeStreakStats _mergeStreakStats({
    required HomeStreakStats remote,
    required HomeStreakStats local,
  }) {
    return HomeStreakStats(
      currentStreakDays: max(remote.currentStreakDays, local.currentStreakDays),
      longestStreakDays: max(remote.longestStreakDays, local.longestStreakDays),
      activeDays: max(remote.activeDays, local.activeDays),
      awarenessPercent: remote.awarenessPercent,
      awarenessLocked: remote.awarenessLocked,
      lastActiveAt: _latestDate(remote.lastActiveAt, local.lastActiveAt),
    );
  }

  DateTime? _latestDate(DateTime? first, DateTime? second) {
    if (first == null) {
      return second;
    }
    if (second == null) {
      return first;
    }
    return second.isAfter(first) ? second : first;
  }

  bool _sameStreakStats(HomeStreakStats a, HomeStreakStats b) {
    return a.currentStreakDays == b.currentStreakDays &&
        a.longestStreakDays == b.longestStreakDays &&
        a.activeDays == b.activeDays &&
        a.awarenessPercent == b.awarenessPercent &&
        a.awarenessLocked == b.awarenessLocked &&
        a.lastActiveAt == b.lastActiveAt;
  }

  Future<void> _loadReportEntitlements() async {
    if (_loadingReportEntitlements) {
      return;
    }
    setState(() {
      _loadingReportEntitlements = true;
    });
    _refreshOpenStreakModal();
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
      _refreshOpenStreakModal();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReportEntitlements = false;
      });
      _refreshOpenStreakModal();
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
    _refreshOpenStreakModal();
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
      _refreshOpenStreakModal();
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
                            : lang == 'fr'
                                ? 'Télécharger / partager le PDF'
                                : lang == 'tr'
                                    ? 'PDF indir / paylaş'
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

  Future<void> _loadHomeReferralStats() async {
    if (_homeReferralStatsRequested) {
      return;
    }
    _homeReferralStatsRequested = true;
    try {
      final data =
          await ref.read(userDashboardRepositoryProvider).fetchDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _homeReferralInvited = data.totalInvited;
        _homeReferralCredits = data.freeFiveCardsCredits;
        _homeReferralLink =
            data.referralLink.trim().isEmpty ? null : data.referralLink.trim();
      });
    } catch (_) {
      // Keep sharing available with local fallback link.
    }
  }

  String _resolveHomeReferralLink() {
    final fromDashboard = (_homeReferralLink ?? '').trim();
    if (fromDashboard.isNotEmpty) {
      return fromDashboard;
    }
    final profile = readTelegramUserProfile();
    if (profile != null) {
      return buildReferralLinkForUserId(profile.userId);
    }
    return 'https://t.me/tarot_arkana_bot/app';
  }

  String _homeInvitedLabel(BuildContext context) {
    final invited = _homeReferralInvited ?? 0;
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Приглашено: $invited';
    }
    if (code == 'kk') {
      return 'Шақырылғандар: $invited';
    }
    if (code == 'fr') {
      return 'Invités : $invited';
    }
    if (code == 'tr') {
      return 'Davet edilen: $invited';
    }
    return 'Invited: $invited';
  }

  String _homeBonusLabel(BuildContext context) {
    final credits = _homeReferralCredits ?? 0;
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Бонусы: $credits';
    }
    if (code == 'kk') {
      return 'Бонустар: $credits';
    }
    if (code == 'fr') {
      return 'Bonus : $credits';
    }
    if (code == 'tr') {
      return 'Bonuslar: $credits';
    }
    return 'Bonuses: $credits';
  }

  Future<void> _trackHomeInviteEvent(String eventName) async {
    try {
      await ref.read(inviteTelemetryRepositoryProvider).track(
        eventName: eventName,
        source: 'home_invite_card',
        metadata: <String, Object?>{
          'invited': _homeReferralInvited ?? -1,
          'credits': _homeReferralCredits ?? -1,
        },
      );
    } catch (_) {
      // Tracking must never block UX.
    }
  }

  Future<void> _shareHomeReferralLink(AppLocalizations l10n) async {
    final referralLink = _resolveHomeReferralLink();
    unawaited(_trackHomeInviteEvent('invite_share_clicked'));
    final text = '${l10n.resultReferralShareMessage}\n$referralLink';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.resultReferralCopied)),
    );
    final shareUri = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(referralLink)}'
      '&text=${Uri.encodeComponent(l10n.resultReferralShareMessage)}',
    );
    final opened = await launchUrl(
      shareUri,
      mode: LaunchMode.externalApplication,
    );
    if (opened) {
      unawaited(_trackHomeInviteEvent('invite_share_opened'));
    }
  }

  Future<void> _trackDailyStoryEvent(String eventName, CardModel card) async {
    try {
      await ref.read(inviteTelemetryRepositoryProvider).track(
        eventName: eventName,
        source: 'daily_story_card',
        metadata: <String, Object?>{
          'card_id': card.id,
          'card_name': card.name,
        },
      );
    } catch (_) {
      // Tracking must never block UX.
    }
  }

  Future<void> _shareDailyStory({
    required CardModel dailyCard,
    required _HomeStreakCopy copy,
  }) async {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final interpretationRaw = _dailyCardInterpretationCardId == dailyCard.id
        ? (_dailyCardInterpretation ?? '')
        : '';
    final interpretation = interpretationRaw.trim().isNotEmpty
        ? interpretationRaw.trim()
        : dailyCard.meaning.general.trim();
    final insight = interpretation.isEmpty
        ? dailyCard.name
        : interpretation.length > 180
            ? '${interpretation.substring(0, 180)}...'
            : interpretation;
    final link = _resolveHomeReferralLink();

    final storyText = switch (localeCode) {
      'ru' => 'the real magic · Карта дня: ${dailyCard.name}\n'
          'Инсайт: $insight\n'
          'Шаг дня: ${copy.dailyCardQuestion(dailyCard.name)}\n'
          'Забери свою карту дня:',
      'kk' => 'the real magic · Күн картасы: ${dailyCard.name}\n'
          'Инсайт: $insight\n'
          'Күн қадамы: ${copy.dailyCardQuestion(dailyCard.name)}\n'
          'Өзіңнің күн картаңды аш:',
      'fr' => 'the real magic · Carte du jour : ${dailyCard.name}\n'
          'Insight : $insight\n'
          'Étape du jour : ${copy.dailyCardQuestion(dailyCard.name)}\n'
          'Ouvre ta carte du jour :',
      'tr' => 'the real magic · Günün kartı: ${dailyCard.name}\n'
          'İçgörü: $insight\n'
          'Günün adımı: ${copy.dailyCardQuestion(dailyCard.name)}\n'
          'Günün kartını aç:',
      _ => 'the real magic · Card of the day: ${dailyCard.name}\n'
          'Insight: $insight\n'
          'Step of the day: ${copy.dailyCardQuestion(dailyCard.name)}\n'
          'Get your daily card:',
    };

    unawaited(_trackDailyStoryEvent('daily_story_share_clicked', dailyCard));
    await Clipboard.setData(ClipboardData(text: '$storyText\n$link'));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.resultReferralCopied)),
    );
    final shareUri = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(link)}'
      '&text=${Uri.encodeComponent(storyText)}',
    );
    final opened = await launchUrl(
      shareUri,
      mode: LaunchMode.externalApplication,
    );
    if (opened) {
      unawaited(_trackDailyStoryEvent('daily_story_share_opened', dailyCard));
    }
  }

  Future<void> _showHomeInviteInfoModal(AppLocalizations l10n) async {
    unawaited(_trackHomeInviteEvent('invite_info_opened'));
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
                  l10n.resultReferralTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.resultReferralBody,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                AppPrimaryButton(
                  label: l10n.resultReferralButton,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _shareHomeReferralLink(l10n);
                  },
                ),
              ],
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
                            foregroundColor: colorScheme.onPrimary,
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
    _detachLiveStatsListeners();
    _streakReloadDebounce?.cancel();
    _readingFlowSubscription?.close();
    _streakModalRefreshTick.dispose();
    _fieldGlowController.dispose();
    _titleShimmerController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshOpenStreakModal() {
    _streakModalRefreshTick.value++;
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

  void _openVibePromptsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: appRouteSettings(showBackButton: true),
        builder: (_) => const VibePromptsScreen(),
      ),
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
    final featureCopy = _HomeFeatureCopy.resolve(context);
    final streakCopy = _HomeStreakCopy.resolve(context);
    final deckHint = _deckHint(l10n, deckId);
    final cards = cardsAsync.maybeWhen(
        data: (list) => list, orElse: () => const <CardModel>[]);
    final dailyCard = _resolveDailyCard(cards, deckId);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primaryColor = colorScheme.primary;
    final disabledColor = Color.lerp(primaryColor, colorScheme.surface, 0.45)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompactScreen = screenHeight < 760;
    final questionMinLines = isCompactScreen ? 2 : 3;
    final questionMaxLines = isCompactScreen ? 6 : 8;
    if (!_homeInviteCardViewTracked) {
      _homeInviteCardViewTracked = true;
      unawaited(_trackHomeInviteEvent('invite_card_viewed'));
    }

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
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _VibeGhostButton(
                            text: l10n.homeDescription,
                            animation: _titleShimmerController,
                            onTap: _openVibePromptsScreen,
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
                          child: child,
                        );
                      },
                      child: RepaintBoundary(
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
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  108,
                                  16,
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
                                      onTap: () => _handlePrimaryAction(
                                        hasQuestion,
                                      ),
                                      backgroundColor: colorScheme.primary,
                                      iconColor: colorScheme.onPrimary,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        deckHint,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w400,
                            ),
                      ),
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
              _HomeInviteCompactCard(
                title: l10n.resultReferralTitle,
                invitedLabel: _homeInvitedLabel(context),
                bonusLabel: _homeBonusLabel(context),
                isLoading: !_homeReferralStatsRequested,
                onShareTap: () => _shareHomeReferralLink(l10n),
                onHelpTap: () => _showHomeInviteInfoModal(l10n),
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
    final allTimeStats = ref.read(cardStatsRepositoryProvider).getAllCounts();
    final cardById = <String, CardModel>{
      for (final card in cards) canonicalCardId(card.id): card,
    };
    return _buildEnergyProfileFromAllTimeStats(
      allTimeStats: allTimeStats,
      cardById: cardById,
      topCards: topCards,
      selectedDeck: selectedDeck,
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
      names[normalizedId] = _resolveProfileCardName(
        normalizedCardId: normalizedId,
        rawName: entry.key,
        cardById: cardById,
      );

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
                _resolveProfileCardName(
                  normalizedCardId: canonicalCardId(entry.key),
                  rawName: entry.key,
                  cardById: cardById,
                ),
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

  String _resolveProfileCardName({
    required String normalizedCardId,
    required String rawName,
    required Map<String, CardModel> cardById,
  }) {
    final catalogName = cardById[normalizedCardId]?.name.trim() ?? '';
    if (catalogName.isNotEmpty) {
      return catalogName;
    }
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return normalizedCardId;
    }
    final lower = trimmed.toLowerCase();
    final looksLikeAsset = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.avif') ||
        lower.endsWith('.mp4') ||
        lower.contains('/') ||
        lower.contains('\\');
    final looksLikeCardId = lower.startsWith('major_') ||
        lower.startsWith('ac_') ||
        lower.startsWith('wands_') ||
        lower.startsWith('cups_') ||
        lower.startsWith('swords_') ||
        lower.startsWith('pentacles_') ||
        lower.startsWith('lenormand_');
    if (looksLikeAsset || looksLikeCardId) {
      final withoutExt = trimmed.replaceFirst(
          RegExp(r'\.(png|jpe?g|webp|gif|avif|mp4)$', caseSensitive: false),
          '');
      final tokens = withoutExt
          .split(RegExp(r'[_\-\s]+'))
          .where((part) => part.trim().isNotEmpty)
          .toList();
      if (tokens.isNotEmpty) {
        return tokens
            .map((token) {
              final value = token.trim();
              if (value.isEmpty) {
                return '';
              }
              final lowerValue = value.toLowerCase();
              return '${lowerValue[0].toUpperCase()}${lowerValue.substring(1)}';
            })
            .where((part) => part.isNotEmpty)
            .join(' ');
      }
    }
    return trimmed;
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
    required List<CardModel> cards,
    required DeckType selectedDeck,
  }) async {
    final energyCopy = _EnergyProfileCopy.resolve(context);

    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const reportCtaReservedSpace = 176.0;
        return ValueListenableBuilder<int>(
          valueListenable: _streakModalRefreshTick,
          builder: (context, _, __) {
            final liveTopCards = _topCards(cards);
            final profile = _buildEnergyProfile(
              cards: cards,
              topCards: liveTopCards,
              selectedDeck: selectedDeck,
            );
            return FractionallySizedBox(
              heightFactor: 0.95,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.8),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
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
                          if (!_loadingStreak &&
                              _streakStats.lastActiveAt != null)
                            Text(
                              copy.lastActiveLabel(_streakStats.lastActiveAt!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.68),
                                  ),
                            ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView(
                              primary: false,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.only(
                                bottom: reportCtaReservedSpace,
                              ),
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
                                    activeDays: _streakStats.activeDays,
                                    onAskOracle: (question) =>
                                        _startReadingFromRhythmInsight(
                                      question,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.32),
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: SelfAnalysisReportCtaSection(
                              title: copy.reportSectionTitle,
                              body: copy.reportSectionBody,
                              paidLabel: copy.reportPaidCta,
                              freeLabel: copy.reportFreeCta,
                              helper: '',
                              isFree: _isReportFreeByEntitlements(),
                              isLoading: _reportFlowInFlight ||
                                  _loadingReportEntitlements,
                              isEnabled: !_loadingStreak,
                              onPressed: () => _onGenerateReportTap(
                                copy: copy,
                                selectedDeck: selectedDeck,
                              ),
                            ),
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
                    padding: const EdgeInsets.all(10),
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
                          width: 88,
                          child: AspectRatio(
                            aspectRatio: 0.68,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                              const SizedBox(height: 6),
                              Text(
                                () {
                                  final localeCode =
                                      Localizations.localeOf(sheetContext)
                                          .languageCode;
                                  if (localeCode == 'fr' ||
                                      localeCode == 'tr') {
                                    return copy.dailyCardFallback;
                                  }
                                  final summary =
                                      dailyCard.meaning.general.trim();
                                  return summary.isEmpty
                                      ? copy.dailyCardFallback
                                      : summary;
                                }(),
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.8),
                                      height: 1.32,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    onShareStory: () => _shareDailyStory(
                      dailyCard: dailyCard,
                      copy: copy,
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

  void _handlePrimaryAction(bool hasQuestion) {
    if (!hasQuestion) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      return;
    }
    final normalizedQuestion = _controller.text.trim();
    final flow = ref.read(readingFlowControllerProvider.notifier);
    flow.reset();
    flow.setQuestion(normalizedQuestion);
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: false),
        builder: (_) => const SpreadScreen(),
      ),
    );
  }

  void _startReadingFromRhythmInsight(String question) {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      return;
    }
    _controller.text = normalizedQuestion;
    final flow = ref.read(readingFlowControllerProvider.notifier);
    flow.reset();
    flow.setQuestion(normalizedQuestion);
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: appRouteSettings(showBackButton: false),
          builder: (_) => const SpreadScreen(),
        ),
      );
    });
  }

  String _deckHint(AppLocalizations l10n, DeckType deckId) {
    return switch (deckId) {
      DeckType.lenormand => '${l10n.deckLabel}: ${l10n.deckLenormandName}',
      DeckType.crowley => '${l10n.deckLabel}: ${l10n.deckCrowleyName}',
      _ => '${l10n.deckLabel}: ${l10n.deckTarotRiderWaite}',
    };
  }
}

class _HomeInviteCompactCard extends StatelessWidget {
  const _HomeInviteCompactCard({
    required this.title,
    required this.invitedLabel,
    required this.bonusLabel,
    required this.isLoading,
    required this.onShareTap,
    required this.onHelpTap,
  });

  final String title;
  final String invitedLabel;
  final String bonusLabel;
  final bool isLoading;
  final Future<void> Function() onShareTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Ink(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icon/home_invite.svg',
            width: 28,
            height: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                if (isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  Text(
                    '$invitedLabel · $bonusLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onShareTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icon/home_share.svg',
                    width: 13,
                    height: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _shareLabel(context),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onHelpTap,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SvgPicture.asset(
                'assets/icon/help_circle.svg',
                width: 16,
                height: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shareLabel(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Поделиться';
    }
    if (code == 'kk') {
      return 'Бөлісу';
    }
    if (code == 'fr') {
      return 'Partager';
    }
    if (code == 'tr') {
      return 'Paylaş';
    }
    return 'Share';
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

class _VibeGhostButton extends StatelessWidget {
  const _VibeGhostButton({
    required this.text,
    required this.animation,
    required this.onTap,
  });

  final String text;
  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.88),
          fontWeight: FontWeight.w500,
        );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.62),
            ),
            color: colorScheme.surface.withValues(alpha: 0.14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShimmerTitle(
                text: text,
                animation: animation,
                baseStyle: textStyle,
                shimmerColor: colorScheme.primary.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(
                'assets/icon/home_dice.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withValues(alpha: 0.8),
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (code == 'fr') {
      return _HomeOnboardingCopy(
        title: 'The real magic',
        subtitle: subtitle,
        itemLenormand: 'Tirage Lenormand',
        itemLenormandHint: 'Choisis le jeu dans le profil',
        itemCompatibility: 'Compatibilité du couple',
        itemCompatibilityHint: 'Essaie gratuitement',
        itemNatal: 'Lecture du thème natal',
        itemNatalHint: 'Essaie gratuitement',
        closeButton: 'Super',
      );
    }
    if (code == 'tr') {
      return _HomeOnboardingCopy(
        title: 'The real magic',
        subtitle: subtitle,
        itemLenormand: 'Lenormand açılımı',
        itemLenormandHint: 'Desteyi profilden seç',
        itemCompatibility: 'Çift uyumluluk testi',
        itemCompatibilityHint: 'Ücretsiz dene',
        itemNatal: 'Doğum haritası yorumu',
        itemNatalHint: 'Ücretsiz dene',
        closeButton: 'Harika',
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
    required this.localeCode,
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
    required this.patternShortTitle,
    required this.archetypeShortTitle,
    required this.patternDetailsTitle,
    required this.archetypeDetailsTitle,
    required this.repeatsPercentMeaningPrefix,
    required this.repeatsPercentMeaningSuffix,
    required this.askOracleCta,
    required this.patternPromptPrefix,
    required this.archetypePromptPrefix,
  });

  final String localeCode;
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
  final String patternShortTitle;
  final String archetypeShortTitle;
  final String patternDetailsTitle;
  final String archetypeDetailsTitle;
  final String repeatsPercentMeaningPrefix;
  final String repeatsPercentMeaningSuffix;
  final String askOracleCta;
  final String patternPromptPrefix;
  final String archetypePromptPrefix;

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
      if (localeCode == 'ru') {
        return 'Сейчас доминирует $dominantLabel. Это твой основной вектор периода.';
      }
      if (localeCode == 'kk') {
        return 'Қазір $dominantLabel басым. Осы кезеңнің негізгі бағыты осы.';
      }
      if (localeCode == 'fr') {
        return 'En ce moment, $dominantLabel domine. C est votre axe principal de la période.';
      }
      if (localeCode == 'tr') {
        return 'Şu anda $dominantLabel baskın. Bu dönemin ana yönü bu.';
      }
      return 'Your pattern is led by $dominantLabel right now.';
    }
    final supportLabel = elementLabel(deckType, support).toLowerCase();
    if (localeCode == 'ru') {
      return 'Ты в фазе, где $dominantLabel ведёт, а $supportLabel поддерживает движение.';
    }
    if (localeCode == 'kk') {
      return '$dominantLabel алда, ал $supportLabel оны қолдап тұр.';
    }
    if (localeCode == 'fr') {
      return 'Vous êtes dans une phase où $dominantLabel mène et $supportLabel soutient le mouvement.';
    }
    if (localeCode == 'tr') {
      return '$dominantLabel önde, $supportLabel ise akışı destekliyor.';
    }
    return 'You are in a phase where $dominantLabel leads and $supportLabel supports it.';
  }

  String archetypeDescription(String cardName) {
    if (localeCode == 'ru') {
      return 'Ведущий архетип сейчас: $cardName. Используй его как ориентир для решений ближайших дней.';
    }
    if (localeCode == 'kk') {
      return 'Қазір жетекші архетип: $cardName. Жақын күндердегі шешімдерде осыны бағдар етіңіз.';
    }
    if (localeCode == 'fr') {
      return 'Votre archétype dominant actuel est $cardName. Utilisez-le comme repère pour les décisions des prochains jours.';
    }
    if (localeCode == 'tr') {
      return 'Şu anki baskın arketipiniz $cardName. Önümüzdeki günlerde karar verirken bunu pusula olarak kullanın.';
    }
    return 'Your current leading archetype is $cardName. Use it as a compass for near-term decisions.';
  }

  String localeHint(int streakDays) {
    if (localeCode == 'ru') {
      return 'Серия $streakDays дней усиливает точность профиля.';
    }
    if (localeCode == 'kk') {
      return '$streakDays күндік серия профиль дәлдігін арттырады.';
    }
    if (localeCode == 'fr') {
      return 'Une série de $streakDays jours améliore la précision du profil.';
    }
    if (localeCode == 'tr') {
      return '$streakDays günlük seri profil doğruluğunu artırır.';
    }
    return '$streakDays-day streak improves profile precision.';
  }

  String repeatsPercentMeaning(int percent) {
    return '$repeatsPercentMeaningPrefix $percent%$repeatsPercentMeaningSuffix';
  }

  List<String> patternDetailParagraphs({
    required DeckType deckType,
    required int percent,
    required _ElementKind? dominant,
    required _ElementKind? support,
  }) {
    return [
      destinySummary(deckType, percent),
      phaseSummary(
        deckType: deckType,
        dominant: dominant,
        support: support,
      ),
    ];
  }

  List<String> archetypeDetailParagraphs(String? cardName) {
    if (cardName == null) {
      return [
        archetypeDescriptionFallback,
        phaseSummaryFallback,
      ];
    }
    return [
      archetypeDescription(cardName),
      localeCode == 'ru'
          ? 'Архетип $cardName показывает стиль действий на ближайший цикл. Чем чаще он повторяется, тем точнее подсказывает твой следующий шаг.'
          : localeCode == 'kk'
              ? '$cardName архетипі жақын циклдегі әрекет стилін көрсетеді. Ол жиірек қайталанған сайын, келесі қадамды дәлірек көрсетеді.'
              : localeCode == 'fr'
                  ? 'L archétype $cardName reflète votre style d action actuel. Plus il se répète, plus votre prochaine étape devient claire.'
                  : localeCode == 'tr'
                      ? '$cardName arketipi mevcut eylem tarzınızı gösterir. Ne kadar sık tekrar ederse sonraki adım o kadar netleşir.'
                      : '$cardName archetype reflects your current action style. The more often it repeats, the clearer your next move becomes.',
    ];
  }

  String patternAskQuestion({
    required DeckType deckType,
    required int percent,
  }) {
    final patternName = destinyTitle(deckType);
    return '$patternPromptPrefix $patternName $percent%';
  }

  String archetypeAskQuestion(String? cardName) {
    final resolved = cardName ?? archetypeFallback;
    return '$archetypePromptPrefix $resolved';
  }

  static _EnergyProfileCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _EnergyProfileCopy(
        localeCode: 'ru',
        title: 'Твой текущий энергетический паттерн',
        subtitle: 'Аналитика по всей истории активности',
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
        repeatsTitle: 'Повторяющиеся сигналы',
        repeatsFallback: 'Явных повторов пока нет.',
        sampleWindowLabel: 'На основе всей истории карт',
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
        patternShortTitle: 'Паттерн',
        archetypeShortTitle: 'Архетип',
        patternDetailsTitle: 'Интенсивность паттерна',
        archetypeDetailsTitle: 'Доминирующий архетип',
        repeatsPercentMeaningPrefix: 'Осознанность',
        repeatsPercentMeaningSuffix:
            ' — это индекс устойчивости сигнала: чем выше процент, тем чаще тема повторяется в твоей истории.',
        askOracleCta: 'Спросить оракула',
        patternPromptPrefix:
            'Разбери мой текущий паттерн и дай следующий шаг. Фокус:',
        archetypePromptPrefix:
            'Разбери мой доминирующий архетип и дай практический совет. Архетип:',
      );
    }
    if (code == 'kk') {
      return const _EnergyProfileCopy(
        localeCode: 'kk',
        title: 'Сенің ағымдағы энергия паттернің',
        subtitle: 'Белсенділіктің толық тарихы аналитикасы',
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
        repeatsTitle: 'Қайталанатын сигналдар',
        repeatsFallback: 'Айқын қайталанулар әзірге жоқ.',
        sampleWindowLabel: 'Карталар толық тарихы негізінде',
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
        patternShortTitle: 'Паттерн',
        archetypeShortTitle: 'Архетип',
        patternDetailsTitle: 'Паттерн қарқындылығы',
        archetypeDetailsTitle: 'Басым архетип',
        repeatsPercentMeaningPrefix: 'Осознанность',
        repeatsPercentMeaningSuffix:
            ' — сигнал тұрақтылығының индексі: пайыз жоғары болған сайын тақырып тарихта жиі қайталанады.',
        askOracleCta: 'Оракулдан сұрау',
        patternPromptPrefix:
            'Қазіргі паттернімді талдап, келесі қадам бер. Фокус:',
        archetypePromptPrefix:
            'Басым архетипімді талдап, практикалық кеңес бер. Архетип:',
      );
    }
    if (code == 'fr') {
      return const _EnergyProfileCopy(
        localeCode: 'fr',
        title: 'Votre modèle énergétique actuel',
        subtitle: 'Analyse basée sur tout votre historique d activité',
        emptyState:
            'Pas encore assez de données. Faites quelques tirages et ce profil se remplira.',
        elementsTitleRider: 'Roue des éléments',
        elementsTitleLenormand: 'Roue des histoires',
        elementsTitleCrowley: 'Roue des phases arcaniques',
        destinyTitleRider: 'Intensité du destin',
        destinyTitleAlt: 'Intensité du modèle',
        destinyLowRider: 'Phase de fond : vous gardez le contrôle',
        destinyHighRider: 'Phase à fort impact sur le destin',
        destinyLowAlt: 'Le modèle est souple et diffus',
        destinyHighAlt: 'Le modèle est concentré et intense',
        archetypeTitle: 'Archétype dominant',
        archetypeFallback: 'Archétype en formation',
        repeatsTitle: 'Signaux récurrents',
        repeatsFallback: 'Pas encore de répétitions nettes.',
        sampleWindowLabel: 'Basé sur tout votre historique de cartes',
        elementAction: 'Bâtons',
        elementEmotion: 'Coupes',
        elementMind: 'Épées',
        elementMatter: 'Pentacles',
        lenormandMovement: 'Mouvement',
        lenormandRelations: 'Relations',
        lenormandChallenges: 'Défis',
        lenormandMaterial: 'Ressources',
        crowleyImpulse: 'Impulsion',
        crowleyChoice: 'Choix',
        crowleyTransformation: 'Transformation',
        crowleyIntegration: 'Intégration',
        phaseSummaryFallback:
            'Le profil collecte encore des signaux, le résumé reste donc neutre pour le moment.',
        archetypeDescriptionFallback:
            'Lorsque davantage de tirages seront disponibles, votre archétype dominant apparaîtra ici.',
        patternShortTitle: 'Modèle',
        archetypeShortTitle: 'Archétype',
        patternDetailsTitle: 'Intensité du modèle',
        archetypeDetailsTitle: 'Archétype dominant',
        repeatsPercentMeaningPrefix: 'Conscience',
        repeatsPercentMeaningSuffix:
            ' est un indice de stabilité : plus le pourcentage est élevé, plus ce signal se répète dans votre historique.',
        askOracleCta: 'Demander à l Oracle',
        patternPromptPrefix:
            'Analyse mon modèle actuel et propose la prochaine étape. Focus :',
        archetypePromptPrefix:
            'Analyse mon archétype dominant et propose une étape pratique. Archétype :',
      );
    }
    if (code == 'tr') {
      return const _EnergyProfileCopy(
        localeCode: 'tr',
        title: 'Mevcut enerji kalıbın',
        subtitle: 'Tüm etkinlik geçmişinden analiz',
        emptyState:
            'Henüz yeterli veri yok. Birkaç açılım yapın, profil dolmaya başlayacak.',
        elementsTitleRider: 'Element çarkı',
        elementsTitleLenormand: 'Hikâye çarkı',
        elementsTitleCrowley: 'Arkana faz çarkı',
        destinyTitleRider: 'Kader yoğunluğu',
        destinyTitleAlt: 'Kalıp yoğunluğu',
        destinyLowRider: 'Arka plan fazı: direksiyon sizde',
        destinyHighRider: 'Kaderi şekillendiren faz',
        destinyLowAlt: 'Kalıp yumuşak ve yaygın',
        destinyHighAlt: 'Kalıp yoğun ve güçlü',
        archetypeTitle: 'Baskın arketip',
        archetypeFallback: 'Arketip oluşuyor',
        repeatsTitle: 'Tekrarlayan sinyaller',
        repeatsFallback: 'Henüz güçlü tekrar yok.',
        sampleWindowLabel: 'Tüm kart geçmişinize göre',
        elementAction: 'Değnekler',
        elementEmotion: 'Kupalar',
        elementMind: 'Kılıçlar',
        elementMatter: 'Tılsımlar',
        lenormandMovement: 'Hareket',
        lenormandRelations: 'İlişkiler',
        lenormandChallenges: 'Zorluklar',
        lenormandMaterial: 'Kaynaklar',
        crowleyImpulse: 'İtki',
        crowleyChoice: 'Seçim',
        crowleyTransformation: 'Dönüşüm',
        crowleyIntegration: 'Entegrasyon',
        phaseSummaryFallback:
            'Profil hâlâ sinyal topluyor; bu yüzden özet şimdilik nötr.',
        archetypeDescriptionFallback:
            'Daha fazla açılım biriktikçe baskın arketipiniz burada görünecek.',
        patternShortTitle: 'Kalıp',
        archetypeShortTitle: 'Arketip',
        patternDetailsTitle: 'Kalıp yoğunluğu',
        archetypeDetailsTitle: 'Baskın arketip',
        repeatsPercentMeaningPrefix: 'Farkındalık',
        repeatsPercentMeaningSuffix:
            ' bir istikrar indeksidir: yüzde ne kadar yüksekse bu sinyal geçmişinizde o kadar sık tekrar eder.',
        askOracleCta: 'Kâhine sor',
        patternPromptPrefix:
            'Mevcut kalıbımı yorumla ve bir sonraki adımı öner. Odak:',
        archetypePromptPrefix:
            'Baskın arketipimi yorumla ve pratik bir sonraki adımı ver. Arketip:',
      );
    }
    return const _EnergyProfileCopy(
      localeCode: 'en',
      title: 'Your current energy pattern',
      subtitle: 'Analytics from your full activity history',
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
      repeatsTitle: 'Recurring signals',
      repeatsFallback: 'No strong repeats yet.',
      sampleWindowLabel: 'Based on your full card history',
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
      patternShortTitle: 'Pattern',
      archetypeShortTitle: 'Archetype',
      patternDetailsTitle: 'Pattern intensity',
      archetypeDetailsTitle: 'Dominant archetype',
      repeatsPercentMeaningPrefix: 'Awareness',
      repeatsPercentMeaningSuffix:
          ' is a stability index: the higher the percent, the more often this signal repeats in your history.',
      askOracleCta: 'Ask Oracle',
      patternPromptPrefix:
          'Read my current pattern and suggest the next step. Focus:',
      archetypePromptPrefix:
          'Read my dominant archetype and give a practical next step. Archetype:',
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
    required this.dailyCardShareCta,
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
  final String dailyCardShareCta;
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
        dailyCardShareCta: 'Поделиться историей дня',
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
        dailyCardShareCta: 'Күн тарихымен бөлісу',
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
    if (code == 'fr') {
      return const _HomeStreakCopy(
        tileLoadingTitle: '...',
        tileLoadingSubtitle: 'Chargement de la série...',
        tileSubtitle: 'Série et statistiques',
        modalTitle: 'Votre série',
        currentStreakLabel: 'Actuelle',
        bestStreakLabel: 'Record',
        awarenessLabel: 'Conscience',
        dailyCardTileTitle: 'Carte du jour',
        dailyCardModalTitle: 'Carte du jour',
        dailyCardFallback: 'Sélection de la carte...',
        dailyCardPending:
            'Interprétation de ce que cette carte signifie pour vous aujourd hui...',
        dailyCardError: 'Impossible de charger l interprétation. Réessayez.',
        dailyCardBadgeLabel: 'Énergie du jour',
        dailyCardInsightTitle: 'Interprétation',
        dailyCardActionsTitle: 'Passer à l étape suivante',
        dailyCardPrimaryCta: 'Lancer un tirage à partir de cette carte',
        dailyCardSecondaryCta: 'Consultation personnelle avec Sofia',
        dailyCardShareCta: 'Partager l histoire du jour',
        dailyCardQuestionPrefix:
            'Quelle prochaine étape dois-je faire aujourd hui en tenant compte de la carte',
        streakLoadingSubtitle: 'Chargement de la série la plus récente...',
        reportSectionTitle: 'Rapport personnel',
        reportSectionBody:
            'Rapport de coaching basé sur vos 30 derniers jours de tirages : tendances, équilibre et recommandations.',
        reportPaidCta: 'Obtenir le rapport (PDF) — 200 ⭐',
        reportFreeCta: 'Obtenir le rapport (PDF) — gratuit',
        reportHelper: 'Basé sur votre historique des 30 derniers jours',
        reportInsufficientTitle: 'Données insuffisantes',
        reportInsufficientBody:
            'Il faut au moins 10 cartes sur les 30 derniers jours. Faites encore quelques tirages puis revenez.',
        reportConfirmTitle: 'Générer le rapport ?',
        reportConfirmBody:
            'Nous allons créer un rapport PDF sur vos 30 derniers jours de tirages. Prix — 200 ⭐.',
        reportConfirmContinue: 'Continuer',
        reportConfirmCancel: 'Annuler',
        reportReadyTitle: 'Rapport prêt',
        reportOpenPdf: 'Ouvrir le PDF',
        reportSharePdf: 'Partager',
        reportGenerateFailed:
            'Impossible de générer le PDF après paiement. Contactez le support, nous vous aiderons.',
        lastActivePrefix: 'Dernière activité',
        closeLabel: 'Fermer',
        dayUnit: _frDayUnit,
      );
    }
    if (code == 'tr') {
      return const _HomeStreakCopy(
        tileLoadingTitle: '...',
        tileLoadingSubtitle: 'Seri yükleniyor...',
        tileSubtitle: 'Seri ve istatistikler',
        modalTitle: 'Seriniz',
        currentStreakLabel: 'Mevcut',
        bestStreakLabel: 'En iyi',
        awarenessLabel: 'Farkındalık',
        dailyCardTileTitle: 'Günün kartı',
        dailyCardModalTitle: 'Günün kartı',
        dailyCardFallback: 'Kart seçiliyor...',
        dailyCardPending: 'Bu kartın bugün sizin için anlamını yorumluyoruz...',
        dailyCardError: 'Yorum yüklenemedi. Tekrar deneyin.',
        dailyCardBadgeLabel: 'Günün enerjisi',
        dailyCardInsightTitle: 'Yorum',
        dailyCardActionsTitle: 'Bir sonraki adım',
        dailyCardPrimaryCta: 'Bu kartla açılıma başla',
        dailyCardSecondaryCta: 'Sofia ile kişisel danışmanlık',
        dailyCardShareCta: 'Günün hikâyesini paylaş',
        dailyCardQuestionPrefix:
            'Bu karta göre bugün hangi sonraki adımı atmalıyım',
        streakLoadingSubtitle: 'En güncel seri yükleniyor...',
        reportSectionTitle: 'Kişisel rapor',
        reportSectionBody:
            'Son 30 günlük açılımlarınıza dayalı koç tarzı rapor: kalıplar, denge ve nazik öneriler.',
        reportPaidCta: 'Raporu al (PDF) — 200 ⭐',
        reportFreeCta: 'Raporu al (PDF) — ücretsiz',
        reportHelper: 'Son 30 günlük açılım geçmişinize göre',
        reportInsufficientTitle: 'Yetersiz veri',
        reportInsufficientBody:
            'Son 30 günde en az 10 kart gerekiyor. Birkaç açılım daha yapıp tekrar gelin.',
        reportConfirmTitle: 'Rapor oluşturulsun mu?',
        reportConfirmBody:
            'Son 30 günlük açılımlarınızdan bir PDF raporu oluşturacağız. Ücret — 200 ⭐.',
        reportConfirmContinue: 'Devam et',
        reportConfirmCancel: 'İptal',
        reportReadyTitle: 'Rapor hazır',
        reportOpenPdf: 'PDF aç',
        reportSharePdf: 'Paylaş',
        reportGenerateFailed:
            'Ödeme sonrası PDF oluşturulamadı. Lütfen destekle iletişime geçin.',
        lastActivePrefix: 'Son etkinlik',
        closeLabel: 'Kapat',
        dayUnit: _trDayUnit,
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
      dailyCardShareCta: 'Share daily story',
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
    required this.onShareStory,
  });

  final _HomeStreakCopy copy;
  final VoidCallback onStartReading;
  final VoidCallback onSofiaTap;
  final VoidCallback onShareStory;

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
          AppPrimaryButton(
            label: copy.dailyCardPrimaryCta,
            onPressed: onStartReading,
          ),
          const SizedBox(height: 8),
          AppGhostButton(
            label: copy.dailyCardSecondaryCta,
            onPressed: onSofiaTap,
          ),
          const SizedBox(height: 8),
          AppGhostButton(
            label: copy.dailyCardShareCta,
            icon: Icons.ios_share,
            onPressed: onShareStory,
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
    required this.activeDays,
    required this.onAskOracle,
  });

  final _EnergyProfileCopy copy;
  final _EnergyProfileData profile;
  final int streakDays;
  final int activeDays;
  final ValueChanged<String> onAskOracle;

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
                Color(0xFF67D8C7),
                Color(0xFF7DA8FF),
                Color(0xFFCF96FF),
                Color(0xFF7EDB9A),
              ]
            : const [
                Color(0xFFFF8E6A),
                Color(0xFF71C6F2),
                Color(0xFFC4B8FF),
                Color(0xFFF2CD6E),
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
    final mainSignal =
        profile.repeatedSignals.isEmpty ? null : profile.repeatedSignals.first;
    final achievements = _buildAchievements(streakDays);
    final recentGoal = max(3, min(30, (activeDays / 2).round()));
    final cadencePercent = activeDays <= 0
        ? 0
        : ((activeDays / recentGoal) * 100).round().clamp(0, 100);

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
            colorScheme.primary.withValues(alpha: 0.08),
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
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.34),
                ),
              ),
              child: Row(
                children: [
                  _EnergyDonutChart(
                    slices: slices,
                    centerLabel: '${profile.sampledCardsCount}',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.circleTitle(profile.deckType),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InsightMetricTile(
                    title: copy.patternShortTitle,
                    value: '${profile.majorArcanaPercent}%',
                    subtitle: copy.destinySummary(
                      profile.deckType,
                      profile.majorArcanaPercent,
                    ),
                    accent: palette[0],
                    onTap: () => _showInsightDetails(
                      context,
                      title: copy.patternDetailsTitle,
                      headline: '${profile.majorArcanaPercent}%',
                      paragraphs: copy.patternDetailParagraphs(
                        deckType: profile.deckType,
                        percent: profile.majorArcanaPercent,
                        dominant: profile.dominantElement,
                        support: profile.supportElement,
                      ),
                      ctaLabel: copy.askOracleCta,
                      onCtaTap: () => onAskOracle(
                        copy.patternAskQuestion(
                          deckType: profile.deckType,
                          percent: profile.majorArcanaPercent,
                        ),
                      ),
                      accent: palette[0],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InsightMetricTile(
                    title: copy.archetypeShortTitle,
                    value: profile.dominantArchetype ?? copy.archetypeFallback,
                    subtitle: profile.dominantArchetype == null
                        ? copy.archetypeDescriptionFallback
                        : copy.archetypeDescription(profile.dominantArchetype!),
                    accent: palette[1],
                    onTap: () => _showInsightDetails(
                      context,
                      title: copy.archetypeDetailsTitle,
                      headline:
                          profile.dominantArchetype ?? copy.archetypeFallback,
                      paragraphs: copy.archetypeDetailParagraphs(
                        profile.dominantArchetype,
                      ),
                      ctaLabel: copy.askOracleCta,
                      onCtaTap: () => onAskOracle(
                        copy.archetypeAskQuestion(
                          profile.dominantArchetype,
                        ),
                      ),
                      accent: palette[1],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InsightMetricTile(
              title: copy.repeatsTitle,
              value: mainSignal == null
                  ? copy.repeatsFallback
                  : '${mainSignal.cardName} · ${mainSignal.count30d}x',
              subtitle: copy.phaseSummary(
                deckType: profile.deckType,
                dominant: profile.dominantElement,
                support: profile.supportElement,
              ),
              accent: palette[2],
              trailingTrend: cadencePercent,
            ),
            const SizedBox(height: 6),
            Text(
              copy.repeatsPercentMeaning(cadencePercent),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 14),
            _EnergySectionTitle(text: _awardsTitle(context)),
            const SizedBox(height: 8),
            _AchievementGrid(
              achievements: achievements,
              streakDays: streakDays,
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

  String _awardsTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Награды ритма';
    }
    if (code == 'kk') {
      return 'Ритм марапаттары';
    }
    if (code == 'fr') {
      return 'Récompenses du rythme';
    }
    if (code == 'tr') {
      return 'Ritim ödülleri';
    }
    return 'Rhythm awards';
  }

  List<_AchievementMilestone> _buildAchievements(int streak) {
    final thresholds = <int>[3, 5, 7, 14, 21];
    final milestones = <_AchievementMilestone>[];
    for (final value in thresholds) {
      milestones.add(_AchievementMilestone(days: value));
    }
    final monthlyMax = max(30, ((streak + 29) ~/ 30) * 30);
    for (var month = 30; month <= monthlyMax; month += 30) {
      milestones.add(_AchievementMilestone(days: month, isMonthly: true));
    }
    return milestones;
  }

  void _showInsightDetails(
    BuildContext context, {
    required String title,
    required String headline,
    required List<String> paragraphs,
    required String ctaLabel,
    required VoidCallback onCtaTap,
    required Color accent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.62,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.96),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                ),
              ),
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
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < paragraphs.length; i++) ...[
                            Text(
                              paragraphs[i],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.86),
                                    height: 1.4,
                                  ),
                            ),
                            if (i != paragraphs.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onCtaTap();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        ctaLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onPrimary,
                            ),
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
}

class _InsightMetricTile extends StatelessWidget {
  const _InsightMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.trailingTrend,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final int? trailingTrend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trend = trailingTrend?.clamp(0, 100);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.surface.withValues(alpha: 0.32),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (trend != null) _MiniTrendBubble(percent: trend),
                  if (trend == null && onTap != null) ...[
                    const SizedBox(width: 6),
                    const _InsightTapPlusBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightTapPlusBadge extends StatelessWidget {
  const _InsightTapPlusBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const svg = '''
<svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
  <path d="M8 3.2v9.6M3.2 8h9.6" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''';
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.45),
        ),
      ),
      child: Center(
        child: SvgPicture.string(
          svg,
          width: 10,
          height: 10,
          colorFilter: ColorFilter.mode(
            colorScheme.primary.withValues(alpha: 0.95),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _MiniTrendBubble extends StatelessWidget {
  const _MiniTrendBubble({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUp = percent >= 50;
    final iconSvg = isUp
        ? '''
<svg viewBox="0 0 12 12" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 2.2l2.6 2.6H7.1v4.5H4.9V4.8H3.4L6 2.2z" fill="#ffffff"/>
</svg>
'''
        : '''
<svg viewBox="0 0 12 12" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 9.8L3.4 7.2h1.5V2.7h2.2v4.5h1.5L6 9.8z" fill="#ffffff"/>
</svg>
''';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (isUp ? const Color(0xFF73DBA1) : const Color(0xFFFF9D8D))
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.string(
            iconSvg,
            width: 11,
            height: 11,
            colorFilter: ColorFilter.mode(
              isUp ? const Color(0xFF73DBA1) : const Color(0xFFFF9D8D),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$percent%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AchievementMilestone {
  const _AchievementMilestone({
    required this.days,
    this.isMonthly = false,
  });

  final int days;
  final bool isMonthly;
}

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({
    required this.achievements,
    required this.streakDays,
  });

  final List<_AchievementMilestone> achievements;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const columns = 3;
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in achievements)
              SizedBox(
                width: itemWidth,
                child: _AchievementBadge(
                  days: item.days,
                  unlocked: streakDays >= item.days,
                  isMonthly: item.isMonthly,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.days,
    required this.unlocked,
    required this.isMonthly,
  });

  final int days;
  final bool unlocked;
  final bool isMonthly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = unlocked
        ? colorScheme.primary.withValues(alpha: 0.18)
        : colorScheme.surface.withValues(alpha: 0.24);
    final border = unlocked
        ? colorScheme.primary.withValues(alpha: 0.5)
        : colorScheme.outlineVariant.withValues(alpha: 0.35);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AchievementIcon(unlocked: unlocked, monthly: isMonthly),
          const SizedBox(width: 6),
          Text(
            '$days',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 2),
          Text(
            _dayShort(context),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _dayShort(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'дн';
    }
    if (code == 'kk') {
      return 'күн';
    }
    if (code == 'fr') {
      return 'j';
    }
    if (code == 'tr') {
      return 'g';
    }
    return 'd';
  }
}

class _AchievementIcon extends StatelessWidget {
  const _AchievementIcon({
    required this.unlocked,
    required this.monthly,
  });

  final bool unlocked;
  final bool monthly;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? const Color(0xFFFFD574) : const Color(0xFF7E7A95);
    final svg = monthly
        ? '''
<svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
  <path d="M10 2.2l2 4.1 4.5.7-3.2 3.1.8 4.4-4.1-2.2-4.1 2.2.8-4.4-3.2-3.1 4.5-.7L10 2.2z" fill="#ffffff"/>
</svg>
'''
        : '''
<svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
  <circle cx="10" cy="10" r="7" fill="none" stroke="#ffffff" stroke-width="1.8"/>
  <path d="M6.2 10.4l2.3 2.2 5.3-5.3" fill="none" stroke="#ffffff" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';
    return SvgPicture.string(
      svg,
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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

class _EnergyDonutChart extends StatefulWidget {
  const _EnergyDonutChart({
    required this.slices,
    required this.centerLabel,
  });

  final List<_EnergySlice> slices;
  final String centerLabel;

  @override
  State<_EnergyDonutChart> createState() => _EnergyDonutChartState();
}

class _EnergyDonutChartState extends State<_EnergyDonutChart>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _revealController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([_revealController, _orbitController]),
      builder: (context, _) {
        final reveal = Curves.easeOutCubic.transform(_revealController.value);
        return SizedBox(
          width: 126,
          height: 126,
          child: CustomPaint(
            painter: _DonutChartPainter(
              slices: widget.slices,
              trackColor: colorScheme.surface.withValues(alpha: 0.38),
              progress: reveal,
              orbitPhase: _orbitController.value,
            ),
            child: Center(
              child: Text(
                widget.centerLabel,
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

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.slices,
    required this.trackColor,
    required this.progress,
    required this.orbitPhase,
  });

  final List<_EnergySlice> slices;
  final Color trackColor;
  final double progress;
  final double orbitPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.12;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF9A7CFF).withValues(alpha: 0.20),
          const Color(0xFF58C8FF).withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.22));
    canvas.drawCircle(center, radius * 1.15, auraPaint);

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
      final drawSweep = max(0.0, sweep - 0.05);
      if (sweep <= 0.001) {
        start += fullSweep;
        continue;
      }
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 3
        ..strokeCap = StrokeCap.round
        ..color = slice.color.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
      canvas.drawArc(rect, start, drawSweep, false, glowPaint);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = slice.color.withValues(alpha: 0.98);
      canvas.drawArc(rect, start, drawSweep, false, paint);

      final markerAngle = start + drawSweep / 2;
      final markerOffset = Offset(
        center.dx + cos(markerAngle) * radius,
        center.dy + sin(markerAngle) * radius,
      );
      canvas.drawCircle(
        markerOffset,
        2.1,
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
      start += fullSweep;
    }

    final orbitRadius = radius + stroke * 0.84;
    final orbitAngle = -pi / 2 + (pi * 2 * orbitPhase);
    final orbitOffset = Offset(
      center.dx + cos(orbitAngle) * orbitRadius,
      center.dy + sin(orbitAngle) * orbitRadius,
    );
    final orbitGlowPaint = Paint()
      ..color = const Color(0xFF8BF3D6).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(orbitOffset, 4.2, orbitGlowPaint);
    canvas.drawCircle(
      orbitOffset,
      2.2,
      Paint()..color = const Color(0xFFC5FFF0),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progress != progress ||
        oldDelegate.orbitPhase != orbitPhase;
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
    if (code == 'fr') {
      return 'Patiente une seconde…';
    }
    if (code == 'tr') {
      return 'Birkaç saniye bekleyin…';
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
    if (code == 'fr') {
      return const _SofiaCopy(
        sofiaName: '@SofiaKnoxx',
        consentTitle: 'Consentement au traitement des données',
        consentBodyPrefix: 'Autoriser l envoi de votre nom à notre astrologue',
        consentBodySuffix: 'pour les notifications',
        acceptButton: 'J accepte',
        rejectButton: 'Je refuse',
        infoCardTitle: 'Notre tarologue-astrologue Sofia',
        modalTitle: 'Notre tarologue-astrologue Sofia',
        consentModalBody:
            'Vous pouvez autoriser l envoi de votre nom et de votre username Telegram à Sofia pour les notifications. Destinataire : @SofiaKnoxx.',
        consentModalScope:
            'Seuls votre nom et votre username sont transmis. En cas de refus, seules des statistiques anonymes sont envoyées.',
        profileModalBody:
            'Sofia aide à clarifier même les situations complexes avec douceur et précision.',
        profileModalScope:
            'Relations, argent, carrière ou chaos intérieur : elle aide à voir le tableau global et la prochaine étape.',
        submitError: 'Impossible d enregistrer votre choix. Réessayez.',
        closeLabel: 'Fermer',
      );
    }
    if (code == 'tr') {
      return const _SofiaCopy(
        sofiaName: '@SofiaKnoxx',
        consentTitle: 'Veri işleme onayı',
        consentBodyPrefix: 'Adınızın astrologumuza gönderilmesine izin ver',
        consentBodySuffix: 'bildirimler için',
        acceptButton: 'Kabul ediyorum',
        rejectButton: 'Reddediyorum',
        infoCardTitle: 'Tarot astrologumuz Sofia',
        modalTitle: 'Tarot astrologumuz Sofia',
        consentModalBody:
            'Bildirimler için adınızı ve Telegram kullanıcı adınızı Sofia ya göndermeye izin verebilirsiniz. Alıcı: @SofiaKnoxx.',
        consentModalScope:
            'Yalnızca adınız ve kullanıcı adınız paylaşılır. Redderseniz sadece anonim istatistikler gönderilir.',
        profileModalBody:
            'Sofia en karmaşık durumları bile sakin ve net şekilde analiz etmenize yardımcı olur.',
        profileModalScope:
            'İlişki, para, kariyer veya iç karmaşa fark etmez; resmi ve sonraki adımı netleştirir.',
        submitError: 'Seçiminiz kaydedilemedi. Lütfen tekrar deneyin.',
        closeLabel: 'Kapat',
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
            child: Center(
              child: SvgPicture.asset(
                'assets/icon/history_recent.svg',
                width: 18,
                height: 18,
              ),
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

String _frDayUnit(int days) {
  return days <= 1 ? 'jour' : 'jours';
}

String _trDayUnit(int days) {
  return 'gün';
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
    if (code == 'fr') {
      return const _HomeFeatureCopy(
        natalTitle: 'Thème\nnatal',
        compatibilityTitle: 'Compatibilité\namoureuse',
        libraryTitle: 'Bibliothèque\nde cartes',
      );
    }
    if (code == 'tr') {
      return const _HomeFeatureCopy(
        natalTitle: 'Doğum\nharitası',
        compatibilityTitle: 'Aşk\nuyumu',
        libraryTitle: 'Kart\nkütüphanesi',
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
