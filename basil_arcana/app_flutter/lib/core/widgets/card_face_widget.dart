import 'package:flutter/material.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import 'tarot_asset_widgets.dart';

class CardFaceWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
                final image = CardMedia(
                  cardId: cardId!,
                  enableVideo: true,
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
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords
                .map(
                  (keyword) => Chip(
                    label: Text(keyword),
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: colorScheme.outlineVariant),
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                  ),
                )
                .toList(),
          ),
          if (onCardTap != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCardTap,
                child: Text(l10n.cardsDetailTitle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
