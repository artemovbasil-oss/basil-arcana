import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/card_face_widget.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/reading_flow_controller.dart';
import '../../state/providers.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(readingFlowControllerProvider);
    final aiResult = state.aiResult;
    final spread = state.spread;

    if (aiResult == null || spread == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sectionMap = {
      for (final section in aiResult.sections) section.positionId: section
    };

    final messages = <Widget>[];
    messages.add(
      _buildUserBubble(context, state.question),
    );
    messages.add(
      _buildAssistantBubble(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TL;DR', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(aiResult.tldr),
          ],
        ),
      ),
    );

    for (final drawn in state.drawnCards) {
      final section = sectionMap[drawn.positionId];
      messages.add(
        _buildAssistantBubble(
          context,
          Column(
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

    messages.add(
      _buildAssistantBubble(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why this reading',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(aiResult.why),
          ],
        ),
      ),
    );

    messages.add(
      _buildAssistantBubble(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Action step (next 24–72h)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(aiResult.action),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Your reading')),
      body: SafeArea(
        child: Column(
          children: [
            if (!state.aiUsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _StatusPill(
                  text: _statusMessage(state),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _StaggeredFadeSlide(
                      delay: Duration(milliseconds: 120 * index),
                      child: messages[index],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(readingFlowControllerProvider.notifier)
                            .saveReading();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reading saved.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('Save reading'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(readingFlowControllerProvider.notifier).reset();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('New reading'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Share.share(
                          aiResult.fullText,
                          subject: 'Basil\'s Arcana Reading',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share text'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        return 'Request timed out — showing offline reading';
      case AiErrorType.serverError:
        final status = state.aiErrorStatusCode;
        if (status != null) {
          return 'Server unavailable ($status) — showing offline reading';
        }
        return 'Server unavailable — showing offline reading';
      case null:
        return 'AI interpretation unavailable — showing offline reading';
    }
    return 'AI interpretation unavailable — showing offline reading';
  }
}

Widget _buildUserBubble(BuildContext context, String text) {
  final colorScheme = Theme.of(context).colorScheme;
  return Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.95),
              colorScheme.primary.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colorScheme.onPrimary),
        ),
      ),
    ),
  );
}

Widget _buildAssistantBubble(BuildContext context, Widget child) {
  final colorScheme = Theme.of(context).colorScheme;
  return Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.86,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
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

class _StaggeredFadeSlide extends StatefulWidget {
  const _StaggeredFadeSlide({
    required this.child,
    required this.delay,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
