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
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';
import 'card_detail_screen.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  bool _precacheDone = false;
  final ScrollController _scrollController = ScrollController();
  late final Map<DeckType, GlobalKey> _sectionKeys = {
    DeckType.major: GlobalKey(),
    DeckType.wands: GlobalKey(),
    DeckType.swords: GlobalKey(),
    DeckType.pentacles: GlobalKey(),
    DeckType.cups: GlobalKey(),
    DeckType.lenormand: GlobalKey(),
    DeckType.crowley: GlobalKey(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsAllProvider);
    final selectedDeck = ref.watch(deckProvider);
    final l10n = AppLocalizations.of(context);
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
                final sections = _buildDeckSections(
                  cards,
                  l10n,
                  selectedDeck: selectedDeck,
                );
                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: _DeckChips(
                          sections: sections,
                          onSelect: (deck) => _scrollToSection(deck),
                        ),
                      ),
                    ),
                    for (final section in sections) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          key: _sectionKeys[section.deck],
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            section.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.65),
                                ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.62,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = section.cards[index];
                              final count = statsRepository.getCount(card.id);
                              return _CardTile(
                                card: card,
                                drawnCount: count,
                                drawnLabel: l10n.cardsDrawnCount(count),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      settings: appRouteSettings(
                                        showBackButton: true,
                                      ),
                                      builder: (_) =>
                                          CardDetailScreen(card: card),
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: section.cards.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            final repo = ref.read(cardsRepositoryProvider);
            final locale = ref.read(localeProvider);
            final cacheKey = repo.cardsCacheKey(locale);
            DevFailureInfo? failureInfo;
            if (kEnableDevDiagnostics) {
              failureInfo = buildDevFailureInfo(
                FailedStage.cardsLocalLoad,
                error,
              );
              logDevFailure(failureInfo);
            }
            final debugInfo = kEnableDevDiagnostics
                ? DataLoadDebugInfo(
                    assetsBaseUrl: AssetsConfig.assetsBaseUrl,
                    requests: {
                      'cards (${repo.cardsFileNameForLocale(locale)})':
                          DataLoadRequestDebugInfo(
                        url: repo.lastAttemptedUrls[cacheKey] ?? '—',
                        statusCode: repo.lastStatusCodes[cacheKey],
                        contentType: repo.lastContentTypes[cacheKey],
                        contentLength: repo.lastContentLengths[cacheKey],
                        responseSnippetStart:
                            repo.lastResponseSnippetsStart[cacheKey],
                        responseSnippetEnd:
                            repo.lastResponseSnippetsEnd[cacheKey],
                        responseLength:
                            repo.lastResponseStringLengths[cacheKey],
                        bytesLength: repo.lastResponseByteLengths[cacheKey],
                        rootType: repo.lastResponseRootTypes[cacheKey],
                      ),
                    },
                    failedStage: failureInfo?.failedStage,
                    exceptionSummary: failureInfo?.summary,
                  )
                : null;
            return Center(
              child: DataLoadError(
                title: l10n.dataLoadTitle,
                message: l10n.cardsLoadError,
                retryLabel: l10n.dataLoadRetry,
                onRetry: () {
                  ref.invalidate(cardsAllProvider);
                },
                debugInfo: debugInfo,
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

  void _scrollToSection(DeckType deck) {
    final target = _sectionKeys[deck]?.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  List<_DeckSection> _buildDeckSections(
      List<CardModel> cards, AppLocalizations l10n,
      {required DeckType selectedDeck}) {
    final labels = <DeckType, String>{
      DeckType.major: l10n.deckMajorName,
      DeckType.wands: l10n.deckWandsName,
      DeckType.swords: l10n.deckSwordsName,
      DeckType.pentacles: l10n.deckPentaclesName,
      DeckType.cups: l10n.deckCupsName,
      DeckType.lenormand: l10n.deckLenormandName,
      DeckType.crowley: l10n.deckCrowleyName,
    };
    final order = [
      DeckType.major,
      DeckType.wands,
      DeckType.swords,
      DeckType.pentacles,
      DeckType.cups,
      DeckType.lenormand,
      DeckType.crowley,
    ];
    if (selectedDeck == DeckType.lenormand ||
        selectedDeck == DeckType.crowley) {
      order
        ..remove(selectedDeck)
        ..insert(0, selectedDeck);
    }
    return [
      for (final deck in order)
        _DeckSection(
          deck: deck,
          label: labels[deck] ?? '',
          cards: cards.where((card) => card.deckId == deck).toList(),
        ),
    ].where((section) => section.cards.isNotEmpty).toList();
  }
}

class _DeckSection {
  const _DeckSection({
    required this.deck,
    required this.label,
    required this.cards,
  });

  final DeckType deck;
  final String label;
  final List<CardModel> cards;
}

class _DeckChips extends StatelessWidget {
  const _DeckChips({
    required this.sections,
    required this.onSelect,
  });

  final List<_DeckSection> sections;
  final ValueChanged<DeckType> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            ActionChip(
              label: Text(sections[i].label),
              onPressed: () => onSelect(sections[i].deck),
              backgroundColor: colorScheme.surfaceVariant.withOpacity(0.6),
              shape: StadiumBorder(
                side: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
            if (i != sections.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
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
    const cardAspectRatio = 0.62;
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
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AspectRatio(
                    aspectRatio: cardAspectRatio,
                    child: CardAssetImage(
                      cardId: card.id,
                      imageUrl: card.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(12),
                      fit: BoxFit.contain,
                      showGlow: false,
                    ),
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

class _DrawnBadge extends StatelessWidget {
  const _DrawnBadge({required this.label, required this.isEmpty});

  final String label;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(isEmpty ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withOpacity(isEmpty ? 0.2 : 0.4),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(isEmpty ? 0.6 : 0.9),
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
