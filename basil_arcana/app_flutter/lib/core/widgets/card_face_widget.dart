import 'package:flutter/material.dart';

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
                final image = CardAssetImage(
                  cardId: cardId!,
                  width: cardWidth,
                  height: cardHeight,
                  borderRadius: BorderRadius.circular(8),
                  fit: BoxFit.cover,
                );
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onCardTap,
                    child: image,
                  ),
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
        ],
      ),
    );
  }
}
