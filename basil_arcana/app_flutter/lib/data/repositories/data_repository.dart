import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/network/json_loader.dart';
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
  final Map<String, int> _lastStatusCodes = {};
  final Map<String, String> _lastResponseSnippetsStart = {};
  final Map<String, String> _lastResponseSnippetsEnd = {};
  final Map<String, String?> _lastContentTypes = {};
  final Map<String, String?> _lastContentLengths = {};
  final Map<String, int> _lastResponseStringLengths = {};
  final Map<String, int> _lastResponseByteLengths = {};
  final Map<String, String> _lastResponseRootTypes = {};
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
  UnmodifiableMapView<String, int> get lastStatusCodes =>
      UnmodifiableMapView(_lastStatusCodes);
  UnmodifiableMapView<String, String> get lastResponseSnippetsStart =>
      UnmodifiableMapView(_lastResponseSnippetsStart);
  UnmodifiableMapView<String, String> get lastResponseSnippetsEnd =>
      UnmodifiableMapView(_lastResponseSnippetsEnd);
  UnmodifiableMapView<String, String?> get lastContentTypes =>
      UnmodifiableMapView(_lastContentTypes);
  UnmodifiableMapView<String, String?> get lastContentLengths =>
      UnmodifiableMapView(_lastContentLengths);
  UnmodifiableMapView<String, int> get lastResponseStringLengths =>
      UnmodifiableMapView(_lastResponseStringLengths);
  UnmodifiableMapView<String, int> get lastResponseByteLengths =>
      UnmodifiableMapView(_lastResponseByteLengths);
  UnmodifiableMapView<String, String> get lastResponseRootTypes =>
      UnmodifiableMapView(_lastResponseRootTypes);
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
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadJsonWithFallback(
      uri: Uri.parse(cardsUrl(locale.languageCode)),
      cacheKey: cacheKey,
      validator: _isValidCardsJson,
      expectedRootTypes: {'Map'},
    );
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<List<SpreadModel>> fetchSpreads({required Locale locale}) async {
    final cacheKey = spreadsCacheKey(locale);
    final raw = await _loadJsonWithFallback(
      uri: Uri.parse(spreadsUrl(locale.languageCode)),
      cacheKey: cacheKey,
      validator: _isValidSpreadsJson,
      expectedRootTypes: {'List'},
    );
    return _parseSpreads(raw: raw);
  }

  Future<Set<String>?> fetchVideoIndex() async {
    final raw = await _loadOptionalJson(
      uri: Uri.parse('$assetsBaseUrl/data/video_index.json'),
      cacheKey: _videoIndexKey,
      validator: _isValidVideoIndex,
      expectedRootTypes: {'List', 'Map'},
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
    required Set<String> expectedRootTypes,
  }) async {
    _lastAttemptedUrls[cacheKey] = uri.toString();
    try {
      final result = await fetchJson(client: _client, uri: uri);
      _recordResponseInfo(cacheKey, result.response);
      final rootType = jsonRootType(result.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (!expectedRootTypes.contains(rootType)) {
        final expected = expectedRootTypes.join(' or ');
        throw DataLoadException(
          'Unexpected JSON root type: $rootType (expected $expected)',
          cacheKey: cacheKey,
        );
      }
      if (!validator(result.decoded)) {
        throw DataLoadException(
          'Invalid JSON payload: unexpected structure',
          cacheKey: cacheKey,
        );
      }
      await _storeCache(cacheKey, result.raw);
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return result.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (error is JsonFetchException && error.response != null) {
        _recordResponseInfo(cacheKey, error.response!);
      }
      if (kDebugMode) {
        debugPrint(
          '[DataRepository] fetchError url=${uri.toString()} '
          'cacheKey=$cacheKey error=${error.toString()}',
        );
      }
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        try {
          final parsed = parseJsonString(cached);
          final rootType = jsonRootType(parsed.decoded);
          _lastResponseRootTypes[cacheKey] = rootType;
          if (expectedRootTypes.contains(rootType) &&
              validator(parsed.decoded)) {
            _lastCacheTimes[cacheKey] = DateTime.now();
            return parsed.raw;
          }
        } on FormatException {
          // ignore invalid cache
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
    required Set<String> expectedRootTypes,
  }) async {
    _lastAttemptedUrls[cacheKey] = uri.toString();
    try {
      final response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      );
      final parsed = decodeJsonResponse(response: response, uri: uri);
      _recordResponseInfo(cacheKey, parsed.response);
      if (response.statusCode == 404 ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return await _readCache(cacheKey);
      }
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (!expectedRootTypes.contains(rootType) ||
          !validator(parsed.decoded)) {
        return await _readCache(cacheKey);
      }
      await _storeCache(cacheKey, parsed.raw);
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (error is JsonFetchException && error.response != null) {
        _recordResponseInfo(cacheKey, error.response!);
      }
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
    final parsed = parseJsonString(raw);
    final rootType = jsonRootType(parsed.decoded);
    _lastResponseRootTypes[cacheKey] = rootType;
    if (rootType != 'Map' || !_isValidCardsJson(parsed.decoded)) {
      throw DataLoadException('Cached cards are invalid', cacheKey: cacheKey);
    }
    _lastCacheTimes[cacheKey] = DateTime.now();
    return _parseCards(raw: parsed.raw, deckId: deckId);
  }

  Future<List<SpreadModel>> loadCachedSpreads({required Locale locale}) async {
    final cacheKey = spreadsCacheKey(locale);
    final raw = await _readCache(cacheKey);
    if (raw == null) {
      throw DataLoadException('No cached spreads available', cacheKey: cacheKey);
    }
    final parsed = parseJsonString(raw);
    final rootType = jsonRootType(parsed.decoded);
    _lastResponseRootTypes[cacheKey] = rootType;
    if (rootType != 'List' || !_isValidSpreadsJson(parsed.decoded)) {
      throw DataLoadException('Cached spreads are invalid', cacheKey: cacheKey);
    }
    _lastCacheTimes[cacheKey] = DateTime.now();
    return _parseSpreads(raw: parsed.raw);
  }

  void _recordResponseInfo(String cacheKey, JsonResponseInfo response) {
    _lastStatusCodes[cacheKey] = response.statusCode;
    _lastContentTypes[cacheKey] = response.contentType;
    _lastContentLengths[cacheKey] = response.contentLengthHeader;
    _lastResponseSnippetsStart[cacheKey] = response.responseSnippetStart;
    _lastResponseSnippetsEnd[cacheKey] = response.responseSnippetEnd;
    _lastResponseStringLengths[cacheKey] = response.stringLength;
    _lastResponseByteLengths[cacheKey] = response.bytesLength;
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
