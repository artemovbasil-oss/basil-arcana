import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/data_load_error.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';
import '../../state/providers.dart';
import 'card_detail_screen.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  bool _precacheDone = false;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final l10n = AppLocalizations.of(context)!;
    final statsRepository = ref.watch(cardStatsRepositoryProvider);
    return Scaffold(
      appBar: buildTopBar(
        context,
        title: Text(l10n.cardsTitle),
        showBack: true,
      ),
      body: SafeArea(
        top: false,
        child: cardsAsync.when(
          data: (cards) {
            if (cards.isEmpty) {
              return _EmptyState(
                title: l10n.cardsEmptyTitle,
                subtitle: l10n.cardsEmptySubtitle,
              );
            }
            _precacheFirstCards(cards);
            return ValueListenableBuilder(
              valueListenable: statsRepository.listenable(),
              builder: (context, box, _) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final count = statsRepository.getCount(card.id);
                    return _CardTile(
                      card: card,
                      drawnCount: count,
                      drawnLabel: l10n.cardsDrawnCount(count),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: appRouteSettings(showBackButton: true),
                            builder: (_) => CardDetailScreen(card: card),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
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
                        responseSnippetStart:
                            repo.lastResponseSnippetsStart[cacheKey],
                        responseSnippetEnd:
                            repo.lastResponseSnippetsEnd[cacheKey],
                        responseLength: repo.lastResponseStringLengths[cacheKey],
                        bytesLength: repo.lastResponseByteLengths[cacheKey],
                        rootType: repo.lastResponseRootTypes[cacheKey],
                      ),
                    },
                    lastError: repo.lastError,
                  )
                : null;
            return Center(
              child: FutureBuilder<bool>(
                future: repo.hasCachedData(
                  locale.languageCode,
                  includeFallback: true,
                ),
                builder: (context, snapshot) {
                  final hasCache = snapshot.data ?? false;
                  return DataLoadError(
                    title: l10n.dataLoadTitle,
                    message: l10n.cardsLoadError,
                    retryLabel: l10n.dataLoadRetry,
                    onRetry: () {
                      ref.read(useCachedCardsProvider.notifier).state = false;
                      ref.invalidate(cardsProvider);
                    },
                    secondaryLabel: hasCache ? l10n.dataLoadUseCache : null,
                    onSecondary: hasCache
                        ? () {
                            ref.read(useCachedCardsProvider.notifier).state =
                                true;
                            ref.invalidate(cardsProvider);
                          }
                        : null,
                    debugInfo: debugInfo,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _precacheFirstCards(List<CardModel> cards) {
    if (_precacheDone) {
      return;
    }
    _precacheDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialCards = cards.take(6);
      for (final card in initialCards) {
        precacheImage(
          NetworkImage(card.imageUrl),
          context,
        );
      }
    });
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.drawnCount,
    required this.drawnLabel,
    required this.onTap,
  });

  final CardModel card;
  final int drawnCount;
  final String drawnLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceVariant.withOpacity(0.4),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: _DrawnBadge(
                  label: drawnLabel,
                  isEmpty: drawnCount == 0,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: CardAssetImage(
                    cardId: card.id,
                    imageUrl: card.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                card.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawnBadge extends StatelessWidget {
  const _DrawnBadge({
    required this.label,
    required this.isEmpty,
  });

  final String label;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isEmpty
            ? colorScheme.surfaceVariant.withOpacity(0.6)
            : colorScheme.primary.withOpacity(0.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: isEmpty
                ? colorScheme.onSurface.withOpacity(0.7)
                : colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
