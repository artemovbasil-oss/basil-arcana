import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/navigation/app_route_config.dart';
import '../../data/models/app_enums.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../debug/runtime_error_log_screen.dart';
import '../home/home_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final cards = ref.watch(cardsProvider).asData?.value ?? const <CardModel>[];
    final isDirty = settingsState.isDirty;
    final bottomPadding = isDirty ? 120.0 : 32.0;
    return Scaffold(
      appBar: buildTopBar(
        context,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RuntimeErrorLogScreen(),
              ),
            );
          },
          child: Text(l10n.settingsTitle),
        ),
        showBack: true,
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: isDirty
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: AppPrimaryButton(
                    label: l10n.actionApply,
                    onPressed: () async {
                      await settingsController.apply();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          settings: appRouteSettings(showBackButton: false),
                          builder: (_) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          children: [
            Text(
              l10n.languageLabel,
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              label: l10n.languageEnglish,
              language: AppLanguage.en,
              groupValue: settingsState.language,
              onSelected: (value) {
                settingsController.updateLanguage(value);
              },
            ),
            _LanguageOption(
              label: l10n.languageRussian,
              language: AppLanguage.ru,
              groupValue: settingsState.language,
              onSelected: (value) {
                settingsController.updateLanguage(value);
              },
            ),
            _LanguageOption(
              label: l10n.languageKazakh,
              language: AppLanguage.kz,
              groupValue: settingsState.language,
              onSelected: (value) {
                settingsController.updateLanguage(value);
              },
            ),
            const SizedBox(height: 20),
            Text(
              l10n.deckLabel,
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 8),
            _DeckOption(
              label: l10n.deckAll,
              deckType: DeckType.all,
              previewUrl: _previewImageUrl(cards, DeckType.all),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckMajor,
              deckType: DeckType.major,
              previewUrl: _previewImageUrl(cards, DeckType.major),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckWands,
              deckType: DeckType.wands,
              previewUrl: _previewImageUrl(cards, DeckType.wands),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckSwords,
              deckType: DeckType.swords,
              previewUrl: _previewImageUrl(cards, DeckType.swords),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckPentacles,
              deckType: DeckType.pentacles,
              previewUrl: _previewImageUrl(cards, DeckType.pentacles),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckCups,
              deckType: DeckType.cups,
              previewUrl: _previewImageUrl(cards, DeckType.cups),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.deckDebugLogLabel),
                onTap: () {
                  final path = _previewImageUrl(cards, DeckType.wands) ?? '—';
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
    required this.deckType,
    required this.previewUrl,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final DeckType deckType;
  final String? previewUrl;
  final DeckType groupValue;
  final ValueChanged<DeckType> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = deckType == groupValue;
    return Card(
      color: isSelected ? colorScheme.primary.withOpacity(0.12) : null,
      child: RadioListTile<DeckType>(
        value: deckType,
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
    required this.language,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final AppLanguage language;
  final AppLanguage groupValue;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = language == groupValue;
    return Card(
      color: isSelected ? colorScheme.primary.withOpacity(0.12) : null,
      child: RadioListTile<AppLanguage>(
        value: language,
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

String? _previewImageUrl(List<CardModel> cards, DeckType deckId) {
  if (cards.isEmpty) {
    return null;
  }
  String previewId;
  switch (deckId) {
    case DeckType.wands:
      previewId = wandsCardIds.first;
    case DeckType.swords:
      previewId = swordsCardIds.first;
    case DeckType.pentacles:
      previewId = pentaclesCardIds.first;
    case DeckType.cups:
      previewId = cupsCardIds.first;
    case DeckType.major:
    case DeckType.all:
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
