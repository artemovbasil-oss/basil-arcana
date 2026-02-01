import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/card_face_widget.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/reading_flow_controller.dart';
import '../../state/providers.dart';
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

    if (aiResult == null || spread == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeSequence(state);
        }
      });
    }

    final statusText = state.aiUsed ? 'AI reading' : _statusMessage(state);
    final detailsText = aiResult.requestId == null
        ? 'Request ID unavailable'
        : 'Request ID: ${aiResult.requestId}';

    return Scaffold(
      appBar: AppBar(title: const Text('Your reading')),
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
                  if (_sequenceComplete)
                    _DetailsTile(detailsText: detailsText),
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
                    const SnackBar(content: Text('Reading saved.')),
                  );
                }
              },
              onNew: () {
                ref.read(readingFlowControllerProvider.notifier).reset();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              onShare: () async {
                await Share.share(
                  aiResult.fullText,
                  subject: 'Basil\'s Arcana Reading',
                );
              },
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
              'Arcane Snapshot',
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
                cardName: drawn.cardName,
                keywords: drawn.keywords,
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
              'Why this reading',
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
              'Action step (next 24–72h)',
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

  String _statusMessage(ReadingFlowState state) {
    switch (state.aiErrorType) {
      case AiErrorType.missingApiKey:
        return 'AI disabled — API key not included in this build';
      case AiErrorType.unauthorized:
        return 'Unauthorized — check API key';
      case AiErrorType.noInternet:
        return 'No internet — showing offline reading';
      case AiErrorType.timeout:
        return 'AI is taking longer than usual — showing offline reading.';
      case AiErrorType.serverError:
        final status = state.aiErrorStatusCode;
        if (status != null) {
          return 'Server unavailable ($status) — showing offline reading';
        }
        return 'Server unavailable — showing offline reading';
      case AiErrorType.upstreamFailed:
        return 'Unexpected response — showing offline reading';
      case null:
        return 'AI interpretation unavailable — showing offline reading';
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

class _DetailsTile extends StatelessWidget {
  const _DetailsTile({required this.detailsText});

  final String detailsText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          'Details',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              detailsText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
  });

  final bool isVisible;
  final VoidCallback onSave;
  final VoidCallback onNew;
  final VoidCallback onShare;

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
                    label: const Text('Save reading'),
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
                    label: const Text('New reading'),
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
                    icon: const Icon(Icons.share),
                    label: const Text('Share text'),
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
