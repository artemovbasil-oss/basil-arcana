import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_enums.dart';
import '../data/models/deck_model.dart';
import 'providers.dart';

class SettingsState {
  const SettingsState({
    required this.language,
    required this.deckType,
    required this.initialLanguage,
    required this.initialDeckType,
  });

  final AppLanguage language;
  final DeckType deckType;
  final AppLanguage initialLanguage;
  final DeckType initialDeckType;

  bool get isDirty =>
      language != initialLanguage || deckType != initialDeckType;

  SettingsState copyWith({
    AppLanguage? language,
    DeckType? deckType,
    AppLanguage? initialLanguage,
    DeckType? initialDeckType,
  }) {
    return SettingsState(
      language: language ?? this.language,
      deckType: deckType ?? this.deckType,
      initialLanguage: initialLanguage ?? this.initialLanguage,
      initialDeckType: initialDeckType ?? this.initialDeckType,
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
  final language = AppLanguageX.fromLocale(locale);
  return SettingsController(
    ref,
    SettingsState(
      language: language,
      deckType: deckType,
      initialLanguage: language,
      initialDeckType: deckType,
    ),
  );
});
