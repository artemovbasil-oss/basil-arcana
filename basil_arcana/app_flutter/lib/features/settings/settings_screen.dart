import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
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
        ],
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
