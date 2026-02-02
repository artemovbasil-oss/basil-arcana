import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/card_face_widget.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/reading_flow_controller.dart';
import '../../state/providers.dart';
import '../cards/card_detail_screen.dart';
import 'widgets/chat_widgets.dart';

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
  int _itemCounter = 0;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    final aiResult = state.aiResult;
    final spread = state.spread;
    final l10n = AppLocalizations.of(context)!;

    if (aiResult == null || spread == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(text: statusText),
                  ),
                  const SizedBox(height: 18),
                  for (final item in _items) ...[
                    _buildChatItem(item),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            _ActionBar(
              isVisible: _sequenceComplete,
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
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
              saveLabel: l10n.resultSaveButton,
              newLabel: l10n.resultNewButton,
              moreLabel: l10n.resultWantMoreButton,
            ),
          ],
        ),
      ),
    );
  }

  void _initializeSequence(ReadingFlowState state) {
    _initialized = true;
    _sequenceComplete = false;
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
    _scrollToBottom();
    _queueNextBasilMessage();
  }

  void _queueNextBasilMessage() {
    if (_basilQueue.isEmpty) {
      setState(() {
        _sequenceComplete = true;
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _items.add(_ChatItem.typing(id: _nextId()));
    });
    _scrollToBottom();

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
      _scrollToBottom();
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
                        card: CardModel(
                          id: drawn.cardId,
                          name: drawn.cardName,
                          keywords: drawn.keywords,
                          meaning: drawn.meaning,
                        ),
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

    return items;
  }

  Widget _buildChatItem(_ChatItem item) {
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
      case AiErrorType.missingApiKey:
        return l10n.resultStatusMissingApiKey;
      case AiErrorType.unauthorized:
        return l10n.resultStatusUnauthorized;
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
      case AiErrorType.upstreamFailed:
        return l10n.resultStatusUnexpectedResponse;
      case null:
        return l10n.resultStatusInterpretationUnavailable;
    }
  }

  String _nextId() => 'chat_${_itemCounter++}';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final drawn in state.drawnCards) {
        precacheImage(
          AssetImage(cardAssetPath(drawn.cardId)),
          context,
        );
      }
    });
  }
}

class _ChatItem {
  const _ChatItem._({
    required this.id,
    required this.kind,
    this.child,
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
}

enum _ChatItemKind { user, basil, typing }

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
    required this.isVisible,
    required this.onSave,
    required this.onNew,
    required this.onShare,
    required this.saveLabel,
    required this.newLabel,
    required this.moreLabel,
  });

  final bool isVisible;
  final VoidCallback onSave;
  final VoidCallback onNew;
  final VoidCallback onShare;
  final String saveLabel;
  final String newLabel;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 0.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 360),
        opacity: isVisible ? 1 : 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isVisible ? onSave : null,
                    icon: const Icon(Icons.bookmark_add),
                    label: Text(saveLabel),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      backgroundColor: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isVisible ? onNew : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(newLabel),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isVisible ? onShare : null,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(moreLabel),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
