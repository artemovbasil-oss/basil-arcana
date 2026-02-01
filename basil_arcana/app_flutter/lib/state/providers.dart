import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/repositories/ai_repository.dart';
import '../data/repositories/cards_repository.dart';
import '../data/repositories/readings_repository.dart';
import '../data/repositories/spreads_repository.dart';
import 'reading_flow_controller.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepository();
});

final spreadsRepositoryProvider = Provider<SpreadsRepository>((ref) {
  return SpreadsRepository();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

final readingsRepositoryProvider = Provider<ReadingsRepository>((ref) {
  return ReadingsRepository();
});

final readingFlowControllerProvider =
    StateNotifierProvider<ReadingFlowController, ReadingFlowState>((ref) {
  return ReadingFlowController(ref);
});

const _settingsBoxName = 'settings';
const _languageCodeKey = 'languageCode';

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

final cardsProvider = FutureProvider((ref) async {
  final repo = ref.watch(cardsRepositoryProvider);
  return repo.fetchCards();
});

final spreadsProvider = FutureProvider((ref) async {
  final locale = ref.watch(localeProvider);
  final repo = ref.watch(spreadsRepositoryProvider);
  return repo.fetchSpreads(locale: locale);
});
