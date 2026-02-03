import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/widgets/tarot_asset_widgets.dart';
import '../../state/reading_flow_controller.dart';
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
  late final AnimationController _fallController;
  late final AnimationController _glowController;
  Timer? _ctaTimer;
  bool _showCta = false;
  bool _hasTriggeredFall = false;

  static const _deckCount = 8;
  static const _cardWidth = 120.0;
  static const _cardHeight = 176.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/deck/cover.webp'),
        context,
      );
    });
    _ctaTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _showCta = true;
        });
      }
    });
    ref.listen<ReadingFlowState>(readingFlowControllerProvider, (prev, next) {
      if (!_hasTriggeredFall &&
          (prev?.drawnCards.isEmpty ?? true) &&
          next.drawnCards.isNotEmpty) {
        _hasTriggeredFall = true;
        _controller.stop();
        _fallController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _fallController.dispose();
    _glowController.dispose();
    _ctaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    final cardsAsync = ref.watch(cardsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasDrawnCards = state.drawnCards.isNotEmpty;
    final keptCount = state.spread?.positions.length ?? 0;
    final showGlow = state.isLoading && hasDrawnCards;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shuffleTitle)),
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
                      width: 280,
                      height: 300,
                      child: hasDrawnCards
                          ? _DrawnStack(
                              keptCount: keptCount,
                              fallAnimation: CurvedAnimation(
                                parent: _fallController,
                                curve: Curves.easeIn,
                              ),
                              showGlow: showGlow,
                              glowAnimation: CurvedAnimation(
                                parent: _glowController,
                                curve: Curves.easeInOut,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final t = _controller.value * 2 * pi;
                                final phases = <double>[
                                  0,
                                  pi / 2,
                                  pi,
                                  3 * pi / 2,
                                  pi / 3,
                                ];
                                final baseOffsets = <Offset>[
                                  const Offset(0, 24),
                                  const Offset(-20, 12),
                                  const Offset(18, 6),
                                  const Offset(-12, -4),
                                  const Offset(12, -10),
                                ];
                                final baseAngles = <double>[
                                  -0.12,
                                  -0.06,
                                  0.05,
                                  0.11,
                                  -0.02,
                                ];
                                return Stack(
                                  alignment: Alignment.center,
                                  children:
                                      List.generate(phases.length, (index) {
                                    final wave = sin(t + phases[index]);
                                    final sway = cos(t + phases[index]);
                                    final offset = baseOffsets[index] +
                                        Offset(wave * 10, sway * 6);
                                    final angle = baseAngles[index] + wave * 0.08;
                                    return Transform.translate(
                                      offset: offset,
                                      child: Transform.rotate(
                                        angle: angle,
                                        child: const DeckCoverBack(),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.shuffleSubtitle,
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
                    child: Text(l10n.shuffleDrawButton),
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

class _DrawnStack extends StatelessWidget {
  const _DrawnStack({
    required this.keptCount,
    required this.fallAnimation,
    required this.showGlow,
    required this.glowAnimation,
  });

  final int keptCount;
  final Animation<double> fallAnimation;
  final bool showGlow;
  final Animation<double> glowAnimation;

  @override
  Widget build(BuildContext context) {
    final stackCount = max(keptCount, 1);
    final fallCount = _ShuffleScreenState._deckCount - stackCount;
    final fallOffsetBase = MediaQuery.of(context).size.height * 0.45;
    final baseOffsets = <Offset>[
      const Offset(0, 0),
      const Offset(-38, 6),
      const Offset(38, 6),
      const Offset(-24, -10),
      const Offset(24, -10),
      const Offset(-52, 14),
      const Offset(52, 14),
      const Offset(0, -18),
    ];
    final baseAngles = <double>[
      0,
      -0.08,
      0.08,
      -0.12,
      0.12,
      -0.18,
      0.18,
      0.04,
    ];

    return AnimatedBuilder(
      animation: fallAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < fallCount; i++)
              _FallingCard(
                index: i,
                offset: baseOffsets[i % baseOffsets.length],
                angle: baseAngles[i % baseAngles.length],
                fallOffset: fallOffsetBase + (i * 16),
                progress: fallAnimation.value,
              ),
            _RemainingCards(
              keptCount: stackCount,
              showGlow: showGlow,
              glowAnimation: glowAnimation,
            ),
          ],
        );
      },
    );
  }
}

class _RemainingCards extends StatelessWidget {
  const _RemainingCards({
    required this.keptCount,
    required this.showGlow,
    required this.glowAnimation,
  });

  final int keptCount;
  final bool showGlow;
  final Animation<double> glowAnimation;

  @override
  Widget build(BuildContext context) {
    final spacing = keptCount == 1 ? 0.0 : 74.0;
    final offsets = List.generate(keptCount, (index) {
      if (keptCount == 1) {
        return Offset.zero;
      }
      final start = -((keptCount - 1) / 2) * spacing;
      return Offset(start + index * spacing, 0);
    });

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        final glowStrength = showGlow
            ? (0.6 + sin(glowAnimation.value * pi) * 0.4)
            : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: List.generate(keptCount, (index) {
            return Transform.translate(
              offset: offsets[index],
              child: _MagicalGlowCard(
                glowStrength: glowStrength,
              ),
            );
          }),
        );
      },
    );
  }
}

class _FallingCard extends StatelessWidget {
  const _FallingCard({
    required this.index,
    required this.offset,
    required this.angle,
    required this.fallOffset,
    required this.progress,
  });

  final int index;
  final Offset offset;
  final double angle;
  final double fallOffset;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final drift = sin((index + 1) * 1.3) * 18;
    final yOffset = fallOffset * progress;
    final xOffset = offset.dx + drift * progress;
    final rotation = angle + progress * (index.isEven ? 0.22 : -0.18);
    return Transform.translate(
      offset: Offset(xOffset, offset.dy + yOffset),
      child: Transform.rotate(
        angle: rotation,
        child: const DeckCoverBack(
          width: _ShuffleScreenState._cardWidth,
          height: _ShuffleScreenState._cardHeight,
        ),
      ),
    );
  }
}

class _MagicalGlowCard extends StatelessWidget {
  const _MagicalGlowCard({required this.glowStrength});

  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF8F6BFF);
    final blur = 16 + (glowStrength * 18);
    final opacity = glowStrength * 0.45;
    final strokeOpacity = glowStrength * 0.55;
    final radius = BorderRadius.circular(18);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (glowStrength > 0)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
            ),
            child: Container(
              width: _ShuffleScreenState._cardWidth,
              height: _ShuffleScreenState._cardHeight,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: color.withOpacity(opacity * 0.55),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: color.withOpacity(strokeOpacity),
              width: 1.2,
            ),
            boxShadow: glowStrength > 0
                ? [
                    BoxShadow(
                      color: color.withOpacity(opacity),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: const DeckCoverBack(
            width: _ShuffleScreenState._cardWidth,
            height: _ShuffleScreenState._cardHeight,
          ),
        ),
      ],
    );
  }
}
