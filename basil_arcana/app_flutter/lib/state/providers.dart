import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/repositories/ai_repository.dart';
import '../data/repositories/activity_stats_repository.dart';
import '../data/repositories/card_stats_repository.dart';
import '../data/repositories/cards_repository.dart';
import '../data/repositories/data_repository.dart';
import '../data/repositories/energy_topup_repository.dart';
import '../data/repositories/home_insights_repository.dart';
import '../data/repositories/query_history_repository.dart';
import '../data/repositories/spreads_repository.dart';
import '../data/repositories/readings_repository.dart';
import '../data/repositories/sofia_consent_repository.dart';
import '../data/repositories/user_dashboard_repository.dart';
import '../data/models/card_model.dart';
import '../data/models/deck_model.dart';
import '../features/home/self_analysis_report_service.dart';
import 'energy_controller.dart';
import 'reading_flow_controller.dart';

final dataRepositoryProvider = Provider<DataRepository>((ref) {
  return DataRepository();
});

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

final cardStatsRepositoryProvider = Provider<CardStatsRepository>((ref) {
  return CardStatsRepository();
});

final activityStatsRepositoryProvider =
    Provider<ActivityStatsRepository>((ref) {
  return ActivityStatsRepository();
});

final energyTopUpRepositoryProvider = Provider<EnergyTopUpRepository>((ref) {
  return EnergyTopUpRepository();
});

final sofiaConsentRepositoryProvider = Provider<SofiaConsentRepository>((ref) {
  return SofiaConsentRepository();
});

final queryHistoryRepositoryProvider = Provider<QueryHistoryRepository>((ref) {
  return QueryHistoryRepository();
});

final homeInsightsRepositoryProvider = Provider<HomeInsightsRepository>((ref) {
  return HomeInsightsRepository();
});

final userDashboardRepositoryProvider =
    Provider<UserDashboardRepository>((ref) {
  return UserDashboardRepository();
});

final selfAnalysisReportServiceProvider = Provider<SelfAnalysisReportService>((
  ref,
) {
  return SelfAnalysisReportService();
});

final readingFlowControllerProvider =
    StateNotifierProvider<ReadingFlowController, ReadingFlowState>((ref) {
  return ReadingFlowController(ref);
});

final energyProvider = StateNotifierProvider<EnergyController, EnergyState>((
  ref,
) {
  final box = Hive.box<String>(_settingsBoxName);
  return EnergyController(box);
});

const _settingsBoxName = 'settings';
const _languageCodeKey = 'languageCode';
const _deckIdKey = 'deckId';

String? _normalizeSupportedLanguageCode(String? raw) {
  final code = raw?.trim().toLowerCase() ?? '';
  if (code.startsWith('ru')) {
    return 'ru';
  }
  if (code.startsWith('kk') || code.startsWith('kz')) {
    return 'kk';
  }
  if (code.startsWith('en')) {
    return 'en';
  }
  return null;
}

Locale _localeFromLanguageCode(String code) {
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

String _resolveLanguageCode(Box<String> box) {
  final fromStorage =
      _normalizeSupportedLanguageCode(box.get(_languageCodeKey));
  if (fromStorage != null) {
    return fromStorage;
  }

  final fromQuery = _normalizeSupportedLanguageCode(
    Uri.base.queryParameters[_languageCodeKey],
  );
  if (fromQuery != null) {
    return fromQuery;
  }

  final fromSystem = _normalizeSupportedLanguageCode(
    PlatformDispatcher.instance.locale.languageCode,
  );
  return fromSystem ?? 'en';
}

Locale _localeFromBox(Box<String> box) {
  final code = _resolveLanguageCode(box);
  return _localeFromLanguageCode(code);
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

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final box = Hive.box<String>(_settingsBoxName);
  return LocaleNotifier(box);
});

class DeckNotifier extends StateNotifier<DeckType> {
  DeckNotifier(this._box)
      : super(normalizePrimaryDeckSelection(
          deckIdFromStorage(_box.get(_deckIdKey)),
        ));

  final Box<String> _box;

  Future<void> setDeck(DeckType deckId) async {
    final normalized = normalizePrimaryDeckSelection(deckId);
    state = normalized;
    await _box.put(_deckIdKey, deckStorageValues[normalized] ?? 'all');
  }
}

final deckProvider = StateNotifierProvider<DeckNotifier, DeckType>((ref) {
  final box = Hive.box<String>(_settingsBoxName);
  return DeckNotifier(box);
});

final cardsProvider = FutureProvider((ref) async {
  final locale = ref.watch(localeProvider);
  final deckId = ref.watch(deckProvider);
  final repo = ref.watch(cardsRepositoryProvider);
  return repo.fetchCards(locale: locale, deckId: deckId);
});

final cardsAllProvider = FutureProvider((ref) async {
  final locale = ref.watch(localeProvider);
  final repo = ref.watch(cardsRepositoryProvider);
  final allCards = await repo.fetchCards(locale: locale, deckId: DeckType.all);
  final byId = <String, CardModel>{for (final card in allCards) card.id: card};

  if (!allCards.any((card) => card.deckId == DeckType.lenormand)) {
    final lenormandCards =
        await repo.fetchCards(locale: locale, deckId: DeckType.lenormand);
    for (final card in lenormandCards) {
      byId.putIfAbsent(card.id, () => card);
    }
  }

  if (!allCards.any((card) => card.deckId == DeckType.crowley)) {
    final crowleyCards =
        await repo.fetchCards(locale: locale, deckId: DeckType.crowley);
    for (final card in crowleyCards) {
      byId.putIfAbsent(card.id, () => card);
    }
  }

  return byId.values.toList(growable: false);
});

final spreadsProvider = FutureProvider((ref) async {
  final locale = ref.watch(localeProvider);
  final repo = ref.watch(spreadsRepositoryProvider);
  return repo.fetchSpreads(locale: locale);
});

final videoIndexProvider = FutureProvider<Set<String>?>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.fetchVideoIndex();
});
