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

  const CardFaceWidget({
    super.key,
    required this.cardName,
    required this.keywords,
    this.cardId,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.primary.withOpacity(0.05),
      ),
      child: Column(
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
                  imageUrl: resolvedCard?.imageUrl,
                  videoUrl: mediaAssets.videoUrl,
                  enableVideo: true,
                  autoPlayOnce: true,
                  playLabel: l10n.videoTapToPlay,
                  width: cardWidth,
                  height: cardHeight,
                  borderRadius: BorderRadius.circular(8),
                  fit: BoxFit.cover,
                );
                return Material(
                  color: Colors.transparent,
                  child: image,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Text(
            cardName,
            style: AppTextStyles.title(context),
          ),
          const SizedBox(height: 8),
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
          if (onCardTap != null) ...[
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
      ),
    );
  }
}
