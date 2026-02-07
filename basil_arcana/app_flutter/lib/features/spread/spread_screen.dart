import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/data_load_error.dart';
import '../../data/models/app_enums.dart';
import '../../data/models/spread_model.dart';
import '../../state/providers.dart';
import '../shuffle/shuffle_screen.dart';

class SpreadScreen extends ConsumerWidget {
  const SpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spreadsAsync = ref.watch(spreadsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: buildTopBar(
        context,
        title: Text(l10n.spreadTitle),
      ),
      body: SafeArea(
        top: false,
        child: spreadsAsync.when(
          data: (spreads) {
            final oneCardSpread = _resolveSpreadByType(
              spreads,
              SpreadType.one,
              l10n: l10n,
            );
            final threeCardSpread = _resolveSpreadByType(
              spreads,
              SpreadType.three,
              l10n: l10n,
            );

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (oneCardSpread != null)
                    Expanded(
                      child: _SpreadOptionCard(
                        spread: oneCardSpread,
                        spreadType: SpreadType.one,
                        title: l10n.spreadOneCardTitle,
                        subtitle: l10n.spreadOneCardSubtitle,
                        animation:
                            const SpreadIconDeck(mode: SpreadIconMode.oneCard),
                      ),
                    ),
                  if (oneCardSpread != null && threeCardSpread != null)
                    const SizedBox(height: 18),
                  if (threeCardSpread != null)
                    Expanded(
                      child: _SpreadOptionCard(
                        spread: threeCardSpread,
                        spreadType: SpreadType.three,
                        title: l10n.spreadThreeCardTitle,
                        subtitle: l10n.spreadThreeCardSubtitle,
                        animation: const SpreadIconDeck(
                          mode: SpreadIconMode.threeCards,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            final repo = ref.read(spreadsRepositoryProvider);
            final locale = ref.read(localeProvider);
            final cacheKey = repo.spreadsCacheKey(locale.languageCode);
            final debugInfo = kShowDiagnostics
                ? DataLoadDebugInfo(
                    assetsBaseUrl: AssetsConfig.assetsBaseUrl,
                    requests: {
                      'spreads (${repo.spreadsFileNameForLanguage(locale.languageCode)})':
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
                    message: l10n.dataLoadSpreadsError,
                    retryLabel: l10n.dataLoadRetry,
                    onRetry: () {
                      ref.read(useCachedSpreadsProvider.notifier).state = false;
                      ref.invalidate(spreadsProvider);
                    },
                    secondaryLabel: hasCache ? l10n.dataLoadUseCache : null,
                    onSecondary: hasCache
                        ? () {
                            ref.read(useCachedSpreadsProvider.notifier).state =
                                true;
                            ref.invalidate(spreadsProvider);
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
}

enum SpreadIconMode { oneCard, threeCards }

class SpreadIconDeck extends StatelessWidget {
  const SpreadIconDeck({super.key, required this.mode});

  final SpreadIconMode mode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardsToShow = mode == SpreadIconMode.oneCard ? 1 : 3;
    final offsets = <Offset>[
      const Offset(18, 6),
      const Offset(8, 3),
      const Offset(0, 0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final cardWidth = width * 0.62;
        final cardHeight = height * 0.78;
        return Stack(
          alignment: Alignment.center,
          children: List.generate(cardsToShow, (index) {
            final offset = offsets[index];
            final opacity = 0.35 + (index / cardsToShow) * 0.4;
            return Positioned(
              right: offset.dx,
              top: offset.dy,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

SpreadModel? _findSpread(
  List<SpreadModel> spreads,
  int count,
) {
  for (final spread in spreads) {
    final cardsCount = spread.cardsCount ?? spread.positions.length;
    if (cardsCount == count) {
      return spread;
    }
  }
  return null;
}

class _SpreadOptionCard extends ConsumerWidget {
  const _SpreadOptionCard({
    required this.spread,
    required this.spreadType,
    required this.title,
    required this.subtitle,
    required this.animation,
  });

  final SpreadModel spread;
  final SpreadType spreadType;
  final String title;
  final String subtitle;
  final Widget animation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        ref
            .read(readingFlowControllerProvider.notifier)
            .selectSpread(spread, spreadType);
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: appRouteSettings(showBackButton: true),
            builder: (_) => const ShuffleScreen(),
          ),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: primary.withOpacity(0.32),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.14),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surfaceVariant.withOpacity(0.18),
                        theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: animation,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: AppTextStyles.sectionTitle(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption(context).copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

SpreadModel? _resolveSpreadByType(
  List<SpreadModel> spreads,
  SpreadType spreadType, {
  required AppLocalizations l10n,
}) {
  final count = spreadType.cardCount;
  final found = _findSpread(spreads, count);
  if (found != null) {
    return found;
  }

  return SpreadModel(
    id: spreadType.storageValue,
    name: spreadType.storageValue,
    positions: List.generate(
      count,
      (index) => SpreadPosition(
        id: 'position_${index + 1}',
        title: l10n.spreadCardLabel(index + 1),
      ),
    ),
    cardsCount: count,
  );
}
