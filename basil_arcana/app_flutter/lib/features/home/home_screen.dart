import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/app_version.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../data/repositories/home_insights_repository.dart';
import '../../data/repositories/sofia_consent_repository.dart';
import '../../state/providers.dart';
import '../../state/reading_flow_controller.dart';
import '../cards/cards_screen.dart';
import '../astro/compatibility_flow_screen.dart';
import '../astro/natal_chart_flow_screen.dart';
import '../history/query_history_screen.dart';
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
  bool _loadingStreak = false;
  HomeStreakStats _streakStats = HomeStreakStats.empty;
  String? _dailyCardInterpretation;
  String? _dailyCardInterpretationCardId;
  String? _streakInterpretation;
  String? _streakInterpretationCacheKey;
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
    _loadQueryHistoryAvailability();
    _loadStreakStats();
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
    setState(() {
      _loadingStreak = true;
    });
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
                            emoji: '🧝‍♀️',
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
                            emoji: '❤️',
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
                            emoji: '🃏',
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
                            emoji: '🔥',
                            title: streakCopy
                                .tileTitle(_streakStats.currentStreakDays),
                            subtitle: streakCopy.tileSubtitle,
                            onTap: () => _showStreakModal(
                              copy: streakCopy,
                              topCards: topCards,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SecondaryFeatureCard(
                            emoji: '🗓️',
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
    final filtered = cards.where((card) {
      if (deckId == DeckType.lenormand) {
        return card.deckId == DeckType.lenormand;
      }
      return card.deckId != DeckType.lenormand;
    }).toList();
    final source = filtered.isEmpty ? cards : filtered;
    final now = DateTime.now().toUtc();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final index = seed % source.length;
    return source[index];
  }

  Future<void> _showStreakModal({
    required _HomeStreakCopy copy,
    required List<_TopCardStat> topCards,
  }) async {
    final locale = Localizations.localeOf(context).languageCode;
    final streakCacheKey = [
      locale,
      _streakStats.currentStreakDays,
      _streakStats.longestStreakDays,
      _streakStats.awarenessPercent,
      topCards.map((card) => '${card.name}:${card.count}').join('|'),
    ].join(':');
    final hasCache = _streakInterpretationCacheKey == streakCacheKey &&
        (_streakInterpretation?.trim().isNotEmpty ?? false);
    final requestFuture = hasCache
        ? null
        : ref.read(homeInsightsRepositoryProvider).fetchStreakInterpretation(
            stats: _streakStats,
            locale: locale,
            topCards: [
              for (final card in topCards)
                {
                  'name': card.name,
                  'count': card.count,
                },
            ],
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
                          value: '${_streakStats.currentStreakDays}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatPill(
                          label: copy.bestStreakLabel,
                          value: '${_streakStats.longestStreakDays}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AwarenessPill(
                          label: copy.awarenessLabel,
                          value: _streakStats.awarenessPercent,
                          locked: _streakStats.awarenessLocked,
                          shimmer: _titleShimmerController,
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
                  Text(
                    copy.topCardsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (topCards.isEmpty)
                            Text(
                              copy.topCardsEmpty,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < topCards.length; i++) ...[
                                  Expanded(
                                    child: _MiniTopCardTile(
                                      rank: i + 1,
                                      stat: topCards[i],
                                      hitsLabel: copy.hitsLabel,
                                    ),
                                  ),
                                  if (i != topCards.length - 1)
                                    const SizedBox(width: 10),
                                ],
                              ],
                            ),
                          const SizedBox(height: 12),
                          Text(
                            copy.streakInsightTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<String>(
                            future: requestFuture,
                            initialData:
                                hasCache ? _streakInterpretation : null,
                            builder: (context, snapshot) {
                              final hasValue = snapshot.hasData &&
                                  (snapshot.data?.trim().isNotEmpty ?? false);
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !hasValue) {
                                return _HomeMagicLoadingCard(
                                  label: copy.streakInsightPending,
                                );
                              }
                              final resolved = hasValue
                                  ? snapshot.data!.trim()
                                  : copy.streakInsightFallback;
                              if (_streakInterpretationCacheKey !=
                                      streakCacheKey ||
                                  _streakInterpretation != resolved) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {
                                    _streakInterpretationCacheKey =
                                        streakCacheKey;
                                    _streakInterpretation = resolved;
                                  });
                                });
                              }
                              return Text(
                                resolved,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.9),
                                    ),
                              );
                            },
                          ),
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
                          copy.dailyCardModalTitle,
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
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: AspectRatio(
                          aspectRatio: 0.68,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              dailyCard.imageUrl,
                              fit: BoxFit.contain,
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
                              style: Theme.of(context)
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: requestFuture,
                      initialData: hasCache ? _dailyCardInterpretation : null,
                      builder: (context, snapshot) {
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
                          child: Text(
                            resolved,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.9),
                                ),
                          ),
                        );
                      },
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

class _HomeStreakCopy {
  const _HomeStreakCopy({
    required this.tileSubtitle,
    required this.modalTitle,
    required this.currentStreakLabel,
    required this.bestStreakLabel,
    required this.awarenessLabel,
    required this.topCardsTitle,
    required this.topCardsEmpty,
    required this.hitsLabel,
    required this.dailyCardTileTitle,
    required this.dailyCardModalTitle,
    required this.dailyCardFallback,
    required this.dailyCardPending,
    required this.dailyCardError,
    required this.streakInsightTitle,
    required this.streakInsightPending,
    required this.streakInsightFallback,
    required this.lastActivePrefix,
    required this.closeLabel,
  });

  final String tileSubtitle;
  final String modalTitle;
  final String currentStreakLabel;
  final String bestStreakLabel;
  final String awarenessLabel;
  final String topCardsTitle;
  final String topCardsEmpty;
  final String hitsLabel;
  final String dailyCardTileTitle;
  final String dailyCardModalTitle;
  final String dailyCardFallback;
  final String dailyCardPending;
  final String dailyCardError;
  final String streakInsightTitle;
  final String streakInsightPending;
  final String streakInsightFallback;
  final String lastActivePrefix;
  final String closeLabel;

  String tileTitle(int days) => '🔥 ${days < 1 ? 1 : days}';

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
        tileSubtitle: 'Серия и статистика',
        modalTitle: 'Твой streak',
        currentStreakLabel: 'Сейчас',
        bestStreakLabel: 'Рекорд',
        awarenessLabel: 'Осознанность',
        topCardsTitle: 'Топ карт',
        topCardsEmpty: 'Пока нет статистики по картам.',
        hitsLabel: 'Выпадала',
        dailyCardTileTitle: 'Карта дня',
        dailyCardModalTitle: 'Карта дня',
        dailyCardFallback: 'Подбираем карту...',
        dailyCardPending: 'Смотрим, что карта дня значит именно для тебя…',
        dailyCardError: 'Не получилось получить трактовку. Попробуй еще раз.',
        streakInsightTitle: 'Что это значит',
        streakInsightPending: 'Собираем короткий смысл по твоей статистике…',
        streakInsightFallback:
            'Статистика показывает темп твоей практики: регулярность и повторяемость усиливают точность интерпретаций.',
        lastActivePrefix: 'Последняя активность',
        closeLabel: 'Закрыть',
      );
    }
    if (code == 'kk') {
      return const _HomeStreakCopy(
        tileSubtitle: 'Серия мен статистика',
        modalTitle: 'Сенің streak',
        currentStreakLabel: 'Қазір',
        bestStreakLabel: 'Рекорд',
        awarenessLabel: 'Саналылық',
        topCardsTitle: 'Топ карталар',
        topCardsEmpty: 'Карта статистикасы әзірге жоқ.',
        hitsLabel: 'Түскен саны',
        dailyCardTileTitle: 'Күн картасы',
        dailyCardModalTitle: 'Күн картасы',
        dailyCardFallback: 'Карта таңдалып жатыр...',
        dailyCardPending: 'Күн картасының саған не айтатынын қарап жатырмыз…',
        dailyCardError: 'Түсіндірмені алу мүмкін болмады. Қайта көріңіз.',
        streakInsightTitle: 'Бұл нені білдіреді',
        streakInsightPending:
            'Статистикаңыз бойынша қысқа түсіндірме дайындап жатырмыз…',
        streakInsightFallback:
            'Бұл статистика тәжірибе ырғағын көрсетеді: тұрақты қайталау интерпретация дәлдігін арттырады.',
        lastActivePrefix: 'Соңғы белсенділік',
        closeLabel: 'Жабу',
      );
    }
    return const _HomeStreakCopy(
      tileSubtitle: 'Streak and stats',
      modalTitle: 'Your streak',
      currentStreakLabel: 'Current',
      bestStreakLabel: 'Best',
      awarenessLabel: 'Awareness',
      topCardsTitle: 'Top cards',
      topCardsEmpty: 'No card stats yet.',
      hitsLabel: 'Drawn',
      dailyCardTileTitle: 'Daily card',
      dailyCardModalTitle: 'Daily card',
      dailyCardFallback: 'Selecting card...',
      dailyCardPending: 'Reading what this card means for you today...',
      dailyCardError: 'Could not load interpretation. Try again.',
      streakInsightTitle: 'What this means',
      streakInsightPending: 'Building a short insight from your stats...',
      streakInsightFallback:
          'Your stats reflect practice rhythm: consistency and repetition improve interpretation quality over time.',
      lastActivePrefix: 'Last activity',
      closeLabel: 'Close',
    );
  }
}

class _SecondaryFeatureCard extends StatelessWidget {
  const _SecondaryFeatureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
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
            Text(
              emoji,
              style: Theme.of(context).textTheme.titleMedium,
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
  });

  final String label;
  final String value;

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
          colors: [
            colorScheme.primary.withValues(alpha: 0.24),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
  });

  final String label;
  final int value;
  final bool locked;
  final Animation<double> shimmer;

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
            colorScheme.primary.withValues(alpha: locked ? 0.3 : 0.24),
            colorScheme.surfaceContainerHighest.withValues(
              alpha: locked ? 0.38 : 0.3,
            ),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (locked && percent == 100)
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

class _MiniTopCardTile extends StatelessWidget {
  const _MiniTopCardTile({
    required this.rank,
    required this.stat,
    required this.hitsLabel,
  });

  final int rank;
  final _TopCardStat stat;
  final String hitsLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceVariant.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#$rank',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 0.68,
              child: stat.imageUrl.trim().isNotEmpty
                  ? Image.network(
                      stat.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                      ),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stat.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$hitsLabel: ${stat.count}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
        ],
      ),
    );
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
    required this.emoji,
    required this.title,
    required this.onTap,
  });

  final String emoji;
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
            Text(
              emoji,
              style: Theme.of(context).textTheme.headlineSmall,
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
