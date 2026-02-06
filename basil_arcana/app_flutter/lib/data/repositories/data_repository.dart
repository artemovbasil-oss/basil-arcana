import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';
import '../models/spread_model.dart';
import '../models/card_video.dart';

class DataRepository {
  DataRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _memoryCache = {};
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, DateTime> _lastCacheTimes = {};
  final Map<String, String> _lastAttemptedUrls = {};
  SharedPreferences? _preferences;
  String? _lastError;

  static const String _cardsPrefix = 'cdn_cards_';
  static const String _spreadsPrefix = 'cdn_spreads_';
  static const String _videoIndexKey = 'cdn_video_index';

  UnmodifiableMapView<String, DateTime> get lastFetchTimes =>
      UnmodifiableMapView(_lastFetchTimes);
  UnmodifiableMapView<String, DateTime> get lastCacheTimes =>
      UnmodifiableMapView(_lastCacheTimes);
  UnmodifiableMapView<String, String> get lastAttemptedUrls =>
      UnmodifiableMapView(_lastAttemptedUrls);
  String? get lastError => _lastError;

  String get assetsBaseUrl => AssetsConfig.assetsBaseUrl;

  String cardsCacheKey(Locale locale) =>
      '$_cardsPrefix${locale.languageCode}';

  String spreadsCacheKey(Locale locale) =>
      '$_spreadsPrefix${locale.languageCode}';

  String get videoIndexCacheKey => _videoIndexKey;

  String cardsFileNameForLocale(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kz.json',
      _ => 'cards_en.json',
    };
  }

  String spreadsFileNameForLocale(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'spreads_ru.json',
      'kk' => 'spreads_kz.json',
      _ => 'spreads_en.json',
    };
  }

  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckId deckId,
  }) async {
    final filename = cardsFileNameForLocale(locale);
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadJsonWithFallback(
      uri: Uri.parse(cardsUrl(locale.languageCode)),
      cacheKey: cacheKey,
      validator: _isValidCardsJson,
    );
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<List<SpreadModel>> fetchSpreads({required Locale locale}) async {
    final filename = spreadsFileNameForLocale(locale);
    final cacheKey = spreadsCacheKey(locale);
    final raw = await _loadJsonWithFallback(
      uri: Uri.parse(spreadsUrl(locale.languageCode)),
      cacheKey: cacheKey,
      validator: _isValidSpreadsJson,
    );
    return _parseSpreads(raw: raw);
  }

  Future<Set<String>?> fetchVideoIndex() async {
    final raw = await _loadOptionalJson(
      uri: Uri.parse('$assetsBaseUrl/data/video_index.json'),
      cacheKey: _videoIndexKey,
      validator: _isValidVideoIndex,
    );
    if (raw == null) {
      return null;
    }
    return _parseVideoIndex(raw);
  }

  Future<SharedPreferences> _prefs() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    return prefs;
  }

  Future<String> _loadJsonWithFallback({
    required Uri uri,
    required String cacheKey,
    required bool Function(Object?) validator,
  }) async {
    _lastAttemptedUrls[cacheKey] = uri.toString();
    try {
      final response = await _client.get(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DataLoadException(
          'HTTP ${response.statusCode}',
          cacheKey: cacheKey,
        );
      }
      if (!validator(jsonDecode(response.body))) {
        throw DataLoadException('Invalid JSON payload', cacheKey: cacheKey);
      }
      await _storeCache(cacheKey, response.body);
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return response.body;
    } catch (error) {
      _lastError = error.toString();
      if (kDebugMode) {
        debugPrint(
          '[DataRepository] fetchError url=${uri.toString()} '
          'cacheKey=$cacheKey error=${error.toString()}',
        );
      }
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (validator(decoded)) {
          _lastCacheTimes[cacheKey] = DateTime.now();
          return cached;
        }
      }
      if (error is DataLoadException) {
        throw error;
      }
      throw DataLoadException(error.toString(), cacheKey: cacheKey);
    }
  }

  Future<String?> _loadOptionalJson({
    required Uri uri,
    required String cacheKey,
    required bool Function(Object?) validator,
  }) async {
    _lastAttemptedUrls[cacheKey] = uri.toString();
    try {
      final response = await _client.get(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      );
      if (response.statusCode == 404) {
        return await _readCache(cacheKey);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return await _readCache(cacheKey);
      }
      if (!validator(jsonDecode(response.body))) {
        return await _readCache(cacheKey);
      }
      await _storeCache(cacheKey, response.body);
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return response.body;
    } catch (error) {
      _lastError = error.toString();
      return await _readCache(cacheKey);
    }
  }

  Future<String?> _readCache(String cacheKey) async {
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final prefs = await _prefs();
    final raw = prefs.getString(cacheKey);
    if (raw != null) {
      _memoryCache[cacheKey] = raw;
    }
    return raw;
  }

  Future<void> _storeCache(String cacheKey, String raw) async {
    _memoryCache[cacheKey] = raw;
    final prefs = await _prefs();
    await prefs.setString(cacheKey, raw);
  }

  Future<bool> hasCachedData(String cacheKey) async {
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      return true;
    }
    final prefs = await _prefs();
    return prefs.containsKey(cacheKey);
  }

  Future<List<CardModel>> loadCachedCards({
    required Locale locale,
    required DeckId deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _readCache(cacheKey);
    if (raw == null) {
      throw DataLoadException('No cached cards available', cacheKey: cacheKey);
    }
    if (!_isValidCardsJson(jsonDecode(raw))) {
      throw DataLoadException('Cached cards are invalid', cacheKey: cacheKey);
    }
    _lastCacheTimes[cacheKey] = DateTime.now();
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<List<SpreadModel>> loadCachedSpreads({required Locale locale}) async {
    final cacheKey = spreadsCacheKey(locale);
    final raw = await _readCache(cacheKey);
    if (raw == null) {
      throw DataLoadException('No cached spreads available', cacheKey: cacheKey);
    }
    if (!_isValidSpreadsJson(jsonDecode(raw))) {
      throw DataLoadException('Cached spreads are invalid', cacheKey: cacheKey);
    }
    _lastCacheTimes[cacheKey] = DateTime.now();
    return _parseSpreads(raw: raw);
  }
}

class DataLoadException implements Exception {
  DataLoadException(this.message, {this.cacheKey});

  final String message;
  final String? cacheKey;

  @override
  String toString() => message;
}

bool _isValidCardsJson(Object? payload) {
  if (payload is! Map<String, dynamic> || payload.isEmpty) {
    return false;
  }
  final firstEntry = payload.entries.first;
  if (firstEntry.value is! Map<String, dynamic>) {
    return false;
  }
  final sample = firstEntry.value as Map<String, dynamic>;
  return sample.containsKey('title') &&
      (sample.containsKey('meaning') || sample.containsKey('summary'));
}

bool _isValidSpreadsJson(Object? payload) {
  if (payload is! List<dynamic> || payload.isEmpty) {
    return false;
  }
  final first = payload.first;
  if (first is! Map<String, dynamic>) {
    return false;
  }
  return first.containsKey('id') &&
      first.containsKey('name') &&
      first.containsKey('positions');
}

bool _isValidVideoIndex(Object? payload) {
  if (payload is List<dynamic>) {
    return payload.whereType<String>().isNotEmpty;
  }
  if (payload is Map<String, dynamic>) {
    final files = payload['files'] ?? payload['videos'] ?? payload['items'];
    if (files is List<dynamic>) {
      return files.whereType<String>().isNotEmpty;
    }
  }
  return false;
}

Set<String> _parseVideoIndex(String raw) {
  final decoded = jsonDecode(raw);
  List<String> files;
  if (decoded is List<dynamic>) {
    files = decoded.whereType<String>().toList();
  } else if (decoded is Map<String, dynamic>) {
    final items = decoded['files'] ?? decoded['videos'] ?? decoded['items'];
    if (items is List<dynamic>) {
      files = items.whereType<String>().toList();
    } else {
      files = const [];
    }
  } else {
    files = const [];
  }
  return files
      .map(normalizeVideoFileName)
      .map((file) => file.toLowerCase())
      .toSet();
}

List<CardModel> _parseCards({required String raw, required DeckId deckId}) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final canonicalData = _canonicalizeCardData(data);
  final majorCards = majorCardIds
      .where(canonicalData.containsKey)
      .map((id) => CardModel.fromLocalizedEntry(
            id,
            canonicalData[id] as Map<String, dynamic>,
          ))
      .toList();
  final wandsCards = wandsCardIds
      .where(canonicalData.containsKey)
      .map((id) => CardModel.fromLocalizedEntry(
            id,
            canonicalData[id] as Map<String, dynamic>,
          ))
      .toList();
  final swordsCards = swordsCardIds
      .where(canonicalData.containsKey)
      .map((id) => CardModel.fromLocalizedEntry(
            id,
            canonicalData[id] as Map<String, dynamic>,
          ))
      .toList();
  final pentaclesCards = pentaclesCardIds
      .where(canonicalData.containsKey)
      .map((id) => CardModel.fromLocalizedEntry(
            id,
            canonicalData[id] as Map<String, dynamic>,
          ))
      .toList();
  final cupsCards = cupsCardIds
      .where(canonicalData.containsKey)
      .map((id) => CardModel.fromLocalizedEntry(
            id,
            canonicalData[id] as Map<String, dynamic>,
          ))
      .toList();
  final deckRegistry = <DeckId, List<CardModel>>{
    DeckId.major: majorCards,
    DeckId.wands: wandsCards,
    DeckId.swords: swordsCards,
    DeckId.pentacles: pentaclesCards,
    DeckId.cups: cupsCards,
  };
  return getActiveDeckCards(deckId, deckRegistry);
}

List<SpreadModel> _parseSpreads({required String raw}) {
  final data = jsonDecode(raw) as List<dynamic>;
  return data.map((item) => SpreadModel.fromJson(item)).toList();
}

Map<String, Map<String, dynamic>> _canonicalizeCardData(
  Map<String, dynamic> data,
) {
  final canonical = <String, Map<String, dynamic>>{};
  for (final entry in data.entries) {
    final key = canonicalCardId(entry.key);
    canonical[key] = entry.value as Map<String, dynamic>;
  }
  return canonical;
}

List<CardModel> getActiveDeckCards(
  DeckId? selectedDeckId,
  Map<DeckId, List<CardModel>> deckRegistry,
) {
  if (selectedDeckId == null || selectedDeckId == DeckId.all) {
    return deckRegistry.values.expand((cards) => cards).toList();
  }
  return deckRegistry[selectedDeckId] ?? const [];
}
