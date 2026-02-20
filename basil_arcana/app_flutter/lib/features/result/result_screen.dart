import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/card_face_widget.dart';
import '../../core/widgets/energy_widgets.dart';
import '../../core/assets/asset_paths.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../core/widgets/linkified_text.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../core/telegram/telegram_user_profile.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../data/models/app_enums.dart';
import '../../data/models/drawn_card_model.dart';
import '../../data/models/spread_model.dart';
import '../../data/models/ai_result_model.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/energy_controller.dart';
import '../../state/reading_flow_controller.dart';
import '../../state/providers.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/navigation/app_route_config.dart';
import '../more/more_features_screen.dart';
import '../settings/settings_screen.dart';
import '../cards/card_detail_screen.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/oracle_waiting_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<_ChatItem> _items = [];
  final List<_ChatItem> _basilQueue = [];
  ProviderSubscription<ReadingFlowState>? _readingFlowSubscription;
  Timer? _typingTimer;
  bool _sequenceComplete = false;
  bool _initialized = false;
  bool _precacheDone = false;
  bool _autoScrollEnabled = false;
  int _itemCounter = 0;
  String? _warmTip;

  @override
  void dispose() {
    ref.read(readingFlowControllerProvider.notifier).reset();
    _readingFlowSubscription?.close();
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _readingFlowSubscription = ref.listenManual<ReadingFlowState>(
      readingFlowControllerProvider,
      (prev, next) {
        if (prev?.detailsStatus != next.detailsStatus ||
            prev?.showDetailsCta != next.showDetailsCta) {
          _maybeScrollToBottom();
        }
        final errorMessage = next.errorMessage;
        if (errorMessage != null && errorMessage != prev?.errorMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          });
        }
        if (prev?.aiResult != null &&
            next.aiResult != null &&
            prev?.aiResult?.fullText != next.aiResult?.fullText &&
            !(prev?.aiUsed == false && next.aiUsed == true)) {
          _replaceReadingMessages(next);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToTop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    final aiResult = state.aiResult;
    final spread = state.spread;
    final l10n = AppLocalizations.of(context)!;
    void handleBack() {
      ref.read(readingFlowControllerProvider.notifier).reset();
      Navigator.popUntil(context, (route) => route.isFirst);
    }

    if (spread == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.requiresTelegram) {
      return _OpenInTelegramScreen(
        onOpen: () async {
          final url = Uri.parse('https://t.me/tarot_arkana_bot');
          await launchUrl(url, mode: LaunchMode.externalApplication);
        },
        onBack: () {
          ref.read(readingFlowControllerProvider.notifier).reset();
          Navigator.popUntil(context, (route) => route.isFirst);
        },
      );
    }

    if (aiResult == null) {
      if (state.isLoading) {
        final selectedDeck = ref.watch(deckProvider);
        final energy = ref.watch(energyProvider);
        final deckCoverUrl = deckCoverImageUrl(selectedDeck);
        final expectedCardsCount = state.spreadType?.cardCount ??
            state.spread?.cardsCount ??
            state.spread?.positions.length ??
            state.drawnCards.length;
        return Scaffold(
          appBar: buildEnergyTopBar(
            context,
            showBack: true,
            onBack: handleBack,
            onSettings: () {
              Navigator.pushNamed(
                context,
                SettingsScreen.routeName,
                arguments: const AppRouteConfig(showBackButton: true),
              );
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            top: false,
            child: _ResultLoadingShimmer(
              drawnCards: state.drawnCards,
              expectedCardsCount: expectedCardsCount,
              deckCoverUrl: deckCoverUrl,
              question: state.question,
              isUnlimitedUser: energy.isUnlimited,
              readingEnergyCost: EnergyAction.reading.cost.round(),
            ),
          ),
        );
      }

      if (_shouldShowRetryScreen(state.aiErrorType)) {
        return _OracleRetryScreen(
          onCancel: () {
            ref.read(readingFlowControllerProvider.notifier).cancelGeneration();
            Navigator.pop(context);
          },
          onRetry: () {
            ref.read(readingFlowControllerProvider.notifier).retryGenerate();
          },
        );
      }

      if (_shouldShowBackendErrorBubble(state)) {
        final statusText = _statusMessage(state, l10n);
        final canRetry = !state.isLoading && state.aiErrorType != null;
        return Scaffold(
          appBar: buildEnergyTopBar(
            context,
            showBack: true,
            onBack: handleBack,
            onSettings: () {
              Navigator.pushNamed(
                context,
                SettingsScreen.routeName,
                arguments: const AppRouteConfig(showBackButton: true),
              );
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            top: false,
            child: Center(
              child: GestureDetector(
                onTap: canRetry
                    ? () {
                        ref
                            .read(
                              readingFlowControllerProvider.notifier,
                            )
                            .retryGenerate();
                      }
                    : null,
                child: ChatBubble(
                  isUser: false,
                  avatarEmoji: '🪄',
                  fullWidth: true,
                  showAvatar: false,
                  child: Text(statusText),
                ),
              ),
            ),
          ),
        );
      }

      final statusText = state.isLoading
          ? l10n.resultStatusAiReading
          : _statusMessage(state, l10n);
      final canRetry = !state.isLoading && state.aiErrorType != null;
      return Scaffold(
        appBar: buildEnergyTopBar(
          context,
          showBack: true,
          onBack: handleBack,
          onSettings: () {
            Navigator.pushNamed(
              context,
              SettingsScreen.routeName,
              arguments: const AppRouteConfig(showBackButton: true),
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          top: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: canRetry
                      ? () {
                          ref
                              .read(
                                readingFlowControllerProvider.notifier,
                              )
                              .retryGenerate();
                        }
                      : null,
                  child: _StatusPill(text: statusText),
                ),
                const SizedBox(height: 16),
                if (state.isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    if (!_precacheDone) {
      _precacheDrawnCards(state);
    }

    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeSequence(state);
        }
      });
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final listBottomPadding = 24 +
        _ActionBar.baseHeight +
        (_sequenceComplete ? _ActionBar.extraHeight : 0);
    return Scaffold(
      appBar: buildEnergyTopBar(
        context,
        showBack: true,
        onBack: handleBack,
        onSettings: () {
          Navigator.pushNamed(
            context,
            SettingsScreen.routeName,
            arguments: const AppRouteConfig(showBackButton: true),
          );
        },
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding),
                children: [
                  for (final item in _items) ...[
                    _buildChatItem(item, state),
                    const SizedBox(height: 14),
                  ],
                  if (_sequenceComplete &&
                      state.showDetailsCta &&
                      state.detailsStatus == DetailsStatus.idle) ...[
                    ChatBubbleReveal(
                      child: ChatBubble(
                        isUser: false,
                        avatarEmoji: '🪄',
                        fullWidth: true,
                        showAvatar: false,
                        child: _DeepPromptBubble(
                          isActionable: state.showDetailsCta &&
                              state.detailsStatus == DetailsStatus.idle,
                          onDecline: () {
                            ref
                                .read(
                                  readingFlowControllerProvider.notifier,
                                )
                                .dismissDetails();
                          },
                          onAccept: () async {
                            if (state.detailsStatus == DetailsStatus.loading) {
                              return;
                            }
                            final canShowDetails =
                                await trySpendEnergyForAction(
                              context,
                              ref,
                              EnergyAction.deepDetails,
                            );
                            if (!canShowDetails) {
                              return;
                            }
                            await ref
                                .read(
                                  readingFlowControllerProvider.notifier,
                                )
                                .requestDetails();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (state.detailsStatus == DetailsStatus.loading) ...[
                    ChatBubbleReveal(
                      child: OracleTypingBubble(
                        label:
                            AppLocalizations.of(context)!.resultDeepTypingLabel,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (state.detailsStatus == DetailsStatus.success &&
                      state.detailsText != null &&
                      state.detailsText!.trim().isNotEmpty) ...[
                    ChatBubbleReveal(
                      child: ChatBubble(
                        isUser: false,
                        avatarEmoji: '🪄',
                        fullWidth: true,
                        showAvatar: false,
                        child: _DetailsCardThumbnails(
                          spread: spread,
                          spreadType: state.spreadType,
                          drawnCards: state.drawnCards,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final section in _buildDetailsSections(
                      state.detailsText!,
                      l10n,
                    )) ...[
                      ChatBubbleReveal(
                        child: ChatBubble(
                          isUser: false,
                          avatarEmoji: '🪄',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (section.heading != null) ...[
                                Text(
                                  section.heading!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              LinkifiedText(section.text),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                  if (state.detailsStatus == DetailsStatus.error) ...[
                    ChatBubbleReveal(
                      child: ChatBubble(
                        isUser: false,
                        avatarEmoji: '🪄',
                        fullWidth: true,
                        showAvatar: false,
                        child: _DeepErrorBubble(
                          message: state.detailsError ??
                              AppLocalizations.of(context)!
                                  .resultDeepRetryMessage,
                          onCancel: () {
                            ref
                                .read(
                                  readingFlowControllerProvider.notifier,
                                )
                                .dismissDetails();
                          },
                          onRetry: () {
                            trySpendEnergyForAction(
                              context,
                              ref,
                              EnergyAction.deepDetails,
                            ).then((canRetry) {
                              if (!canRetry) {
                                return;
                              }
                              ref
                                  .read(
                                    readingFlowControllerProvider.notifier,
                                  )
                                  .tryAgainDetails();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _ActionBar(
                  showExtra: _sequenceComplete,
                  onNew: () {
                    ref.read(readingFlowControllerProvider.notifier).reset();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  onShare: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const MoreFeaturesScreen(),
                      ),
                    );
                  },
                  newLabel: l10n.resultNewButton,
                  moreLabel: l10n.resultWantMoreButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowRetryScreen(AiErrorType? type) {
    return type == AiErrorType.timeout;
  }

  bool _shouldShowBackendErrorBubble(ReadingFlowState state) {
    final status = state.aiErrorStatusCode;
    if (status != null && (status < 200 || status >= 300)) {
      return true;
    }
    return state.aiErrorType == AiErrorType.serverError ||
        state.aiErrorType == AiErrorType.badResponse ||
        state.aiErrorType == AiErrorType.unauthorized ||
        state.aiErrorType == AiErrorType.rateLimited;
  }

  void _initializeSequence(ReadingFlowState state) {
    _initialized = true;
    _sequenceComplete = false;
    _autoScrollEnabled = false;
    _warmTip = _maybeWarmTip(state);
    _items
      ..clear()
      ..add(
        _ChatItem.user(
          id: _nextId(),
          child: Text(state.question),
        ),
      );
    _basilQueue
      ..clear()
      ..addAll(_buildBasilMessages(state));
    setState(() {});
    _jumpToTop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollEnabled = true;
    });
    _queueNextBasilMessage();
  }

  void _queueNextBasilMessage() {
    if (_basilQueue.isEmpty) {
      setState(() {
        _sequenceComplete = true;
      });
      _maybeScrollToBottom();
      return;
    }

    setState(() {
      _items.add(_ChatItem.typing(id: _nextId()));
    });
    _maybeScrollToBottom();

    final delay = Duration(milliseconds: 700 + Random().nextInt(401));
    _typingTimer?.cancel();
    _typingTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_items.isNotEmpty) {
          _items[_items.length - 1] = _basilQueue.removeAt(0);
        }
      });
      _maybeScrollToBottom();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _queueNextBasilMessage();
        }
      });
    });
  }

  void _replaceReadingMessages(ReadingFlowState state) {
    if (!mounted) {
      return;
    }
    _typingTimer?.cancel();
    setState(() {
      _sequenceComplete = true;
      _warmTip = _maybeWarmTip(state);
      final userMessages = _items
          .where((item) => item.kind == _ChatItemKind.user)
          .toList(growable: true);
      _items
        ..clear()
        ..addAll(userMessages)
        ..addAll(_buildBasilMessages(state));
      _basilQueue.clear();
    });
    _maybeScrollToBottom();
  }

  List<_ChatItem> _buildBasilMessages(ReadingFlowState state) {
    final aiResult = state.aiResult;
    final l10n = AppLocalizations.of(context)!;
    final isFiveCardPremium = _isFiveCardPremiumReading(state);
    final isLenormandReading = _isLenormandReading(state);
    if (aiResult == null) {
      return <_ChatItem>[
        _ChatItem.basil(
          id: _nextId(),
          child: Text(l10n.resultStatusUnexpectedResponse),
        ),
      ];
    }
    final sectionMap = {
      for (final section in aiResult.sections) section.positionId: section
    };
    final hasSofiaPromo = <String>[
      aiResult.tldr,
      aiResult.why,
      aiResult.action,
      ...aiResult.sections.map((section) => section.text),
    ].any(containsSofiaPromo);
    final sofiaPrefill = _buildSofiaPrefill(aiResult, l10n);

    final items = <_ChatItem>[];
    if (isFiveCardPremium) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: _PremiumReadingBadge(
            title: _premiumTitle(context),
            subtitle: _premiumSubtitle(context),
          ),
        ),
      );
    }
    items.add(
      _ChatItem.basil(
        id: _nextId(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.resultSectionArcaneSnapshot,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            LinkifiedText(
              stripSofiaPromo(aiResult.tldr).trim().isEmpty
                  ? l10n.resultStatusUnexpectedResponse
                  : stripSofiaPromo(aiResult.tldr),
            ),
          ],
        ),
      ),
    );

    for (var index = 0; index < state.drawnCards.length; index++) {
      final drawn = state.drawnCards[index];
      final section = sectionMap[drawn.positionId];
      if (isLenormandReading) {
        final step = index + 1;
        items.add(
          _ChatItem.basil(
            id: _nextId(),
            child: _LenormandSequenceCard(
              step: step,
              total: state.drawnCards.length,
              card: drawn,
              text: stripSofiaPromo(section?.text ?? ''),
              previousCards: state.drawnCards.take(index).toList(),
              onCardTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: appRouteSettings(showBackButton: true),
                    builder: (_) => CardDetailScreen(
                      cardId: drawn.cardId,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        continue;
      }
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: isFiveCardPremium
              ? _PremiumReadingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardFaceWidget(
                        cardId: drawn.cardId,
                        cardName: drawn.cardName,
                        keywords: drawn.keywords,
                        showContainer: false,
                        overlayHeaderOnImage: true,
                        showKeywords: false,
                        padding: EdgeInsets.zero,
                        onCardTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: appRouteSettings(showBackButton: true),
                              builder: (_) => CardDetailScreen(
                                cardId: drawn.cardId,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        drawn.positionTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      LinkifiedText(
                        stripSofiaPromo(section?.text ?? '').trim().isEmpty
                            ? l10n.resultStatusUnexpectedResponse
                            : stripSofiaPromo(section?.text ?? ''),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardFaceWidget(
                      cardId: drawn.cardId,
                      cardName: drawn.cardName,
                      keywords: drawn.keywords,
                      showContainer: false,
                      overlayHeaderOnImage: true,
                      showKeywords: false,
                      padding: EdgeInsets.zero,
                      onCardTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: appRouteSettings(showBackButton: true),
                            builder: (_) => CardDetailScreen(
                              cardId: drawn.cardId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      drawn.positionTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinkifiedText(
                      stripSofiaPromo(section?.text ?? '').trim().isEmpty
                          ? l10n.resultStatusUnexpectedResponse
                          : stripSofiaPromo(section?.text ?? ''),
                    ),
                  ],
                ),
        ),
      );
    }

    final whyText = stripSofiaPromo(aiResult.why);
    if (whyText.trim().isNotEmpty) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: isFiveCardPremium
              ? _PremiumReadingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.resultSectionWhy,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      LinkifiedText(whyText),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resultSectionWhy,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinkifiedText(whyText),
                  ],
                ),
        ),
      );
    }

    final actionText = stripSofiaPromo(aiResult.action);
    if (actionText.trim().isNotEmpty) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: isFiveCardPremium
              ? _PremiumReadingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.resultSectionAction,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      LinkifiedText(actionText),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resultSectionAction,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinkifiedText(actionText),
                  ],
                ),
        ),
      );
    }

    if (hasSofiaPromo) {
      final referralLink = _resolveReferralLink();
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: SofiaPromoCard(prefilledMessage: sofiaPrefill),
        ),
      );
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: _ShareWithFriendsCard(
            title: l10n.resultReferralTitle,
            body: l10n.resultReferralBody,
            buttonLabel: l10n.resultReferralButton,
            copiedLabel: l10n.resultReferralCopied,
            shareUrl: referralLink,
            shareMessage: l10n.resultReferralShareMessage,
          ),
        ),
      );
    }

    if (_warmTip != null) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: LinkifiedText(_warmTip!),
        ),
      );
    }

    return items;
  }

  bool _isFiveCardPremiumReading(ReadingFlowState state) {
    final spreadType = state.spreadType;
    if (spreadType == SpreadType.five && state.drawnCards.length >= 5) {
      return true;
    }
    final spreadCount =
        state.spread?.cardsCount ?? state.spread?.positions.length ?? 0;
    return spreadCount >= 5 && state.drawnCards.length >= 5;
  }

  bool _isLenormandReading(ReadingFlowState state) {
    if (state.drawnCards.isEmpty) {
      return false;
    }
    return state.drawnCards.every(
      (drawn) => canonicalCardId(drawn.cardId).startsWith('lenormand_'),
    );
  }

  String _premiumTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Премиум разбор на 5 карт';
    }
    if (code == 'kk') {
      return '5 картаға премиум талдау';
    }
    return 'Premium 5-card reading';
  }

  String _premiumSubtitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Слой за слоем: причины, динамика и точный вектор действия.';
    }
    if (code == 'kk') {
      return 'Қабат бойынша: себеп, динамика және нақты әрекет векторы.';
    }
    return 'Layer by layer: causes, dynamics, and a precise next-step vector.';
  }

  String _resolveReferralLink() {
    final profile = readTelegramUserProfile();
    if (profile == null) {
      return 'https://t.me/tarot_arkana_bot/app';
    }
    return buildReferralLinkForUserId(profile.userId);
  }

  Widget _buildChatItem(_ChatItem item, ReadingFlowState state) {
    switch (item.kind) {
      case _ChatItemKind.user:
        return ChatBubbleReveal(
          key: ValueKey(item.id),
          child: ChatBubble(
            isUser: true,
            avatarEmoji: '🙂',
            child: item.child ?? const SizedBox.shrink(),
          ),
        );
      case _ChatItemKind.basil:
        return ChatBubbleReveal(
          key: ValueKey(item.id),
          child: ChatBubble(
            isUser: false,
            avatarEmoji: '🪄',
            fullWidth: true,
            showAvatar: false,
            child: item.child ?? const SizedBox.shrink(),
          ),
        );
      case _ChatItemKind.typing:
        return ChatBubbleReveal(
          key: ValueKey(item.id),
          child: const TypingIndicatorBubble(),
        );
    }
  }

  String _statusMessage(ReadingFlowState state, AppLocalizations l10n) {
    switch (state.aiErrorType) {
      case AiErrorType.misconfigured:
        return l10n.resultStatusMissingApiBaseUrl;
      case AiErrorType.unauthorized:
        return l10n.resultStatusServerUnavailable;
      case AiErrorType.rateLimited:
        return l10n.resultStatusTooManyAttempts;
      case AiErrorType.noInternet:
        return l10n.resultStatusNoInternet;
      case AiErrorType.timeout:
        return l10n.resultStatusTimeout;
      case AiErrorType.serverError:
        final status = state.aiErrorStatusCode;
        if (status != null) {
          return l10n.resultStatusServerUnavailableWithStatus(status);
        }
        return l10n.resultStatusServerUnavailable;
      case AiErrorType.badResponse:
        return l10n.resultStatusUnexpectedResponse;
      case null:
        return l10n.resultStatusInterpretationUnavailable;
    }
  }

  String? _maybeWarmTip(ReadingFlowState state) {
    if (!state.aiUsed) {
      return null;
    }
    final rng = Random();
    if (rng.nextDouble() >= 0.5) {
      return null;
    }
    final languageCode = Localizations.localeOf(context).languageCode;
    final tips = _warmTipsFor(languageCode);
    return tips[rng.nextInt(tips.length)];
  }

  List<String> _warmTipsFor(String languageCode) {
    switch (languageCode) {
      case 'ru':
        return const [
          'Сделайте медленный вдох и дайте себе небольшую паузу. Маленькие перерывы делают день мягче.',
          'Если получится, проявите к себе небольшую заботу сегодня. Небольшие шаги поддержки очень важны.',
          'Пусть сегодня будет устойчивость, а не идеальность. Маленький прогресс — тоже прогресс.',
        ];
      case 'kk':
        return const [
          'Бүгін бір сәт баяу тыныстап, өзіңізге кідіріс беріңіз. Кішкентай үзіліс күнді жеңілдетеді.',
          'Мүмкіндік болса, өзіңізге кішкентай қамқорлық жасаңыз. Шағын қолдау үлкен әсер береді.',
          'Бүгін мінсіздіктен гөрі тұрақтылықты таңдаңыз. Кішкентай қадам да алға жылжу.',
        ];
      case 'en':
      default:
        return const [
          'Take a slow breath and give yourself a small pause today. Small resets can make the rest feel lighter.',
          'If you can, do one tiny kind thing for yourself today. Little care adds up.',
          'Let today be steady rather than perfect. Progress in small steps is still progress.',
        ];
    }
  }

  String _nextId() => 'chat_${_itemCounter++}';

  String _buildSofiaPrefill(AiResultModel aiResult, AppLocalizations l10n) {
    final lines = <String>[];
    final tldr = stripSofiaPromo(aiResult.tldr).trim();
    if (tldr.isNotEmpty) {
      lines.add(tldr);
    }
    final action = stripSofiaPromo(aiResult.action).trim();
    if (action.isNotEmpty) {
      lines.add('${l10n.resultSectionAction}: $action');
    }
    if (lines.isEmpty) {
      return '';
    }
    return lines.join('\n\n');
  }

  void _jumpToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 160;
  }

  void _maybeScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScrollEnabled && _isNearBottom()) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _precacheDrawnCards(ReadingFlowState state) {
    _precacheDone = true;
    final cards =
        ref.read(cardsAllProvider).asData?.value ?? const <CardModel>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final drawn in state.drawnCards) {
        final imageUrl = _resolveImageUrl(cards, drawn.cardId);
        if (imageUrl == null || imageUrl.isEmpty) {
          continue;
        }
        precacheImage(
          NetworkImage(imageUrl),
          context,
        );
      }
    });
  }

  List<_DetailsSection> _buildDetailsSections(
    String rawText,
    AppLocalizations l10n,
  ) {
    final sanitized = _sanitizeDetailsText(rawText);
    final cleaned =
        sanitized.trim().isEmpty ? rawText.trim() : sanitized.trim();
    if (cleaned.isEmpty) {
      return const [];
    }
    final relationshipMatch = RegExp(
      r'(relationships|relationship|love)\b[:\-–—]*',
      caseSensitive: false,
    ).firstMatch(cleaned);
    final careerMatch = RegExp(
      r'(career|work)\b[:\-–—]*',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (relationshipMatch == null || careerMatch == null) {
      return [
        _DetailsSection(text: cleaned),
      ];
    }

    final relationshipIndex = relationshipMatch.start;
    final careerIndex = careerMatch.start;
    if (relationshipIndex == careerIndex) {
      return [
        _DetailsSection(text: cleaned),
      ];
    }

    final relationshipsFirst = relationshipIndex < careerIndex;
    final firstIndex = relationshipsFirst ? relationshipIndex : careerIndex;
    final secondIndex = relationshipsFirst ? careerIndex : relationshipIndex;
    final firstLabel = relationshipsFirst
        ? l10n.resultDeepRelationshipsHeading
        : l10n.resultDeepCareerHeading;
    final secondLabel = relationshipsFirst
        ? l10n.resultDeepCareerHeading
        : l10n.resultDeepRelationshipsHeading;
    final firstBody = cleaned.substring(firstIndex, secondIndex).trim();
    final secondBody = cleaned.substring(secondIndex).trim();

    final firstText = _stripSectionHeading(
      firstBody,
      isRelationship: relationshipsFirst,
    );
    final secondText = _stripSectionHeading(
      secondBody,
      isRelationship: !relationshipsFirst,
    );

    if (firstText.isEmpty || secondText.isEmpty) {
      return [
        _DetailsSection(text: cleaned),
      ];
    }

    return [
      _DetailsSection(text: firstText, heading: firstLabel),
      _DetailsSection(text: secondText, heading: secondLabel),
    ];
  }

  String _stripSectionHeading(String text, {required bool isRelationship}) {
    final pattern = isRelationship
        ? RegExp(r'^\s*(relationships|relationship|love)\b[:\-–—]*\s*',
            caseSensitive: false)
        : RegExp(r'^\s*(career|work)\b[:\-–—]*\s*', caseSensitive: false);
    return text.replaceFirst(pattern, '').trim();
  }

  String _sanitizeDetailsText(String input) {
    final lines = input.replaceAll(RegExp(r'[`*_]+'), '').split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      final trimmedLine = line.trim();
      final lower = trimmedLine.toLowerCase();
      if (lower.contains('[left') &&
          lower.contains('[center') &&
          lower.contains('[right')) {
        continue;
      }
      final withoutBullet = trimmedLine.replaceAll(
        RegExp(r'^(\d+\.\s+|[-*•–—]+\s+)'),
        '',
      );
      cleanedLines.add(withoutBullet);
    }
    return cleanedLines.join('\n').trim();
  }
}

class _OpenInTelegramScreen extends StatelessWidget {
  const _OpenInTelegramScreen({
    required this.onOpen,
    required this.onBack,
  });

  final VoidCallback onBack;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: buildEnergyTopBar(
        context,
        showBack: true,
        onBack: onBack,
        onSettings: () {
          Navigator.pushNamed(
            context,
            SettingsScreen.routeName,
            arguments: const AppRouteConfig(showBackButton: true),
          );
        },
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Open this mini app from Telegram bot',
                style: AppTextStyles.title(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This experience needs Telegram to authenticate your reading.',
                style: AppTextStyles.body(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Open Telegram bot',
                onPressed: onOpen,
              ),
              const SizedBox(height: 12),
              AppSmallButton(
                onPressed: onBack,
                label: 'Back',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsSection {
  const _DetailsSection({required this.text, this.heading});

  final String text;
  final String? heading;
}

class _OracleRetryScreen extends StatelessWidget {
  const _OracleRetryScreen({
    required this.onCancel,
    required this.onRetry,
  });

  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OracleWaitingScreen(
      onCancel: onCancel,
      onRetry: onRetry,
      isTimeout: true,
    );
  }
}

class _DeepPromptBubble extends StatelessWidget {
  const _DeepPromptBubble({
    required this.isActionable,
    required this.onDecline,
    required this.onAccept,
  });

  final bool isActionable;
  final VoidCallback onDecline;
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.resultDeepPrompt,
          style: AppTextStyles.body(context),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppSmallButton(
                label: l10n.resultDeepNotNow,
                onPressed: isActionable ? onDecline : null,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppSmallButton(
                label: l10n.resultDeepShowDetails,
                onPressed: isActionable
                    ? () async {
                        await onAccept();
                      }
                    : null,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeepErrorBubble extends StatelessWidget {
  const _DeepErrorBubble({
    required this.message,
    required this.onCancel,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTextStyles.body(context),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppSmallButton(
                label: l10n.resultDeepNotNow,
                onPressed: onCancel,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppSmallButton(
                label: l10n.resultDeepTryAgain,
                onPressed: onRetry,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChatItem {
  const _ChatItem._({
    required this.id,
    required this.kind,
    this.child,
    this.message,
  });

  factory _ChatItem.user({required String id, required Widget child}) {
    return _ChatItem._(id: id, kind: _ChatItemKind.user, child: child);
  }

  factory _ChatItem.basil({required String id, required Widget child}) {
    return _ChatItem._(id: id, kind: _ChatItemKind.basil, child: child);
  }

  factory _ChatItem.typing({required String id}) {
    return _ChatItem._(id: id, kind: _ChatItemKind.typing);
  }

  final String id;
  final _ChatItemKind kind;
  final Widget? child;
  final String? message;
}

enum _ChatItemKind {
  user,
  basil,
  typing,
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: colorScheme.onSurface),
      ),
    );
  }
}

class _ResultLoadingShimmer extends StatefulWidget {
  const _ResultLoadingShimmer({
    required this.drawnCards,
    required this.expectedCardsCount,
    required this.deckCoverUrl,
    required this.question,
    required this.isUnlimitedUser,
    required this.readingEnergyCost,
  });

  final List<DrawnCardModel> drawnCards;
  final int expectedCardsCount;
  final String deckCoverUrl;
  final String question;
  final bool isUnlimitedUser;
  final int readingEnergyCost;

  @override
  State<_ResultLoadingShimmer> createState() => _ResultLoadingShimmerState();
}

class _ResultLoadingShimmerState extends State<_ResultLoadingShimmer>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _questionTypingController;
  late final AnimationController _questionDotsController;
  late final AnimationController _subscriptionTypingController;
  late final AnimationController _subscriptionDotsController;
  bool _sequenceStarted = false;
  bool _questionTypingDone = false;
  bool _subscriptionTypingDone = false;
  bool _showCardsBubble = false;
  bool _showSubscriptionBubble = false;
  bool _showOracleBubble = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );
    final localeCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final fullText = _loadingQuestionText(
      localeCode: localeCode,
      question: widget.question,
    );
    _questionTypingController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (1450 + fullText.length * 30).clamp(1450, 6200),
      ),
    );
    _questionDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final subscriptionText = _subscriptionLoaderText(
      localeCode: localeCode,
      isUnlimitedUser: widget.isUnlimitedUser,
      readingEnergyCost: widget.readingEnergyCost,
    );
    _subscriptionTypingController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (1500 + subscriptionText.length * 33).clamp(1500, 6200),
      ),
    );
    _subscriptionDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sequenceStarted) {
      return;
    }
    _sequenceStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      _questionTypingController.value = 1.0;
      _questionDotsController.value = 1.0;
      _revealController.value = 1.0;
      _subscriptionTypingController.value = 1.0;
      _subscriptionDotsController.value = 1.0;
      _questionTypingDone = true;
      _subscriptionTypingDone = true;
      _showCardsBubble = true;
      _showSubscriptionBubble = true;
      _showOracleBubble = true;
      return;
    }
    unawaited(_runLoadingSequence());
  }

  Future<void> _runLoadingSequence() async {
    await _questionTypingController.forward();
    if (!mounted) {
      return;
    }
    setState(() {
      _questionTypingDone = true;
    });
    await _questionDotsController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _showCardsBubble = true;
    });
    await _revealController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _showSubscriptionBubble = true;
    });
    await _subscriptionTypingController.forward();
    if (!mounted) {
      return;
    }
    setState(() {
      _subscriptionTypingDone = true;
    });
    await _subscriptionDotsController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _showOracleBubble = true;
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _questionTypingController.dispose();
    _questionDotsController.dispose();
    _subscriptionTypingController.dispose();
    _subscriptionDotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeCode = Localizations.localeOf(context).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _QuestionTypingBubble(
          typing: _questionTypingController,
          oneShotDots: _questionDotsController,
          showDots: _questionTypingDone && !_showCardsBubble,
          localeCode: localeCode,
          question: widget.question,
        ),
        if (_showCardsBubble) ...[
          const SizedBox(height: 14),
          ChatBubbleReveal(
            child: ChatBubble(
              isUser: false,
              avatarEmoji: '🪄',
              fullWidth: true,
              showAvatar: false,
              child: _LoadingCardsRow(
                reveal: _revealController,
                drawnCards: widget.drawnCards,
                expectedCardsCount: widget.expectedCardsCount,
                deckCoverUrl: widget.deckCoverUrl,
              ),
            ),
          ),
        ],
        if (_showSubscriptionBubble) ...[
          const SizedBox(height: 14),
          _SubscriptionTypingBubble(
            typing: _subscriptionTypingController,
            oneShotDots: _subscriptionDotsController,
            showDots: _subscriptionTypingDone && !_showOracleBubble,
            localeCode: localeCode,
            isUnlimitedUser: widget.isUnlimitedUser,
            readingEnergyCost: widget.readingEnergyCost,
          ),
        ],
        if (_showOracleBubble) ...[
          const SizedBox(height: 14),
          ChatBubbleReveal(
            child: OracleTypingBubble(
              label: l10n.resultDeepTypingLabel,
            ),
          ),
        ],
      ],
    );
  }
}

String _loadingQuestionText({
  required String localeCode,
  required String question,
}) {
  final trimmed = question.trim().replaceAll(RegExp(r'\s+'), ' ');
  final safeQuestion = trimmed.isEmpty
      ? (localeCode == 'ru'
          ? 'ваш запрос'
          : localeCode == 'kk'
              ? 'сұрағыңыз'
              : 'your question')
      : trimmed;
  final prefix = localeCode == 'ru'
      ? 'Разбираем ситуацию'
      : localeCode == 'kk'
          ? 'Жағдайды талдап жатырмыз'
          : 'Reading your situation';
  return '$prefix — «$safeQuestion»';
}

String _subscriptionLoaderText({
  required String localeCode,
  required bool isUnlimitedUser,
  required int readingEnergyCost,
}) {
  if (isUnlimitedUser) {
    if (localeCode == 'ru') {
      return 'Спасибо за подписку, для тебя отчет бесплатно';
    }
    if (localeCode == 'kk') {
      return 'Жазылым үшін рақмет, сен үшін есеп тегін';
    }
    return 'Thanks for your subscription, this reading is free for you';
  }
  if (localeCode == 'ru') {
    return 'Этот расклад стоит $readingEnergyCost энергии. Если зайдет, в следующий раз можно взять подписку и получать такие разборы без лимита.';
  }
  if (localeCode == 'kk') {
    return 'Бұл жайылма $readingEnergyCost энергия тұрады. Ұнаса, келесі жолы жазылым алып, осындай талдауларды лимитсіз алуға болады.';
  }
  return 'This reading costs $readingEnergyCost energy. If you like it, next time you can get a subscription for unlimited readings.';
}

class _QuestionTypingBubble extends StatelessWidget {
  const _QuestionTypingBubble({
    required this.typing,
    required this.oneShotDots,
    required this.showDots,
    required this.localeCode,
    required this.question,
  });

  final Animation<double> typing;
  final Animation<double> oneShotDots;
  final bool showDots;
  final String localeCode;
  final String question;

  @override
  Widget build(BuildContext context) {
    final fullText = _loadingQuestionText(
      localeCode: localeCode,
      question: question,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([typing, oneShotDots]),
      builder: (context, _) {
        final t = Curves.easeOut.transform(typing.value);
        final visible = (fullText.length * t).round().clamp(1, fullText.length);
        final partial = fullText.substring(0, visible);
        return ChatBubble(
          isUser: false,
          avatarEmoji: '🪄',
          fullWidth: true,
          showAvatar: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(partial)),
              if (showDots) ...[
                const SizedBox(width: 6),
                _OneShotDots(progress: oneShotDots.value),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubscriptionTypingBubble extends StatelessWidget {
  const _SubscriptionTypingBubble({
    required this.typing,
    required this.oneShotDots,
    required this.showDots,
    required this.localeCode,
    required this.isUnlimitedUser,
    required this.readingEnergyCost,
  });

  final Animation<double> typing;
  final Animation<double> oneShotDots;
  final bool showDots;
  final String localeCode;
  final bool isUnlimitedUser;
  final int readingEnergyCost;

  @override
  Widget build(BuildContext context) {
    final fullText = _subscriptionLoaderText(
      localeCode: localeCode,
      isUnlimitedUser: isUnlimitedUser,
      readingEnergyCost: readingEnergyCost,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([typing, oneShotDots]),
      builder: (context, _) {
        final t = Curves.easeOut.transform(typing.value);
        final visible = (fullText.length * t).round().clamp(1, fullText.length);
        final partial = fullText.substring(0, visible);
        return ChatBubble(
          isUser: false,
          avatarEmoji: '🪄',
          fullWidth: true,
          showAvatar: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(partial)),
              if (showDots) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _OneShotDots(progress: oneShotDots.value),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LoadingCardsRow extends StatelessWidget {
  const _LoadingCardsRow({
    required this.reveal,
    required this.drawnCards,
    required this.expectedCardsCount,
    required this.deckCoverUrl,
  });

  final Animation<double> reveal;
  final List<DrawnCardModel> drawnCards;
  final int expectedCardsCount;
  final String deckCoverUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final slots = 5;
    final shownCount = expectedCardsCount.clamp(1, slots);
    final items = List<Widget>.generate(slots, (index) {
      final showRealCard = index < drawnCards.length && index < shownCount;
      final intervalStart = (index * 0.12).clamp(0.0, 0.8);
      final intervalEnd = (intervalStart + 0.42).clamp(0.42, 1.0);
      final fade = CurvedAnimation(
        parent: reveal,
        curve:
            Interval(intervalStart, intervalEnd, curve: Curves.easeInOutCubic),
      );
      final item = AnimatedBuilder(
        animation: fade,
        builder: (context, _) {
          final t = fade.value;
          final cardName = showRealCard ? drawnCards[index].cardName : '';
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: Transform.scale(
                scale: 0.9 + (0.1 * t),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    showRealCard
                        ? CardAssetImage(
                            cardId: drawnCards[index].cardId,
                            width: 56,
                            height: 90,
                            showGlow: false,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : Container(
                            width: 56,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withOpacity(0.38),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  colorScheme.surface.withOpacity(0.2),
                                  BlendMode.srcATop,
                                ),
                                child: Image.network(
                                  deckCoverUrl,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: colorScheme.surfaceContainerHighest
                                          .withOpacity(0.45),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        cardName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 8.5,
                              height: 1.0,
                              color: colorScheme.onSurface.withOpacity(0.58),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: item,
      );
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items,
      ),
    );
  }
}

class _OneShotDots extends StatelessWidget {
  const _OneShotDots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final t = Curves.easeInOut.transform(progress);
    double pulse(double center) {
      final distance = (t - center).abs();
      return (1.0 - (distance * 4)).clamp(0.0, 1.0);
    }

    final p0 = 0.2 + 0.8 * pulse(0.2);
    final p1 = 0.2 + 0.8 * pulse(0.5);
    final p2 = 0.2 + 0.8 * pulse(0.8);
    return SvgPicture.string(
      '''
<svg viewBox="0 0 34 6" xmlns="http://www.w3.org/2000/svg">
  <circle cx="3" cy="3" r="2.3" fill="${_hex(color)}" fill-opacity="${p0.toStringAsFixed(2)}"/>
  <circle cx="17" cy="3" r="2.3" fill="${_hex(color)}" fill-opacity="${p1.toStringAsFixed(2)}"/>
  <circle cx="31" cy="3" r="2.3" fill="${_hex(color)}" fill-opacity="${p2.toStringAsFixed(2)}"/>
</svg>
''',
      width: 34,
      height: 6,
    );
  }

  String _hex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.showExtra,
    required this.onNew,
    required this.onShare,
    required this.newLabel,
    required this.moreLabel,
  });

  static const double baseHeight = 86;
  static const double extraHeight = 70;

  final bool showExtra;
  final VoidCallback onNew;
  final VoidCallback onShare;
  final String newLabel;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: AppGhostButton(
                    label: newLabel,
                    icon: Icons.auto_awesome,
                    onPressed: onNew,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    );
                  },
                  child: showExtra
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: AppPrimaryButton(
                              label: moreLabel,
                              icon: Icons.auto_awesome_outlined,
                              onPressed: onShare,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumReadingBadge extends StatelessWidget {
  const _PremiumReadingBadge({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withOpacity(0.4),
              colorScheme.surface,
            ),
            Color.alphaBlend(
              colorScheme.primaryContainer.withOpacity(0.58),
              colorScheme.surface,
            ),
            Color.alphaBlend(
              colorScheme.tertiaryContainer.withOpacity(0.42),
              colorScheme.surface,
            ),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withOpacity(0.48)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _badgeLabel(context),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withOpacity(0.86),
                ),
          ),
        ],
      ),
    );
  }

  String _badgeLabel(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'ПРЕМИУМ-РЕЖИМ';
    }
    if (code == 'kk') {
      return 'ПРЕМИУМ РЕЖИМ';
    }
    return 'PREMIUM MODE';
  }
}

class _PremiumReadingCard extends StatelessWidget {
  const _PremiumReadingCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withOpacity(0.08),
              colorScheme.surface,
            ),
            Color.alphaBlend(
              colorScheme.secondary.withOpacity(0.06),
              colorScheme.surface,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LenormandSequenceCard extends StatelessWidget {
  const _LenormandSequenceCard({
    required this.step,
    required this.total,
    required this.card,
    required this.text,
    required this.previousCards,
    required this.onCardTap,
  });

  final int step;
  final int total;
  final DrawnCardModel card;
  final String text;
  final List<DrawnCardModel> previousCards;
  final VoidCallback onCardTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final previousNames = previousCards
        .map((item) => item.cardName.trim())
        .where((name) => name.isNotEmpty)
        .join(' → ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.resultLenormandStep(step, total),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          CardFaceWidget(
            cardId: card.cardId,
            cardName: card.cardName,
            keywords: card.keywords,
            showContainer: false,
            overlayHeaderOnImage: true,
            showKeywords: false,
            padding: EdgeInsets.zero,
            onCardTap: onCardTap,
          ),
          const SizedBox(height: 10),
          if (previousNames.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                '${l10n.resultLenormandBuildsOn}: $previousNames',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            card.positionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinkifiedText(
            text.trim().isEmpty ? l10n.resultStatusUnexpectedResponse : text,
          ),
        ],
      ),
    );
  }
}

class _ShareWithFriendsCard extends StatelessWidget {
  const _ShareWithFriendsCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.copiedLabel,
    required this.shareUrl,
    required this.shareMessage,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final String copiedLabel;
  final String shareUrl;
  final String shareMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.primary.withOpacity(0.06),
        border: Border.all(color: colorScheme.primary.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          AppGhostButton(
            label: buttonLabel,
            icon: Icons.ios_share,
            onPressed: () async {
              final textToCopy = '$shareMessage\n$shareUrl';
              await Clipboard.setData(ClipboardData(text: textToCopy));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(copiedLabel)),
                );
              }
              final shareUri = Uri.parse(
                'https://t.me/share/url?url=${Uri.encodeComponent(shareUrl)}'
                '&text=${Uri.encodeComponent(shareMessage)}',
              );
              await launchUrl(shareUri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}

class _DetailsCardThumbnails extends StatelessWidget {
  const _DetailsCardThumbnails({
    required this.spread,
    required this.spreadType,
    required this.drawnCards,
  });

  final SpreadModel spread;
  final SpreadType? spreadType;
  final List<DrawnCardModel> drawnCards;

  @override
  Widget build(BuildContext context) {
    final cards = _thumbnailCards();
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = cards.length;
        final isFiveCard = count >= 5;
        final spacing = isFiveCard ? 6.0 : 10.0;
        const maxCardWidth = 56.0;
        const minCardWidth = 42.0;
        final totalSpacing = spacing * (count - 1);
        final allowedWidth = constraints.maxWidth - totalSpacing;
        final cardWidth =
            (allowedWidth / count).clamp(minCardWidth, maxCardWidth);
        final cardHeight = cardWidth * (88 / 56);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              _DetailThumbnailCard(
                cardId: cards[i].cardId,
                isBack: cards[i].isBack,
                highlight: cards[i].highlight,
                width: cardWidth,
                height: cardHeight,
              ),
              if (i != cards.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }

  List<_ThumbnailCardData> _thumbnailCards() {
    final resolvedType = spreadType ??
        (spread.positions.length >= 5
            ? SpreadType.five
            : spread.positions.length >= 3
                ? SpreadType.three
                : SpreadType.one);
    if (resolvedType.cardCount <= 1) {
      return const [];
    }
    final isFiveCard = resolvedType.cardCount >= 5 && drawnCards.length >= 5;
    if (isFiveCard) {
      final cards = drawnCards.take(5).toList();
      return [
        _ThumbnailCardData(cardId: cards[0].cardId),
        _ThumbnailCardData(cardId: cards[1].cardId),
        _ThumbnailCardData(
          cardId: cards[2].cardId,
          highlight: true,
        ),
        _ThumbnailCardData(cardId: cards[3].cardId),
        _ThumbnailCardData(cardId: cards[4].cardId),
      ];
    }
    final isThreeCard = resolvedType.cardCount >= 3 && drawnCards.length >= 3;
    if (isThreeCard) {
      final cards = drawnCards.take(3).toList();
      return [
        _ThumbnailCardData(cardId: cards[0].cardId),
        _ThumbnailCardData(
          cardId: cards[1].cardId,
          highlight: true,
        ),
        _ThumbnailCardData(cardId: cards[2].cardId),
      ];
    }
    if (drawnCards.isEmpty) {
      final count = resolvedType.cardCount.clamp(2, 5);
      return List<_ThumbnailCardData>.generate(
        count,
        (_) => const _ThumbnailCardData(isBack: true),
      );
    }
    if (drawnCards.length == 1) {
      return const [];
    }
    final count = min(drawnCards.length, resolvedType.cardCount);
    return drawnCards
        .take(count)
        .map((card) => _ThumbnailCardData(cardId: card.cardId))
        .toList();
  }
}

class _DetailThumbnailCard extends ConsumerWidget {
  const _DetailThumbnailCard({
    required this.cardId,
    required this.isBack,
    required this.highlight,
    required this.width,
    required this.height,
  });

  final String? cardId;
  final bool isBack;
  final bool highlight;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(width >= 52 ? 12 : 10);
    final deckId = ref.watch(deckProvider);
    final cards = ref.watch(cardsAllProvider).asData?.value;
    final canonicalId = cardId == null ? null : canonicalCardId(cardId!);
    final resolvedImageUrl = cardId == null
        ? null
        : cards
            ?.firstWhere(
              (card) => card.id == canonicalId,
              orElse: () => const CardModel(
                id: '',
                deckId: DeckType.major,
                name: '',
                keywords: [],
                meaning: CardMeaning(
                  general: '',
                  light: '',
                  shadow: '',
                  advice: '',
                ),
                imageUrl: '',
              ),
            )
            .imageUrl;
    final card = isBack
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(
                    highlight ? 0.28 : 0.16,
                  ),
                  blurRadius: highlight ? 16 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Image.network(
                deckCoverAssetPath(deckId),
                width: width,
                height: height,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  if (deckId != DeckType.major) {
                    return Image.network(
                      deckCoverAssetPath(DeckType.major),
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          )
        : CardAssetImage(
            cardId: cardId ?? '',
            imageUrl: resolvedImageUrl,
            width: width,
            height: height,
            borderRadius: radius,
            showGlow: highlight,
          );
    return Transform.scale(
      scale: highlight ? 1.02 : 1,
      child: card,
    );
  }
}

class _ThumbnailCardData {
  const _ThumbnailCardData({
    this.cardId,
    this.isBack = false,
    this.highlight = false,
  });

  final String? cardId;
  final bool isBack;
  final bool highlight;
}

String? _resolveImageUrl(List<CardModel> cards, String cardId) {
  if (cards.isEmpty) {
    return null;
  }
  final canonicalId = canonicalCardId(cardId);
  for (final card in cards) {
    if (card.id == canonicalId) {
      return card.imageUrl;
    }
  }
  return null;
}
