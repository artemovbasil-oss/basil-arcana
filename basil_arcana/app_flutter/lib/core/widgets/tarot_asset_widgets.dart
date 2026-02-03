import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

String cardAssetPath(String cardId, {DeckId deckId = DeckId.major}) {
  if (deckId == DeckId.wands ||
      (deckId == DeckId.all && cardId.startsWith('wands_'))) {
    return 'assets/cards/wands/$cardId.webp';
  }
  switch (cardId) {
    case 'major_10_wheel':
      return 'assets/cards/major/major_10_wheel_of_fortune.webp';
    default:
      return 'assets/cards/major/$cardId.webp';
  }
}

String deckCoverAssetPath(DeckId deckId) {
  switch (deckId) {
    case DeckId.wands:
      return 'assets/deck/wands_cover.webp';
    case DeckId.major:
    case DeckId.all:
    default:
      return 'assets/deck/cover.webp';
  }
}

class CardAssetImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(18);
    final deckId = ref.watch(deckProvider);
    final image = Image.asset(
      cardAssetPath(cardId, deckId: deckId),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        if (deckId != DeckId.major) {
          return Image.asset(
            cardAssetPath(cardId, deckId: DeckId.major),
            width: width,
            height: height,
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              assert(() {
                debugPrint('Missing card asset for $cardId');
                return true;
              }());
              return _MissingCardPlaceholder(
                width: width,
                height: height,
                borderRadius: radius,
              );
            },
          );
        }
        assert(() {
          debugPrint('Missing card asset for $cardId');
          return true;
        }());
        return _MissingCardPlaceholder(
          width: width,
          height: height,
          borderRadius: radius,
        );
      },
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

class _MissingCardPlaceholder extends StatelessWidget {
  const _MissingCardPlaceholder({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border.all(color: colorScheme.primary.withOpacity(0.35)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome,
        color: colorScheme.primary.withOpacity(0.6),
        size: 32,
      ),
    );
  }
}

class DeckCoverBack extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);
    final deckId = ref.watch(deckProvider);
    final coverPath = deckCoverAssetPath(deckId);
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
          coverPath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            if (deckId != DeckId.major) {
              return Image.asset(
                deckCoverAssetPath(DeckId.major),
                width: width,
                height: height,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
