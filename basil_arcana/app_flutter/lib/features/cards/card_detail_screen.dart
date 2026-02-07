import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_top_bar.dart';
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
      final cacheKey = repo.cardsCacheKey(locale.languageCode);
      final debugInfo = kShowDiagnostics
          ? DataLoadDebugInfo(
              assetsBaseUrl: AssetsConfig.assetsBaseUrl,
              requests: {
                'cards (${repo.cardsFileNameForLanguage(locale.languageCode)})':
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
        appBar: buildTopBar(
          context,
          title: Text(l10n.cardsDetailTitle),
          showBack: true,
        ),
        body: SafeArea(
          top: false,
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
      appBar: buildTopBar(
        context,
        title: Text(l10n.cardsDetailTitle),
        showBack: true,
      ),
      body: SafeArea(
        top: false,
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
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: TarotAssetWidget(
                                asset: mediaAssets,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Text(
                  resolvedCard.name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _KeywordsSection(
                  keywords: resolvedCard.keywords,
                  label: l10n.cardsDetailKeywordsTitle,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: _TextSection(
                  label: l10n.cardsDetailMeaningTitle,
                  value: resolvedCard.meaning.general,
                ),
              ),
            ),
            if (resolvedCard.detailedDescription != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _TextSection(
                    label: l10n.cardsDetailDescriptionTitle,
                    value: resolvedCard.detailedDescription!,
                  ),
                ),
              ),
            if (resolvedCard.funFact != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _TextSection(
                    label: l10n.cardsDetailFunFactTitle,
                    value: resolvedCard.funFact!,
                  ),
                ),
              ),
            if (resolvedCard.stats != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: _StatsSection(
                    stats: resolvedCard.stats!,
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
  CardModel? card,
) {
  if (card != null) {
    return card;
  }
  if (cards == null || cardId == null) {
    return null;
  }
  for (final entry in cards) {
    if (entry.id == cardId) {
      return entry;
    }
  }
  return null;
}

class _KeywordsSection extends StatelessWidget {
  const _KeywordsSection({
    required this.keywords,
    required this.label,
  });

  final List<String> keywords;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (keywords.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.sectionTitle(context),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: keywords
              .map(
                (keyword) => Chip(
                  label: Text(keyword),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.6),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.sectionTitle(context),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.body(context),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final CardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cardsDetailStatsTitle,
          style: AppTextStyles.sectionTitle(context),
        ),
        const SizedBox(height: 12),
        _StatRow(label: l10n.cardsDetailStatLuck, value: stats.luck),
        _StatRow(label: l10n.cardsDetailStatPower, value: stats.power),
        _StatRow(label: l10n.cardsDetailStatLove, value: stats.love),
        _StatRow(label: l10n.cardsDetailStatClarity, value: stats.clarity),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body(context),
            ),
          ),
          Text(
            value.toString(),
            style: AppTextStyles.body(context).copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
