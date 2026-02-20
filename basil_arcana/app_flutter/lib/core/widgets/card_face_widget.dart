import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import 'tarot_asset_widgets.dart';
import '../theme/app_text_styles.dart';
import 'app_buttons.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

class CardFaceWidget extends ConsumerWidget {
  final String cardName;
  final List<String> keywords;
  final String? cardId;
  final VoidCallback? onCardTap;
  final bool showContainer;
  final bool overlayHeaderOnImage;
  final bool showKeywords;
  final EdgeInsetsGeometry padding;

  const CardFaceWidget({
    super.key,
    required this.cardName,
    required this.keywords,
    this.cardId,
    this.onCardTap,
    this.showContainer = true,
    this.overlayHeaderOnImage = false,
    this.showKeywords = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final deckId = ref.watch(deckProvider);
    final cardsAsync = ref.watch(cardsAllProvider);
    CardModel? resolvedCard;
    final cards = cardsAsync.asData?.value;
    if (cardId != null && cards != null) {
      final canonicalId = canonicalCardId(cardId!);
      for (final card in cards) {
        if (card.id == canonicalId) {
          resolvedCard = card;
          break;
        }
      }
    }
    final videoIndex = ref.watch(videoIndexProvider).asData?.value;
    final availableVideos =
        videoIndex == null || videoIndex.isEmpty ? null : videoIndex;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cardId != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth;
              final cardHeight = cardWidth * 1.5;
              final mediaAssets = CardMediaResolver(
                deckId: deckId,
                availableVideoFiles: availableVideos,
              ).resolve(
                resolvedCard?.id ?? canonicalCardId(cardId!),
                card: resolvedCard,
                imageUrlOverride: resolvedCard?.imageUrl,
                videoUrlOverride: resolvedCard?.videoUrl,
              );
              final image = CardMedia(
                cardId: resolvedCard?.id ?? canonicalCardId(cardId!),
                imageUrl: mediaAssets.imageUrl,
                videoUrl: mediaAssets.videoUrl,
                enableVideo: true,
                autoPlayOnce: true,
                playLabel: l10n.videoTapToPlay,
                width: cardWidth,
                height: cardHeight,
                borderRadius: BorderRadius.circular(
                  overlayHeaderOnImage ? 14 : 8,
                ),
                fit: BoxFit.cover,
              );
              return Stack(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: image,
                  ),
                  if (overlayHeaderOnImage)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.surface.withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              child: Text(
                                cardName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                          if (onCardTap != null) ...[
                            const SizedBox(width: 8),
                            _OverlayChipButton(
                              label: l10n.cardsDetailTitle,
                              onPressed: onCardTap!,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (!overlayHeaderOnImage) const SizedBox(height: 16),
        ],
        if (!overlayHeaderOnImage || cardId == null) ...[
          Text(
            cardName,
            style: AppTextStyles.title(context),
          ),
          const SizedBox(height: 8),
        ],
        if (showKeywords)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < keywords.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == keywords.length - 1 ? 0 : 8,
                    ),
                    child: Chip(
                      label: Text(keywords[i]),
                      backgroundColor: colorScheme.surface,
                      side: BorderSide(color: colorScheme.outlineVariant),
                      labelStyle: AppTextStyles.caption(context)
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
              ],
            ),
          ),
        if (onCardTap != null && !overlayHeaderOnImage) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSmallButton(
              onPressed: onCardTap,
              label: l10n.cardsDetailTitle,
            ),
          ),
        ],
      ],
    );
    if (!showContainer) {
      return Padding(
        padding: padding,
        child: content,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.primary.withOpacity(0.05),
      ),
      child: content,
    );
  }
}

class _OverlayChipButton extends StatelessWidget {
  const _OverlayChipButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
