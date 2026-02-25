import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_enums.dart';
import '../data/models/deck_model.dart';
import 'providers.dart';

class SettingsState {
  const SettingsState({
    required this.language,
    required this.deckType,
    required this.highContrastEnabled,
    required this.initialLanguage,
    required this.initialDeckType,
    required this.initialHighContrastEnabled,
  });

  final AppLanguage language;
  final DeckType deckType;
  final bool highContrastEnabled;
  final AppLanguage initialLanguage;
  final DeckType initialDeckType;
  final bool initialHighContrastEnabled;

  bool get isDirty =>
      language != initialLanguage ||
      deckType != initialDeckType ||
      highContrastEnabled != initialHighContrastEnabled;

  SettingsState copyWith({
    AppLanguage? language,
    DeckType? deckType,
    bool? highContrastEnabled,
    AppLanguage? initialLanguage,
    DeckType? initialDeckType,
    bool? initialHighContrastEnabled,
  }) {
    return SettingsState(
      language: language ?? this.language,
      deckType: deckType ?? this.deckType,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      initialLanguage: initialLanguage ?? this.initialLanguage,
      initialDeckType: initialDeckType ?? this.initialDeckType,
      initialHighContrastEnabled:
          initialHighContrastEnabled ?? this.initialHighContrastEnabled,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this.ref, SettingsState state) : super(state);

  final Ref ref;

  void updateLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
  }

  void updateDeck(DeckType deckType) {
    state = state.copyWith(deckType: deckType);
  }

  void updateHighContrast(bool enabled) {
    if (state.highContrastEnabled == enabled &&
        state.initialHighContrastEnabled == enabled) {
      return;
    }
    state = state.copyWith(
      highContrastEnabled: enabled,
      initialHighContrastEnabled: enabled,
    );
    unawaited(ref.read(highContrastProvider.notifier).setHighContrast(enabled));
  }

  Future<void> apply() async {
    final language = state.language;
    final deckType = state.deckType;
    await ref.read(localeProvider.notifier).setLocale(language.locale);
    await ref.read(deckProvider.notifier).setDeck(deckType);
    ref.invalidate(cardsProvider);
    ref.invalidate(cardsAllProvider);
    state = state.copyWith(
      initialLanguage: language,
      initialDeckType: deckType,
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider.autoDispose<SettingsController, SettingsState>((ref) {
  final locale = ref.watch(localeProvider);
  final deckType = ref.watch(deckProvider);
  final highContrastEnabled = ref.watch(highContrastProvider);
  final language = AppLanguageX.fromLocale(locale);
  return SettingsController(
    ref,
    SettingsState(
      language: language,
      deckType: deckType,
      highContrastEnabled: highContrastEnabled,
      initialLanguage: language,
      initialDeckType: deckType,
      initialHighContrastEnabled: highContrastEnabled,
    ),
  );
});
