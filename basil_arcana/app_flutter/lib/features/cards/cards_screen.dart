import 'dart:ui';

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
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedDeckChipsDelegate(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: _DeckChips(
                            sections: sections,
                            currentDeck: selectedDeck,
                            onSelect: (deck) => _scrollToSection(deck),
                          ),
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
                            childAspectRatio: 0.66,
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
    final rwsCards = <CardModel>[
      ...cards.where((card) => card.deckId == DeckType.major),
      ...cards.where((card) => card.deckId == DeckType.wands),
      ...cards.where((card) => card.deckId == DeckType.swords),
      ...cards.where((card) => card.deckId == DeckType.pentacles),
      ...cards.where((card) => card.deckId == DeckType.cups),
    ];
    final labels = <DeckType, String>{
      DeckType.major: 'RWS',
      DeckType.lenormand: l10n.deckLenormandName,
      DeckType.crowley: l10n.deckCrowleyName,
    };
    final sectionsMap = <DeckType, List<CardModel>>{
      DeckType.major: rwsCards,
      DeckType.lenormand:
          cards.where((card) => card.deckId == DeckType.lenormand).toList(),
      DeckType.crowley:
          cards.where((card) => card.deckId == DeckType.crowley).toList(),
    };
    final selectedTopDeck =
        selectedDeck == DeckType.lenormand || selectedDeck == DeckType.crowley
            ? selectedDeck
            : DeckType.major;
    final order = [DeckType.major, DeckType.lenormand, DeckType.crowley];
    if (selectedTopDeck != DeckType.major) {
      order
        ..remove(selectedTopDeck)
        ..insert(0, selectedTopDeck);
    }
    return [
      for (final deck in order)
        _DeckSection(
          deck: deck,
          label: labels[deck] ?? '',
          cards: sectionsMap[deck] ?? const [],
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
    required this.currentDeck,
    required this.onSelect,
  });

  final List<_DeckSection> sections;
  final DeckType currentDeck;
  final ValueChanged<DeckType> onSelect;

  @override
  Widget build(BuildContext context) {
    final activeDeck =
        currentDeck == DeckType.lenormand || currentDeck == DeckType.crowley
            ? currentDeck
            : DeckType.major;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            _DeckGlassChip(
              label: sections[i].label,
              isActive: sections[i].deck == activeDeck,
              onTap: () => onSelect(sections[i].deck),
            ),
            if (i != sections.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _DeckGlassChip extends StatelessWidget {
  const _DeckGlassChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.34)
              : colorScheme.surface.withValues(alpha: 0.2),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive
                      ? colorScheme.primary.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.26),
                ),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isActive
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedDeckChipsDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedDeckChipsDelegate({
    required this.child,
  });

  final Widget child;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedDeckChipsDelegate oldDelegate) {
    return oldDelegate.child != child;
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
    const imageAspectRatio = 0.68;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: imageAspectRatio,
                    child: CardAssetImage(
                      cardId: card.id,
                      imageUrl: card.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(12),
                      fit: BoxFit.cover,
                      showGlow: false,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _DrawnBadge(
                      label: drawnLabel,
                      isEmpty: drawnCount == 0,
                      smallRadius: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                card.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawnBadge extends StatelessWidget {
  const _DrawnBadge({
    required this.label,
    required this.isEmpty,
    this.smallRadius = false,
  });

  final String label;
  final bool isEmpty;
  final bool smallRadius;

  @override
  Widget build(BuildContext context) {
    final radius = smallRadius ? 10.0 : 999.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isEmpty ? 0.3 : 0.42),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEmpty ? 0.22 : 0.34),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w700,
                ),
          ),
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
