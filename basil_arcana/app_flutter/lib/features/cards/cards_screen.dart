import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_web_app.dart';
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
    final useTelegramAppBar =
        TelegramWebApp.isTelegramWebView && TelegramWebApp.isTelegramMobile;

    return Scaffold(
      appBar: useTelegramAppBar ? null : AppBar(title: Text(l10n.cardsTitle)),
      body: SafeArea(
        top: useTelegramAppBar,
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
          error: (error, stackTrace) => Center(
            child: Text(
              l10n.cardsLoadError,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _precacheFirstCards(List<CardModel> cards) {
    if (_precacheDone) {
      return;
    }
    _precacheDone = true;
    final deckId = ref.read(deckProvider);
    final assetManifest =
        ref.read(cardAssetManifestProvider).asData?.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialCards = cards.take(6);
      for (final card in initialCards) {
        precacheImage(
          AssetImage(
            resolveCardAssetPath(
              card.id,
              deckId: deckId,
              manifest: assetManifest,
            ),
          ),
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
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
