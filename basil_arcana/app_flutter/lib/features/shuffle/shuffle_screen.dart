import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../result/result_screen.dart';

class ShuffleScreen extends ConsumerStatefulWidget {
  const ShuffleScreen({super.key});

  @override
  ConsumerState<ShuffleScreen> createState() => _ShuffleScreenState();
}

class _ShuffleScreenState extends ConsumerState<ShuffleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    final cardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shuffle the deck')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: RotationTransition(
                  turns: Tween(begin: -0.02, end: 0.02).animate(_controller),
                  child: Container(
                    width: 180,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Shuffling...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (state.isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final cards = await cardsAsync.valueOrNull;
                        if (cards == null) {
                          return;
                        }
                        await ref
                            .read(readingFlowControllerProvider.notifier)
                            .drawAndGenerate(cards);
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResultScreen(),
                            ),
                          );
                        }
                      },
                child: const Text('Draw cards'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
