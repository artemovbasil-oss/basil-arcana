import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../data/models/deck_model.dart';
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
    final deckHint = _deckHint(l10n, deckId);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const buttonHeight = 56.0;
    final primaryColor = colorScheme.primary;
    final disabledColor = Color.lerp(primaryColor, colorScheme.surface, 0.45)!;

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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  24 + buttonHeight,
                ),
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
                                maxLines: 6,
                                minLines: 5,
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
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(16, 16, 48, 40),
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
                    Text(
                      l10n.homeTryPrompt,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 14),
                    if (_sofiaConsentState == _SofiaConsentState.undecided)
                      _SofiaConsentCard(
                        copy: copy,
                        isBusy: _sendingConsent,
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
                        onTap: _showSofiaInfoModal,
                      ),
                  ],
                ),
              ),
            ),
          ],
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

class _SofiaConsentCard extends StatelessWidget {
  const _SofiaConsentCard({
    required this.copy,
    required this.isBusy,
    required this.onOpenInfo,
    required this.onAccept,
    required this.onReject,
  });

  final _SofiaCopy copy;
  final bool isBusy;
  final VoidCallback onOpenInfo;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onOpenInfo,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceVariant.withOpacity(0.26),
          border: Border.all(color: colorScheme.outlineVariant),
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
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.78),
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
            const SizedBox(height: 10),
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
  });

  final _SofiaCopy copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const outerRadius = 20.0;
    return InkWell(
      borderRadius: BorderRadius.circular(outerRadius),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          color: colorScheme.surfaceVariant.withValues(alpha: 0.24),
          border: Border.all(color: colorScheme.outlineVariant),
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
