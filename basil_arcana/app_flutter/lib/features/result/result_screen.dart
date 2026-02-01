import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/card_face_widget.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Your reading')),
      body: SafeArea(
        child: Column(
          children: [
            if (!state.aiUsed)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.errorMessage ??
                      'AI interpretation unavailable — showing offline reading',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TL;DR',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(aiResult.tldr),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...state.drawnCards.map((drawn) {
                    final section = sectionMap[drawn.positionId];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                      ),
                    );
                  }),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Why this reading',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(aiResult.why),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Action step (next 24–72h)',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(aiResult.action),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
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
                      child: const Text('Save reading'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(readingFlowControllerProvider.notifier).reset();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text('New reading'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: aiResult.fullText),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reading copied to clipboard.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Share'),
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
}
