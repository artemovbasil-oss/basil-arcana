import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_web_app.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
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
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckMajor,
              deckId: DeckId.major,
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckWands,
              deckId: DeckId.wands,
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckSwords,
              deckId: DeckId.swords,
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckPentacles,
              deckId: DeckId.pentacles,
              groupValue: deckId,
              onSelected: (value) {
                ref.read(deckProvider.notifier).setDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckCups,
              deckId: DeckId.cups,
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
                  final path = cardAssetPath(
                    'wands_13_ace',
                    deckId: DeckId.wands,
                  );
                  debugPrint('Wands sample asset: $path');
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
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final DeckId deckId;
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
