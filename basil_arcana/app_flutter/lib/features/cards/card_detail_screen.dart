import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/telegram/telegram_web_app.dart';
import '../../core/widgets/data_load_error.dart';
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
    final deckId = ref.watch(deckProvider);
    final videoIndex = ref.watch(videoIndexProvider).asData?.value;
    final availableVideos =
        videoIndex == null || videoIndex.isEmpty ? null : videoIndex;
    final resolvedCardId = card?.id ?? cardId;
    final cardsAsync = ref.watch(cardsProvider);
    final resolvedCard = _resolveCard(
      cardsAsync.asData?.value,
      resolvedCardId,
      card,
    );
    if (resolvedCard == null) {
      final repo = ref.read(cardsRepositoryProvider);
      final locale = ref.read(localeProvider);
      final cacheKey = repo.cardsCacheKey(locale);
      final debugInfo = kShowDiagnostics
          ? DataLoadDebugInfo(
              assetsBaseUrl: AssetsConfig.assetsBaseUrl,
              requests: {
                'cards (${repo.cardsFileNameForLocale(locale)})':
                    DataLoadRequestDebugInfo(
                  url: repo.lastAttemptedUrls[cacheKey] ?? '—',
                  statusCode: repo.lastStatusCodes[cacheKey],
                  contentType: repo.lastContentTypes[cacheKey],
                  contentLength: repo.lastContentLengths[cacheKey],
                  responseSnippetStart: repo.lastResponseSnippetsStart[cacheKey],
                  responseSnippetEnd: repo.lastResponseSnippetsEnd[cacheKey],
                  responseLength: repo.lastResponseStringLengths[cacheKey],
                  bytesLength: repo.lastResponseByteLengths[cacheKey],
                  rootType: repo.lastResponseRootTypes[cacheKey],
                ),
              },
              lastError: repo.lastError,
            )
          : null;
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
                : DataLoadError(
                    title: l10n.dataLoadTitle,
                    message: l10n.cardsLoadError,
                    retryLabel: l10n.dataLoadRetry,
                    onRetry: () => ref.invalidate(cardsProvider),
                    debugInfo: debugInfo,
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final mediaAssets = CardMediaResolver(
                    deckId: deckId,
                    availableVideoFiles: availableVideos,
                  ).resolve(
                    resolvedCard.id,
                    card: resolvedCard,
                    imageUrlOverride: resolvedCard.imageUrl,
                    videoUrlOverride: resolvedCard.videoUrl,
                  );
                  return SizedBox(
                    width: double.infinity,
                    height: 380,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                      child: CardMedia(
                        cardId: resolvedCard.id,
                        imageUrl: mediaAssets.imageUrl,
                        videoUrl: mediaAssets.videoUrl,
                        width: MediaQuery.of(context).size.width,
                        height: 380,
                        enableVideo: true,
                        autoPlayOnce: true,
                        playLabel: l10n.videoTapToPlay,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -48),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.94),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.18),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  side:
                                      BorderSide(color: colorScheme.outlineVariant),
                                  labelStyle: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
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
                              icon: Icons.bolt,
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
              ),
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
  if (cardId == null || cardId.isEmpty) {
    return fallback;
  }
  if (cards == null || cards.isEmpty) {
    return fallback;
  }
  return cards.firstWhere(
    (card) => card.id == cardId,
    orElse: () => fallback ?? cards.first,
  );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$value',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
