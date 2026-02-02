import 'package:flutter/material.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';

class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.card});

  final CardModel card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cardsDetailTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: CardAssetImage(
              cardId: card.id,
              width: 240,
              height: 360,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            card.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (card.keywords.isNotEmpty) ...[
            Text(
              l10n.cardsDetailKeywordsTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: card.keywords
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
            const SizedBox(height: 20),
          ],
          Text(
            l10n.cardsDetailMeaningTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            card.meaning.general,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
