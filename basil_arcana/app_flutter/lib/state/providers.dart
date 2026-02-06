import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/repositories/ai_repository.dart';
import '../data/repositories/card_stats_repository.dart';
import '../data/repositories/cards_repository.dart';
import '../data/repositories/data_repository.dart';
import '../data/repositories/readings_repository.dart';
import '../data/models/deck_model.dart';
import 'reading_flow_controller.dart';

final dataRepositoryProvider = Provider<DataRepository>((ref) {
  return DataRepository();
});

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepository();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

final readingsRepositoryProvider = Provider<ReadingsRepository>((ref) {
  return ReadingsRepository();
});

final cardStatsRepositoryProvider = Provider<CardStatsRepository>((ref) {
  return CardStatsRepository();
});

final readingFlowControllerProvider =
    StateNotifierProvider<ReadingFlowController, ReadingFlowState>((ref) {
  return ReadingFlowController(ref);
});

const _settingsBoxName = 'settings';
const _languageCodeKey = 'languageCode';
const _deckIdKey = 'deckId';

Locale _localeFromBox(Box<String> box) {
  final code = box.get(_languageCodeKey) ?? 'en';
  switch (code) {
    case 'ru':
      return const Locale('ru');
    case 'kk':
      return const Locale('kk');
    case 'en':
    default:
      return const Locale('en');
  }
}

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._box) : super(_localeFromBox(_box));

  final Box<String> _box;

  Future<void> setLocale(Locale locale) async {
    final languageCode = locale.languageCode;
    state = Locale(languageCode);
    await _box.put(_languageCodeKey, languageCode);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final box = Hive.box<String>(_settingsBoxName);
  return LocaleNotifier(box);
});

class DeckNotifier extends StateNotifier<DeckType> {
  DeckNotifier(this._box) : super(deckIdFromStorage(_box.get(_deckIdKey)));

  final Box<String> _box;

  Future<void> setDeck(DeckType deckId) async {
    state = deckId;
    await _box.put(_deckIdKey, deckStorageValues[deckId] ?? 'all');
  }
}

final deckProvider = StateNotifierProvider<DeckNotifier, DeckType>((ref) {
  final box = Hive.box<String>(_settingsBoxName);
  return DeckNotifier(box);
});

final useCachedCardsProvider = StateProvider<bool>((ref) => false);
final useCachedSpreadsProvider = StateProvider<bool>((ref) => false);

final cardsProvider = FutureProvider((ref) async {
  final locale = ref.watch(localeProvider);
  final deckId = ref.watch(deckProvider);
  final repo = ref.watch(cardsRepositoryProvider);
  final useCached = ref.watch(useCachedCardsProvider);
  if (useCached) {
    return repo.loadCachedCards(locale: locale, deckId: deckId);
  }
  return repo.fetchCards(locale: locale, deckId: deckId);
});

final spreadsProvider = FutureProvider((ref) async {
  final locale = ref.watch(localeProvider);
  final repo = ref.watch(dataRepositoryProvider);
  final useCached = ref.watch(useCachedSpreadsProvider);
  if (useCached) {
    return repo.loadCachedSpreads(locale: locale);
  }
  return repo.fetchSpreads(locale: locale);
});

final videoIndexProvider = FutureProvider<Set<String>?>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.fetchVideoIndex();
});
