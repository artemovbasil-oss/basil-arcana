import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/card_face_widget.dart';
import '../../core/assets/asset_paths.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../data/models/drawn_card_model.dart';
import '../../data/models/spread_model.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/reading_flow_controller.dart';
import '../../state/providers.dart';
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
  Timer? _typingTimer;
  bool _sequenceComplete = false;
  bool _initialized = false;
  bool _precacheDone = false;
  bool _autoScrollEnabled = false;
  int _itemCounter = 0;
  String? _warmTip;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.listen<ReadingFlowState>(readingFlowControllerProvider, (prev, next) {
      if (prev?.detailsStatus != next.detailsStatus ||
          prev?.showDetailsCta != next.showDetailsCta) {
        _maybeScrollToBottom();
      }
    });
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
        return OracleWaitingScreen(
          onCancel: () {
            ref.read(readingFlowControllerProvider.notifier).cancelGeneration();
            Navigator.pop(context);
          },
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

      final statusText = state.isLoading
          ? l10n.resultStatusAiReading
          : _statusMessage(state, l10n);
      final canRetry = !state.isLoading && state.aiErrorType != null;
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.resultTitle),
          leading: Navigator.canPop(context) ? const BackButton() : null,
          automaticallyImplyLeading: Navigator.canPop(context),
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

    final statusText = state.aiUsed
        ? l10n.resultStatusAiReading
        : _statusMessage(state, l10n);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final listBottomPadding = 24 +
        _ActionBar.baseHeight +
        (_sequenceComplete ? _ActionBar.extraHeight : 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultTitle),
        leading: Navigator.canPop(context) ? const BackButton() : null,
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(20, 16, 20, listBottomPadding),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(text: statusText),
                  ),
                  const SizedBox(height: 18),
                  for (final item in _items) ...[
                    _buildChatItem(item, state),
                    const SizedBox(height: 14),
                  ],
                  if (state.showDetailsCta &&
                      state.detailsStatus == DetailsStatus.idle) ...[
                    ChatBubbleReveal(
                      child: ChatBubble(
                        isUser: false,
                        avatarEmoji: '🪄',
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
                        label: AppLocalizations.of(context)!
                            .resultDeepTypingLabel,
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
                        child: _DetailsCardThumbnails(
                          spread: spread,
                          drawnCards: state.drawnCards,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final section
                        in _buildDetailsSections(
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
                              Text(section.text),
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
                            ref
                                .read(
                                  readingFlowControllerProvider.notifier,
                                )
                                .tryAgainDetails();
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
                  onSave: () async {
                    await ref
                        .read(readingFlowControllerProvider.notifier)
                        .saveReading();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.resultSnackSaved)),
                      );
                    }
                  },
                  onNew: () {
                    ref.read(readingFlowControllerProvider.notifier).reset();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  onShare: () async {
                    final url = Uri.parse('https://t.me/tarot_arkana_bot');
                    await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  saveLabel: l10n.resultSaveButton,
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
    return type == AiErrorType.timeout || type == AiErrorType.serverError;
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

  List<_ChatItem> _buildBasilMessages(ReadingFlowState state) {
    final aiResult = state.aiResult!;
    final l10n = AppLocalizations.of(context)!;
    final sectionMap = {
      for (final section in aiResult.sections) section.positionId: section
    };

    final items = <_ChatItem>[];
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
            Text(aiResult.tldr),
          ],
        ),
      ),
    );

    for (final drawn in state.drawnCards) {
      final section = sectionMap[drawn.positionId];
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardFaceWidget(
                cardId: drawn.cardId,
                cardName: drawn.cardName,
                keywords: drawn.keywords,
                onCardTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
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
              Text(section?.text ?? ''),
            ],
          ),
        ),
      );
    }

    if (aiResult.why.trim().isNotEmpty) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.resultSectionWhy,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(aiResult.why),
            ],
          ),
        ),
      );
    }

    if (aiResult.action.trim().isNotEmpty) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.resultSectionAction,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(aiResult.action),
            ],
          ),
        ),
      );
    }

    if (_warmTip != null) {
      items.add(
        _ChatItem.basil(
          id: _nextId(),
          child: Text(_warmTip!),
        ),
      );
    }

    return items;
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
    final cards = ref.read(cardsProvider).asData?.value ?? const <CardModel>[];
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
    final cleaned = sanitized.trim().isEmpty ? rawText.trim() : sanitized.trim();
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
    final firstBody =
        cleaned.substring(firstIndex, secondIndex).trim();
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultTitle),
        leading: Navigator.canPop(context) ? const BackButton() : null,
        automaticallyImplyLeading: Navigator.canPop(context),
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
                'Open in Telegram to draw cards',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This experience needs Telegram to authenticate your reading.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onOpen,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Open in Telegram'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onBack,
                child: const Text('Back'),
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
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isActionable ? onDecline : null,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(l10n.resultDeepNotNow),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: isActionable
                    ? () async {
                        await onAccept();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(l10n.resultDeepShowDetails),
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
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(l10n.resultDeepNotNow),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(l10n.resultDeepTryAgain),
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.showExtra,
    required this.onSave,
    required this.onNew,
    required this.onShare,
    required this.saveLabel,
    required this.newLabel,
    required this.moreLabel,
  });

  static const double baseHeight = 86;
  static const double extraHeight = 70;

  final bool showExtra;
  final VoidCallback onSave;
  final VoidCallback onNew;
  final VoidCallback onShare;
  final String saveLabel;
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.bookmark_add),
                        label: Text(saveLabel),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                          backgroundColor: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNew,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(newLabel),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                          side: BorderSide(color: colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
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
                            child: OutlinedButton.icon(
                              onPressed: onShare,
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: Text(moreLabel),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: const StadiumBorder(),
                                side: BorderSide(color: colorScheme.primary),
                              ),
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

class _DetailsCardThumbnails extends StatelessWidget {
  const _DetailsCardThumbnails({
    required this.spread,
    required this.drawnCards,
  });

  final SpreadModel spread;
  final List<DrawnCardModel> drawnCards;

  @override
  Widget build(BuildContext context) {
    final cards = _thumbnailCards();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          _DetailThumbnailCard(
            cardId: cards[i].cardId,
            isBack: cards[i].isBack,
            highlight: cards[i].highlight,
          ),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  List<_ThumbnailCardData> _thumbnailCards() {
    if (spread.positions.length >= 3 && drawnCards.length >= 3) {
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
      return const [
        _ThumbnailCardData(isBack: true),
        _ThumbnailCardData(isBack: true),
        _ThumbnailCardData(isBack: true),
      ];
    }
    return [
      const _ThumbnailCardData(isBack: true),
      _ThumbnailCardData(cardId: drawnCards.first.cardId),
      const _ThumbnailCardData(isBack: true),
    ];
  }
}

class _DetailThumbnailCard extends ConsumerWidget {
  const _DetailThumbnailCard({
    required this.cardId,
    required this.isBack,
    required this.highlight,
  });

  final String? cardId;
  final bool isBack;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    final deckId = ref.watch(deckProvider);
    final cards = ref.watch(cardsProvider).asData?.value;
    final resolvedImageUrl = cardId == null
        ? null
        : cards
            ?.firstWhere(
              (card) => card.id == cardId,
              orElse: () => const CardModel(
                id: '',
                deckId: DeckId.major,
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
                width: 56,
                height: 88,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  if (deckId != DeckId.major) {
                    return Image.network(
                      deckCoverAssetPath(DeckId.major),
                      width: 56,
                      height: 88,
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
            width: 56,
            height: 88,
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
  for (final card in cards) {
    if (card.id == cardId) {
      return card.imageUrl;
    }
  }
  return null;
}
