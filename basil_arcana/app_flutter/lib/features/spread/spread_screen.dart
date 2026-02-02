import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../data/models/spread_model.dart';
import '../../state/providers.dart';
import '../shuffle/shuffle_screen.dart';

class SpreadScreen extends ConsumerWidget {
  const SpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spreadsAsync = ref.watch(spreadsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.spreadTitle)),
      body: spreadsAsync.when(
        data: (spreads) {
          final oneCardSpread = _findSpread(spreads, 1);
          final threeCardSpread = _findSpread(spreads, 3, fallbackIndex: 1);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (oneCardSpread != null)
                  Expanded(
                    child: _SpreadOptionCard(
                      spread: oneCardSpread,
                      title: l10n.spreadOneCardTitle,
                      subtitle: l10n.spreadOneCardSubtitle,
                      animation: const _OneCardAnimation(),
                    ),
                  ),
                if (oneCardSpread != null && threeCardSpread != null)
                  const SizedBox(height: 18),
                if (threeCardSpread != null)
                  Expanded(
                    child: _SpreadOptionCard(
                      spread: threeCardSpread,
                      title: l10n.spreadThreeCardTitle,
                      subtitle: l10n.spreadThreeCardSubtitle,
                      animation: _ThreeCardAnimation(
                        pastLabel: l10n.spreadLabelPast,
                        presentLabel: l10n.spreadLabelPresent,
                        futureLabel: l10n.spreadLabelFuture,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(l10n.spreadLoadError(error.toString()))),
      ),
    );
  }
}

SpreadModel? _findSpread(
  List<SpreadModel> spreads,
  int count, {
  int fallbackIndex = 0,
}) {
  for (final spread in spreads) {
    if (spread.positions.length == count) {
      return spread;
    }
  }
  if (spreads.isEmpty) {
    return null;
  }
  final index = fallbackIndex < spreads.length ? fallbackIndex : 0;
  return spreads[index];
}

class _SpreadOptionCard extends ConsumerWidget {
  const _SpreadOptionCard({
    required this.spread,
    required this.title,
    required this.subtitle,
    required this.animation,
  });

  final SpreadModel spread;
  final String title;
  final String subtitle;
  final Widget animation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        ref.read(readingFlowControllerProvider.notifier).selectSpread(spread);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShuffleScreen()),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: primary.withOpacity(0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                height: 140,
                child: animation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OneCardAnimation extends StatefulWidget {
  const _OneCardAnimation();

  @override
  State<_OneCardAnimation> createState() => _OneCardAnimationState();
}

class _OneCardAnimationState extends State<_OneCardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceVariant;
    final accent = theme.colorScheme.primary.withOpacity(0.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.48;
        final cardHeight = constraints.maxHeight * 0.7;
        return AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value;
            final lift = lerpDouble(26, -6, t)!;
            final settle = Curves.easeOut.transform(t);
            return Stack(
              alignment: Alignment.center,
              children: [
                _cardShape(
                  width: cardWidth,
                  height: cardHeight,
                  color: cardColor.withOpacity(0.65),
                  offset: const Offset(6, 10),
                ),
                _cardShape(
                  width: cardWidth,
                  height: cardHeight,
                  color: cardColor.withOpacity(0.8),
                  offset: const Offset(2, 4),
                ),
                Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.rotate(
                    angle: lerpDouble(0.08, 0.0, settle)!,
                    child: _cardShape(
                      width: cardWidth,
                      height: cardHeight,
                      color: theme.colorScheme.surface,
                      borderColor: accent,
                      elevationGlow: true,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ThreeCardAnimation extends StatefulWidget {
  const _ThreeCardAnimation({
    required this.pastLabel,
    required this.presentLabel,
    required this.futureLabel,
  });

  final String pastLabel;
  final String presentLabel;
  final String futureLabel;

  @override
  State<_ThreeCardAnimation> createState() => _ThreeCardAnimationState();
}

class _ThreeCardAnimationState extends State<_ThreeCardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fan;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _fan = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final accent = theme.colorScheme.primary.withOpacity(0.55);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.7),
      letterSpacing: 0.4,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.42;
        final cardHeight = constraints.maxHeight * 0.68;
        return AnimatedBuilder(
          animation: _fan,
          builder: (context, _) {
            final t = _fan.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                _cardShape(
                  width: cardWidth,
                  height: cardHeight,
                  color: cardColor.withOpacity(0.35),
                  offset: const Offset(6, 8),
                ),
                _cardShape(
                  width: cardWidth,
                  height: cardHeight,
                  color: cardColor.withOpacity(0.55),
                  offset: const Offset(2, 4),
                ),
                Transform.translate(
                  offset: Offset(-18 * t, -8 * t),
                  child: Transform.rotate(
                    angle: -0.18 * t,
                    child: _cardShape(
                      width: cardWidth,
                      height: cardHeight,
                      color: cardColor.withOpacity(0.8),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -12 * t),
                  child: _cardShape(
                    width: cardWidth,
                    height: cardHeight,
                    color: cardColor,
                    borderColor: accent,
                    elevationGlow: true,
                  ),
                ),
                Transform.translate(
                  offset: Offset(18 * t, -8 * t),
                  child: Transform.rotate(
                    angle: 0.18 * t,
                    child: _cardShape(
                      width: cardWidth,
                      height: cardHeight,
                      color: cardColor.withOpacity(0.8),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: cardHeight * 0.85,
                  child: Text(widget.pastLabel, style: labelStyle),
                ),
                Positioned(
                  top: cardHeight * 0.78,
                  child: Text(widget.presentLabel, style: labelStyle),
                ),
                Positioned(
                  right: 0,
                  top: cardHeight * 0.85,
                  child: Text(widget.futureLabel, style: labelStyle),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Widget _cardShape({
  required double width,
  required double height,
  required Color color,
  Offset offset = Offset.zero,
  Color? borderColor,
  bool elevationGlow = false,
}) {
  return Transform.translate(
    offset: offset,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(color: borderColor.withOpacity(0.7), width: 1.2)
            : null,
        boxShadow: elevationGlow
            ? [
                BoxShadow(
                  color: borderColor?.withOpacity(0.3) ?? Colors.transparent,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
    ),
  );
}
