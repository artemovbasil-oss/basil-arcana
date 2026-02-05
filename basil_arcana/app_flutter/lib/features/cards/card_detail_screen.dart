import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_web_app.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';
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
              child: CardMedia(
                cardId: resolvedCard.id,
                videoAssetPath: resolvedCard.videoAssetPath,
                width: 240,
                height: 360,
                enableVideo: true,
                playLabel: l10n.videoTapToPlay,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              resolvedCard.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (resolvedCard.keywords.isNotEmpty) ...[
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
                children: resolvedCard.keywords
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
            if (resolvedCard.detailedDescription?.isNotEmpty ?? false) ...[
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
                resolvedCard.detailedDescription!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (resolvedCard.funFact?.isNotEmpty ?? false) ...[
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
                resolvedCard.funFact!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (resolvedCard.stats != null) ...[
              const SizedBox(height: 20),
              Text(
                l10n.cardStatsTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
              _StatsRow(
                label: l10n.statLuck,
                value: resolvedCard.stats!.luck,
              ),
              const SizedBox(height: 10),
              _StatsRow(
                label: l10n.statPower,
                value: resolvedCard.stats!.power,
              ),
              const SizedBox(height: 10),
              _StatsRow(
                label: l10n.statLove,
                value: resolvedCard.stats!.love,
              ),
              const SizedBox(height: 10),
              _StatsRow(
                label: l10n.statClarity,
                value: resolvedCard.stats!.clarity,
              ),
            ],
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
  for (final card in cards) {
    if (card.id == cardId) {
      return card;
    }
  }
  return null;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '$value',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.surfaceVariant.withOpacity(0.4),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ],
    );
  }
}
