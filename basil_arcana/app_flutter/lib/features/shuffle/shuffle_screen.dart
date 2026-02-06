import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/telegram/telegram_web_app.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/deck_model.dart';
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

  static const _deckCount = 3;
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
        NetworkImage(deckPreviewImageUrl(DeckId.major)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasDrawnCards = state.drawnCards.isNotEmpty;
    final keptCount = state.spread?.positions.length ?? 0;
    final showGlow = state.isLoading && hasDrawnCards;
    final useTelegramAppBar =
        TelegramWebApp.isTelegramWebView && TelegramWebApp.isTelegramMobile;

    return Scaffold(
      appBar: useTelegramAppBar ? null : AppBar(title: Text(l10n.shuffleTitle)),
      backgroundColor: colorScheme.background,
      body: SafeArea(
        top: useTelegramAppBar,
        child: Stack(
          children: [
            const Positioned.fill(child: _ShuffleBackground()),
            Padding(
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
                                      curve: Curves.easeOutCubic,
                                    ),
                                    showGlow: showGlow,
                                    glowAnimation: CurvedAnimation(
                                      parent: _glowController,
                                      curve: Curves.easeInOut,
                                    ),
                                  )
                                : _ShufflingStack(animation: _controller),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.shuffleSubtitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
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
                                      .read(
                                        readingFlowControllerProvider.notifier,
                                      )
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
    final drawnCount = max(keptCount, 1);
    final targets = _drawTargets(drawnCount);
    final rotations = _drawRotations(drawnCount);

    return AnimatedBuilder(
      animation: Listenable.merge([fallAnimation, glowAnimation]),
      builder: (context, child) {
        final glowStrength = showGlow
            ? (0.45 + sin(glowAnimation.value * pi) * 0.35)
            : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            _DeckStack(glowStrength: glowStrength),
            for (var i = 0; i < drawnCount; i++)
              _DrawnCard(
                index: i,
                targetOffset: targets[i],
                targetRotation: rotations[i],
                progress: fallAnimation,
              ),
          ],
        );
      },
    );
  }
}

List<Offset> _drawTargets(int count) {
  if (count <= 1) {
    return [const Offset(0, -6)];
  }
  if (count == 2) {
    return const [Offset(-64, -8), Offset(64, 8)];
  }
  return const [
    Offset(-78, -10),
    Offset(0, 12),
    Offset(78, -10),
  ];
}

List<double> _drawRotations(int count) {
  if (count <= 1) {
    return [0.02];
  }
  if (count == 2) {
    return [-0.06, 0.06];
  }
  return [-0.08, 0.02, 0.08];
}

class _DrawnCard extends StatelessWidget {
  const _DrawnCard({
    required this.index,
    required this.targetOffset,
    required this.targetRotation,
    required this.progress,
  });

  final int index;
  final Offset targetOffset;
  final double targetRotation;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final start = index * 0.14;
    final curve = CurvedAnimation(
      parent: progress,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        final offset = Offset.lerp(Offset.zero, targetOffset, t)!;
        final rotation = lerpDouble(0, targetRotation, t) ?? 0;
        final scale = lerpDouble(0.96, 1.0, t) ?? 1.0;
        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: const DeckCoverBack(
        width: _ShuffleScreenState._cardWidth,
        height: _ShuffleScreenState._cardHeight,
      ),
    );
  }
}

class _DeckStack extends StatelessWidget {
  const _DeckStack({required this.glowStrength});

  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final offsets = <Offset>[
      const Offset(6, 6),
      const Offset(-4, -4),
    ];
    final angles = <double>[0.03, -0.02];
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < offsets.length; i++)
          Transform.translate(
            offset: offsets[i],
            child: Transform.rotate(
              angle: angles[i],
              child: const DeckCoverBack(
                width: _ShuffleScreenState._cardWidth,
                height: _ShuffleScreenState._cardHeight,
              ),
            ),
          ),
        _MagicalGlowCard(glowStrength: glowStrength),
      ],
    );
  }
}

class _ShufflingStack extends StatelessWidget {
  const _ShufflingStack({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final baseOffsets = <Offset>[
      const Offset(0, 4),
      const Offset(-6, 8),
      const Offset(6, -6),
    ];
    final baseAngles = <double>[-0.04, 0.03, -0.02];
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value * 2 * pi;
        return Stack(
          alignment: Alignment.center,
          children: List.generate(baseOffsets.length, (index) {
            final wave = sin(t + index * 1.4);
            final offset = baseOffsets[index] + Offset(wave * 6, wave * 4);
            final angle = baseAngles[index] + wave * 0.04;
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

class _ShuffleBackground extends StatelessWidget {
  const _ShuffleBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.background;
    final glowColor = theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            background,
            background.withOpacity(0.92),
            background,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          _GlowOrb(
            alignment: const Alignment(-0.9, -0.7),
            color: glowColor,
            size: 220,
            opacity: 0.22,
          ),
          _GlowOrb(
            alignment: const Alignment(0.9, 0.7),
            color: glowColor,
            size: 280,
            opacity: 0.2,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(opacity),
                color.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
