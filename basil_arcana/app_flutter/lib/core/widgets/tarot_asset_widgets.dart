import 'package:flutter/material.dart';

class CardAssetImage extends StatelessWidget {
  const CardAssetImage({
    super.key,
    required this.cardId,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showGlow = true,
  });

  final String cardId;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(18);
    final image = Image.asset(
      'assets/cards/major/$cardId.webp',
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.35),
          width: 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: image,
      ),
    );
  }
}

class DeckCoverBack extends StatelessWidget {
  const DeckCoverBack({
    super.key,
    this.width = 160,
    this.height = 230,
    this.highlight = false,
  });

  final double width;
  final double height;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.primary.withOpacity(highlight ? 0.6 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(highlight ? 0.35 : 0.2),
            blurRadius: highlight ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/deck/cover.webp',
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
