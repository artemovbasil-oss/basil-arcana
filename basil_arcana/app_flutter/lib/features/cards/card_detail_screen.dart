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
    final keywordLimit = 4;
    final visibleKeywords = card.keywords.take(keywordLimit).toList();
    final remainingKeywords = card.keywords.length - visibleKeywords.length;
    final detailedText = card.meaning.detailed.trim().isNotEmpty
        ? card.meaning.detailed
        : l10n.cardDetailedFallback;
    final funFactText = card.funFact.trim().isNotEmpty
        ? card.funFact
        : l10n.cardFunFactFallback;
    final stats = card.stats ??
        const CardStats(
          luck: 0,
          power: 0,
          love: 0,
          clarity: 0,
        );
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
              l10n.cardKeywordsTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...visibleKeywords.map(
                  (keyword) => Chip(
                    label: Text(keyword),
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: colorScheme.outlineVariant),
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (remainingKeywords > 0)
                  Chip(
                    label: Text('+$remainingKeywords'),
                    backgroundColor: colorScheme.surfaceVariant,
                    side: BorderSide(color: colorScheme.outlineVariant),
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Text(
            l10n.cardGeneralTitle,
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
          const SizedBox(height: 20),
          Text(
            l10n.cardDetailedTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            detailedText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.cardFunFactTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            funFactText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.cardStatsTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 12),
          _StatsGrid(stats: stats),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final CardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = [
      _StatTileData(
        icon: Icons.auto_awesome,
        label: l10n.statLuck,
        value: stats.luck,
      ),
      _StatTileData(
        icon: Icons.flash_on,
        label: l10n.statPower,
        value: stats.power,
      ),
      _StatTileData(
        icon: Icons.favorite,
        label: l10n.statLove,
        value: stats.love,
      ),
      _StatTileData(
        icon: Icons.visibility,
        label: l10n.statClarity,
        value: stats.clarity,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatTile(data: tiles[0])),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(data: tiles[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatTile(data: tiles[2])),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(data: tiles[3])),
          ],
        ),
      ],
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: colorScheme.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                '${data.value}%',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: data.value / 100,
            minHeight: 6,
            backgroundColor: colorScheme.surface,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
