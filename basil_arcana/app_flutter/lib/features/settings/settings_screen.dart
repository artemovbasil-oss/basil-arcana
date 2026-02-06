import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_web_app.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final deckId = ref.watch(deckProvider);
    final cards = ref.watch(cardsProvider).asData?.value ?? const <CardModel>[];
    final useTelegramAppBar =
        TelegramWebApp.isTelegramWebView && TelegramWebApp.isTelegramMobile;

    return Scaffold(
      appBar: useTelegramAppBar ? null : AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: useTelegramAppBar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l10n.languageLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              label: l10n.languageEnglish,
              locale: const Locale('en'),
              groupValue: locale,
              onSelected: (value) {
                ref.read(localeProvider.notifier).setLocale(value);
              },
            ),
            _LanguageOption(
              label: l10n.languageRussian,
              locale: const Locale('ru'),
              groupValue: locale,
              onSelected: (value) {
                ref.read(localeProvider.notifier).setLocale(value);
              },
            ),
            _LanguageOption(
              label: l10n.languageKazakh,
              locale: const Locale('kk'),
              groupValue: locale,
              onSelected: (value) {
                ref.read(localeProvider.notifier).setLocale(value);
              },
            ),
            const SizedBox(height: 20),
            Text(
              l10n.deckLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _DeckOption(
              label: l10n.deckAll,
              deckId: DeckId.all,
              previewUrl: _previewImageUrl(cards, DeckId.all),
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckMajor,
              deckId: DeckId.major,
              previewUrl: _previewImageUrl(cards, DeckId.major),
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckWands,
              deckId: DeckId.wands,
              previewUrl: _previewImageUrl(cards, DeckId.wands),
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckSwords,
              deckId: DeckId.swords,
              previewUrl: _previewImageUrl(cards, DeckId.swords),
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckPentacles,
              deckId: DeckId.pentacles,
              previewUrl: _previewImageUrl(cards, DeckId.pentacles),
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckCups,
              deckId: DeckId.cups,
              previewUrl: _previewImageUrl(cards, DeckId.cups),
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.deckDebugLogLabel),
                onTap: () {
                  final path = _previewImageUrl(cards, DeckId.wands) ?? '—';
                  debugPrint('Wands sample image: $path');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckOption extends StatelessWidget {
  const _DeckOption({
    required this.label,
    required this.deckId,
    required this.previewUrl,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final DeckId deckId;
  final String? previewUrl;
  final DeckId groupValue;
  final ValueChanged<DeckId> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: RadioListTile<DeckId>(
        value: deckId,
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) {
            onSelected(value);
          }
        },
        title: Text(label),
        secondary: _DeckPreviewThumbnail(imageUrl: previewUrl),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.locale,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final Locale locale;
  final Locale groupValue;
  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: RadioListTile<Locale>(
        value: locale,
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) {
            onSelected(value);
          }
        },
        title: Text(label),
      ),
    );
  }
}

class _DeckPreviewThumbnail extends StatelessWidget {
  const _DeckPreviewThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const width = 36.0;
    const height = 54.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageUrl == null || imageUrl!.isEmpty
          ? Container(
              width: width,
              height: height,
              color: Theme.of(context).colorScheme.surfaceVariant,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 16,
              ),
            )
          : Image.network(
              imageUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return const SizedBox(
                  width: width,
                  height: height,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: width,
                  height: height,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 16,
                  ),
                );
              },
            ),
    );
  }
}

String? _previewImageUrl(List<CardModel> cards, DeckId deckId) {
  if (cards.isEmpty) {
    return null;
  }
  String previewId;
  switch (deckId) {
    case DeckId.wands:
      previewId = wandsCardIds.first;
    case DeckId.swords:
      previewId = swordsCardIds.first;
    case DeckId.pentacles:
      previewId = pentaclesCardIds.first;
    case DeckId.cups:
      previewId = cupsCardIds.first;
    case DeckId.major:
    case DeckId.all:
      previewId = majorCardIds.first;
  }
  final normalizedId = canonicalCardId(previewId);
  for (final card in cards) {
    if (card.id == normalizedId) {
      return card.imageUrl;
    }
  }
  return cards.first.imageUrl;
}
