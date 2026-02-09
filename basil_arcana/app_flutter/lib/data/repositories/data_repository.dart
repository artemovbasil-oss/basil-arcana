import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/network/json_loader.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';
import '../models/spread_model.dart';
import '../models/card_video.dart';

class DataRepository {
  DataRepository({http.Client? client}) : _client = client ?? http.Client();

  static const int _cacheVersion = 3;
  final http.Client _client;
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
      '${_cardsPrefix}v${_cacheVersion}_${locale.languageCode}';

  String spreadsCacheKey(Locale locale) =>
      '${_spreadsPrefix}v${_cacheVersion}_${locale.languageCode}';

  String get videoIndexCacheKey => '${_videoIndexKey}_v${_cacheVersion}';

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
    required DeckType deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadRequiredAssetJson(
      assetPath: 'assets/data/${cardsFileNameForLocale(locale)}',
      cacheKey: cacheKey,
      validator: _isValidCardsJson,
      expectedRootTypes: {'Map'},
      errorMessage: 'Cards data missing or invalid',
    );
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<List<SpreadModel>> fetchSpreads({required Locale locale}) async {
    final cacheKey = spreadsCacheKey(locale);
    final raw = await _loadRequiredAssetJson(
      assetPath: 'assets/data/${spreadsFileNameForLocale(locale)}',
      cacheKey: cacheKey,
      validator: _isValidSpreadsJson,
      expectedRootTypes: {'List'},
      errorMessage: 'Spreads data missing or invalid',
    );
    return _parseSpreads(raw: raw);
  }

  Future<Set<String>?> fetchVideoIndex() async {
    final raw = await _loadOptionalJson(
      uri: Uri.parse(_withCacheBust('$assetsBaseUrl/data/video_index.json')),
      cacheKey: _videoIndexKey,
      validator: _isValidVideoIndex,
      expectedRootTypes: {'List', 'Map'},
    );
    if (raw == null) {
      return null;
    }
    return _parseVideoIndex(raw);
  }

  Future<String> _loadRequiredJson({
    required Uri uri,
    required String cacheKey,
    required bool Function(Object?) validator,
    required Set<String> expectedRootTypes,
    required String errorMessage,
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = '$errorMessage (${response.statusCode})';
        throw DataLoadException(_lastError!, cacheKey: cacheKey);
      }
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (!expectedRootTypes.contains(rootType) ||
          !validator(parsed.decoded)) {
        if (kEnableRuntimeLogs) {
          debugPrint(
            '[DataRepository] schemaMismatch cacheKey=$cacheKey rootType=$rootType',
          );
        }
        _lastError = '$errorMessage (schema mismatch)';
        throw DataLoadException(_lastError!, cacheKey: cacheKey);
      }
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (error is JsonFetchException && error.response != null) {
        _recordResponseInfo(cacheKey, error.response!);
      }
      throw DataLoadException(errorMessage, cacheKey: cacheKey);
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
        return null;
      }
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (!expectedRootTypes.contains(rootType) ||
          !validator(parsed.decoded)) {
        return null;
      }
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (error is JsonFetchException && error.response != null) {
        _recordResponseInfo(cacheKey, error.response!);
      }
      return null;
    }
  }

  Future<String> _loadRequiredAssetJson({
    required String assetPath,
    required String cacheKey,
    required bool Function(Object?) validator,
    required Set<String> expectedRootTypes,
    required String errorMessage,
  }) async {
    _lastAttemptedUrls[cacheKey] = assetPath;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final parsed = parseJsonString(raw);
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (!expectedRootTypes.contains(rootType) ||
          !validator(parsed.decoded)) {
        if (kEnableRuntimeLogs) {
          debugPrint(
            '[DataRepository] local schemaMismatch cacheKey=$cacheKey rootType=$rootType',
          );
        }
        _lastError = '$errorMessage (schema mismatch)';
        throw DataLoadException(_lastError!, cacheKey: cacheKey);
      }
      _recordLocalResponseInfo(cacheKey, parsed.raw);
      _lastCacheTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (kEnableRuntimeLogs) {
        debugPrint('[DataRepository] local load failed: $error');
      }
      throw DataLoadException(errorMessage, cacheKey: cacheKey);
    }
  }

  void _recordLocalResponseInfo(String cacheKey, String raw) {
    _lastStatusCodes[cacheKey] = 200;
    _lastContentTypes[cacheKey] = 'application/json';
    _lastContentLengths[cacheKey] = raw.length.toString();
    _lastResponseSnippetsStart[cacheKey] = _snippetStart(raw);
    _lastResponseSnippetsEnd[cacheKey] = _snippetEnd(raw);
    _lastResponseStringLengths[cacheKey] = raw.length;
    _lastResponseByteLengths[cacheKey] = raw.length;
  }

  Future<String?> _readCache(String cacheKey) async {
    return null;
  }

  Future<void> _storeCache(String cacheKey, String raw) async {
    return;
  }

  Future<bool> hasCachedData(String cacheKey) async {
    return false;
  }

  Future<List<CardModel>> loadCachedCards({
    required Locale locale,
    required DeckType deckId,
  }) async {
    throw DataLoadException('Cached cards disabled');
  }

  Future<List<SpreadModel>> loadCachedSpreads({required Locale locale}) async {
    throw DataLoadException('Cached spreads disabled');
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

  String _snippetStart(String body) {
    // Snippets are for debug diagnostics only; avoid collecting in release.
    if (!kDebugMode || body.isEmpty) {
      return '';
    }
    try {
      return body.length <= 200 ? body : body.substring(0, 200);
    } catch (_) {
      return '';
    }
  }

  String _snippetEnd(String body) {
    // Snippets are for debug diagnostics only; avoid collecting in release.
    if (!kDebugMode || body.isEmpty) {
      return '';
    }
    try {
      if (body.length <= 200) {
        return body;
      }
      return body.substring(body.length - 200);
    } catch (_) {
      return '';
    }
  }
}

String _withCacheBust(String url) {
  final version = AppConfig.appVersion.trim().isNotEmpty
      ? AppConfig.appVersion.trim()
      : 'dev';
  final uri = Uri.parse(url);
  final params = Map<String, String>.from(uri.queryParameters);
  params['v'] = version;
  return uri.replace(queryParameters: params).toString();
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

List<CardModel> _parseCards({required String raw, required DeckType deckId}) {
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
  final deckRegistry = <DeckType, List<CardModel>>{
    DeckType.major: majorCards,
    DeckType.wands: wandsCards,
    DeckType.swords: swordsCards,
    DeckType.pentacles: pentaclesCards,
    DeckType.cups: cupsCards,
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
  DeckType? selectedDeckType,
  Map<DeckType, List<CardModel>> deckRegistry,
) {
  if (selectedDeckType == null || selectedDeckType == DeckType.all) {
    return deckRegistry.values.expand((cards) => cards).toList();
  }
  return deckRegistry[selectedDeckType] ?? const [];
}
