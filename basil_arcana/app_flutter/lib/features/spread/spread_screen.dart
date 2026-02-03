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
                      animation:
                          const SpreadIconDeck(mode: SpreadIconMode.oneCard),
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
                      animation:
                          const SpreadIconDeck(mode: SpreadIconMode.threeCards),
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
            color: primary.withOpacity(0.32),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.14),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        height: 1.35,
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

enum SpreadIconMode { oneCard, threeCards }

class SpreadIconDeck extends StatefulWidget {
  const SpreadIconDeck({
    super.key,
    required this.mode,
  });

  final SpreadIconMode mode;

  @override
  State<SpreadIconDeck> createState() => _SpreadIconDeckState();
}

class _SpreadIconDeckState extends State<SpreadIconDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
    final primary = theme.colorScheme.primary;
    final deckColor = _shiftLightness(primary, -0.18).withOpacity(0.95);
    final deckBorder = primary.withOpacity(0.75);
    final cardColor = _shiftLightness(primary, 0.1).withOpacity(0.92);
    final cardBorder = Colors.white.withOpacity(0.35);
    final shadow = primary.withOpacity(0.25);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final deckWidth = size.width * 0.46;
        final deckHeight = size.height * 0.68;
        final cardWidth = deckWidth;
        final cardHeight = deckHeight;
        const cardRadius = 16.0;

        return AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value;
            final baseOffset = Offset(size.width * 0.03, size.height * 0.04);
            return Stack(
              alignment: Alignment.center,
              children: [
                _deckCard(
                  width: deckWidth,
                  height: deckHeight,
                  color: deckColor.withOpacity(0.82),
                  borderColor: deckBorder.withOpacity(0.5),
                  borderRadius: cardRadius,
                  offset: baseOffset,
                ),
                _deckCard(
                  width: deckWidth,
                  height: deckHeight,
                  color: deckColor,
                  borderColor: deckBorder,
                  borderRadius: cardRadius,
                ),
                if (widget.mode == SpreadIconMode.oneCard)
                  _movingCard(
                    width: cardWidth,
                    height: cardHeight,
                    color: cardColor,
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    borderRadius: cardRadius,
                    offset: Offset(
                      lerpDouble(0, -11, t)!,
                      lerpDouble(0, -22, t)!,
                    ),
                    rotation: lerpDouble(0, -0.05, t)!,
                  ),
                if (widget.mode == SpreadIconMode.threeCards) ...[
                  _movingCard(
                    width: cardWidth,
                    height: cardHeight,
                    color: cardColor,
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    borderRadius: cardRadius,
                    offset: Offset(
                      lerpDouble(0, -13, t)!,
                      lerpDouble(0, -16, t)!,
                    ),
                    rotation: lerpDouble(0, -0.12, t)!,
                  ),
                  _movingCard(
                    width: cardWidth,
                    height: cardHeight,
                    color: cardColor,
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    borderRadius: cardRadius,
                    offset: Offset(
                      lerpDouble(0, 0, t)!,
                      lerpDouble(0, -21, t)!,
                    ),
                    rotation: lerpDouble(0, 0, t)!,
                  ),
                  _movingCard(
                    width: cardWidth,
                    height: cardHeight,
                    color: cardColor,
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    borderRadius: cardRadius,
                    offset: Offset(
                      lerpDouble(0, 13, t)!,
                      lerpDouble(0, -16, t)!,
                    ),
                    rotation: lerpDouble(0, 0.12, t)!,
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

Widget _deckCard({
  required double width,
  required double height,
  required Color color,
  required Color borderColor,
  required double borderRadius,
  Offset offset = Offset.zero,
}) {
  return Transform.translate(
    offset: offset,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.1),
      ),
    ),
  );
}

Widget _movingCard({
  required double width,
  required double height,
  required Color color,
  required Color borderColor,
  required Color shadowColor,
  required double borderRadius,
  required Offset offset,
  required double rotation,
}) {
  return Transform.translate(
    offset: offset,
    child: Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    ),
  );
}

Color _shiftLightness(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}
