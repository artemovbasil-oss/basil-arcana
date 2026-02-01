import 'dart:async';
import 'dart:math';

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
  Timer? _ctaTimer;
  bool _showCta = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _ctaTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _showCta = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ctaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    final cardsAsync = ref.watch(cardsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Shuffle the deck')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 280,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final t = _controller.value * 2 * pi;
                          final wave = sin(t);
                          final waveAlt = sin(t + pi / 2);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, 18),
                                child: CardBackWidget(
                                  depth: 0,
                                  glowColor: colorScheme.primary,
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(waveAlt * -10, 10),
                                child: Transform.rotate(
                                  angle: waveAlt * 0.04,
                                  child: CardBackWidget(
                                    depth: 1,
                                    glowColor: colorScheme.primary,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(wave * 12, 4),
                                child: Transform.rotate(
                                  angle: wave * -0.05,
                                  child: CardBackWidget(
                                    depth: 2,
                                    glowColor: colorScheme.primary,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(wave * -18, 0),
                                child: Transform.rotate(
                                  angle: wave * 0.08,
                                  child: CardBackWidget(
                                    depth: 3,
                                    glowColor: colorScheme.primary,
                                    highlight: true,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Shuffling the deck...',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            if (state.isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            AnimatedSlide(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              offset: _showCta ? Offset.zero : const Offset(0, 0.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 360),
                opacity: _showCta ? 1 : 0,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !_showCta || state.isLoading
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Draw cards'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardBackWidget extends StatelessWidget {
  const CardBackWidget({
    super.key,
    required this.depth,
    required this.glowColor,
    this.highlight = false,
  });

  final int depth;
  final Color glowColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceVariant;
    final accent = glowColor.withOpacity(highlight ? 0.5 : 0.3);

    return Container(
      width: 160,
      height: 230,
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.7)),
          ),
          child: Center(
            child: Text(
              '✦',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
