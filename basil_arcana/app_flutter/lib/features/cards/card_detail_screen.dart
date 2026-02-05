import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_web_app.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({
    super.key,
    this.card,
    this.cardId,
  });

  final CardModel? card;
  final String? cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final useTelegramAppBar =
        TelegramWebApp.isTelegramWebView && TelegramWebApp.isTelegramMobile;
    final deckId = ref.watch(deckProvider);
    final videoAssets = ref.watch(videoAssetManifestProvider).asData?.value;
    final resolvedCardId = card?.id ?? cardId;
    final cardsAsync = ref.watch(cardsProvider);
    final resolvedCard = _resolveCard(
      cardsAsync.asData?.value,
      resolvedCardId,
      card,
    );
    if (resolvedCard == null) {
      return Scaffold(
        appBar: useTelegramAppBar
            ? null
            : AppBar(
                title: Text(l10n.cardsDetailTitle),
              ),
        body: SafeArea(
          top: useTelegramAppBar,
          child: Center(
            child: cardsAsync.isLoading
                ? const CircularProgressIndicator()
                : Text(
                    l10n.cardsLoadError,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: useTelegramAppBar
          ? null
          : AppBar(
              title: Text(l10n.cardsDetailTitle),
            ),
      body: SafeArea(
        top: useTelegramAppBar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Builder(
                builder: (context) {
                  final mediaAssets = CardMediaResolver(
                    deckId: deckId,
                    availableVideoAssets: videoAssets,
                  ).resolve(
                    resolvedCard.id,
                    videoAssetPathOverride:
                        videoAssets == null ? resolvedCard.videoAssetPath : null,
                  );
                  return CardMedia(
                    cardId: resolvedCard.id,
                    videoAssetPath: mediaAssets.videoAssetPath,
                    width: 240,
                    height: 360,
                    enableVideo: true,
                    autoPlayOnce: true,
                    playLabel: l10n.videoTapToPlay,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              resolvedCard.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cardKeywordsTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 8),
            if (resolvedCard.keywords.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: resolvedCard.keywords
                    .map(
                      (keyword) => Chip(
                        label: Text(keyword),
                        backgroundColor: colorScheme.surface,
                        side: BorderSide(color: colorScheme.outlineVariant),
                        labelStyle: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      ),
                    )
                    .toList(),
              )
            else
              Text(
                l10n.cardDetailsFallback,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            Text(
              l10n.cardGeneralTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              resolvedCard.meaning.general,
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
              resolvedCard.detailedDescription?.trim().isNotEmpty ?? false
                  ? resolvedCard.detailedDescription!
                  : l10n.cardDetailsFallback,
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
              resolvedCard.funFact?.trim().isNotEmpty ?? false
                  ? resolvedCard.funFact!
                  : l10n.cardDetailsFallback,
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
            if (resolvedCard.stats != null)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: [
                  _StatTile(
                    label: l10n.statLuck,
                    value: resolvedCard.stats!.luck,
                    icon: Icons.auto_awesome,
                  ),
                  _StatTile(
                    label: l10n.statPower,
                    value: resolvedCard.stats!.power,
                    icon: Icons.flash_on,
                  ),
                  _StatTile(
                    label: l10n.statLove,
                    value: resolvedCard.stats!.love,
                    icon: Icons.favorite,
                  ),
                  _StatTile(
                    label: l10n.statClarity,
                    value: resolvedCard.stats!.clarity,
                    icon: Icons.visibility,
                  ),
                ],
              )
            else
              Text(
                l10n.cardDetailsFallback,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

CardModel? _resolveCard(
  List<CardModel>? cards,
  String? cardId,
  CardModel? fallback,
) {
  if (fallback != null) {
    return fallback;
  }
  if (cards == null || cardId == null) {
    return null;
  }
  final normalizedId = canonicalCardId(cardId);
  for (final card in cards) {
    if (canonicalCardId(card.id) == normalizedId) {
      return card;
    }
  }
  return null;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$value%',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
