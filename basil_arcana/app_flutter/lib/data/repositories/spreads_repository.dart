import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/assets_config.dart';
import '../../core/network/json_loader.dart';
import '../models/spread_model.dart';
import 'cards_repository.dart';

class SpreadsRepository {
  SpreadsRepository({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _cacheTtl = Duration(days: 30);
  static const String _spreadsPrefix = 'spreads_';
  static const String _timestampSuffix = '_timestamp';

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

  String spreadsCacheKey(String languageCode) =>
      '$_spreadsPrefix${resolveLanguageCode(languageCode)}';

  String spreadsTimestampKey(String languageCode) =>
      '${spreadsCacheKey(languageCode)}$_timestampSuffix';

  String spreadsFileNameForLanguage(String languageCode) {
    return switch (resolveLanguageCode(languageCode)) {
      'ru' => 'spreads_ru.json',
      'kz' => 'spreads_kz.json',
      _ => 'spreads_en.json',
    };
  }

  String spreadsUrlForLanguage(String languageCode) {
    final resolved = resolveLanguageCode(languageCode);
    return '${AssetsConfig.assetsBaseUrl}/data/spreads_$resolved.json';
  }

  String resolveLanguageCode(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    return switch (normalized) {
      'ru' => 'ru',
      'kk' => 'kz',
      'kz' => 'kz',
      'en' => 'en',
      _ => 'en',
    };
  }

  Future<List<SpreadModel>> loadSpreads(String languageCode) async {
    final resolved = resolveLanguageCode(languageCode);
    if (kDebugMode) {
      debugPrint(
        '[SpreadsRepository] deviceLocale=$languageCode resolved=$resolved',
      );
    }

    try {
      return await _fetchSpreadsFromNetwork(resolved);
    } catch (error) {
      if (_isNetworkUnavailable(error)) {
        return await _loadSpreadsFromCacheFallback(resolved) ??
            _throwLoadFailure(error, cacheKey: spreadsCacheKey(resolved));
      }

      if (resolved != 'en') {
        try {
          return await _fetchSpreadsFromNetwork('en');
        } catch (fallbackError) {
          if (_isNetworkUnavailable(fallbackError)) {
            return await _loadSpreadsFromCacheFallback(resolved) ??
                _throwLoadFailure(
                  fallbackError,
                  cacheKey: spreadsCacheKey('en'),
                );
          }
          _throwLoadFailure(
            fallbackError,
            cacheKey: spreadsCacheKey('en'),
          );
        }
      }

      _throwLoadFailure(error, cacheKey: spreadsCacheKey(resolved));
    }
  }

  Future<List<SpreadModel>> loadCachedSpreads(String languageCode) async {
    final resolved = resolveLanguageCode(languageCode);
    final cached = await _loadSpreadsFromCache(resolved);
    if (cached != null) {
      return cached;
    }
    if (resolved != 'en') {
      final fallback = await _loadSpreadsFromCache('en');
      if (fallback != null) {
        return fallback;
      }
    }
    throw DataLoadException(
      'No cached spreads available',
      cacheKey: spreadsCacheKey(resolved),
    );
  }

  Future<bool> hasCachedData(String languageCode,
      {bool includeFallback = false}) async {
    final resolved = resolveLanguageCode(languageCode);
    if (await _hasCache(resolved)) {
      return true;
    }
    if (includeFallback && resolved != 'en') {
      return _hasCache('en');
    }
    return false;
  }

  Future<List<SpreadModel>> _fetchSpreadsFromNetwork(
    String languageCode,
  ) async {
    final resolved = resolveLanguageCode(languageCode);
    final cacheKey = spreadsCacheKey(resolved);
    final uri = Uri.parse(spreadsUrlForLanguage(resolved));
    _lastAttemptedUrls[cacheKey] = uri.toString();
    if (kDebugMode) {
      debugPrint('[SpreadsRepository] fetch url=$uri');
    }

    try {
      final result = await fetchJson(client: _client, uri: uri);
      _recordResponseInfo(cacheKey, result.response);
      _lastResponseRootTypes[cacheKey] = jsonRootType(result.decoded);
      final spreads = _parseSpreads(result.decoded);
      await _storeCache(cacheKey, result.raw);
      await _storeTimestamp(cacheKey, DateTime.now());
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      if (kDebugMode) {
        debugPrint('[SpreadsRepository] fetch success cacheKey=$cacheKey');
      }
      return spreads;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (error is JsonFetchException && error.response != null) {
        _recordResponseInfo(cacheKey, error.response!);
      }
      if (kDebugMode) {
        debugPrint(
          '[SpreadsRepository] fetchError url=${uri.toString()} '
          'cacheKey=$cacheKey error=${error.toString()}',
        );
      }
      rethrow;
    }
  }

  Future<List<SpreadModel>?> _loadSpreadsFromCacheFallback(
    String languageCode,
  ) async {
    final resolved = resolveLanguageCode(languageCode);
    final cached = await _loadSpreadsFromCache(resolved);
    if (cached != null) {
      return cached;
    }
    if (resolved != 'en') {
      return _loadSpreadsFromCache('en');
    }
    return null;
  }

  Future<List<SpreadModel>?> _loadSpreadsFromCache(
    String languageCode,
  ) async {
    final resolved = resolveLanguageCode(languageCode);
    final cacheKey = spreadsCacheKey(resolved);
    final entry = await _readCacheEntry(cacheKey);
    if (entry == null) {
      return null;
    }
    try {
      final parsed = parseJsonString(entry.raw);
      _lastResponseRootTypes[cacheKey] = jsonRootType(parsed.decoded);
      final spreads = _parseSpreads(parsed.decoded);
      _lastCacheTimes[cacheKey] = DateTime.now();
      if (kDebugMode) {
        final staleLabel = entry.isExpired ? 'stale' : 'fresh';
        debugPrint(
          '[SpreadsRepository] cache hit cacheKey=$cacheKey ($staleLabel)',
        );
      }
      return spreads;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SpreadsRepository] cache invalid cacheKey=$cacheKey '
          'error=${error.toString()}',
        );
      }
      return null;
    }
  }

  Future<_CacheEntry?> _readCacheEntry(String cacheKey) async {
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      final timestamp = await _readTimestamp(cacheKey);
      return _CacheEntry(
        raw: cached,
        timestamp: timestamp,
        ttl: _cacheTtl,
      );
    }
    final prefs = await _prefs();
    final raw = prefs.getString(cacheKey);
    if (raw == null) {
      return null;
    }
    _memoryCache[cacheKey] = raw;
    final timestamp = await _readTimestamp(cacheKey);
    return _CacheEntry(raw: raw, timestamp: timestamp, ttl: _cacheTtl);
  }

  Future<void> _storeCache(String cacheKey, String raw) async {
    _memoryCache[cacheKey] = raw;
    final prefs = await _prefs();
    await prefs.setString(cacheKey, raw);
  }

  Future<void> _storeTimestamp(String cacheKey, DateTime timestamp) async {
    final prefs = await _prefs();
    await prefs.setInt('${cacheKey}$_timestampSuffix', timestamp.millisecondsSinceEpoch);
  }

  Future<DateTime?> _readTimestamp(String cacheKey) async {
    final prefs = await _prefs();
    final value = prefs.getInt('${cacheKey}$_timestampSuffix');
    if (value == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<bool> _hasCache(String languageCode) async {
    final cacheKey = spreadsCacheKey(languageCode);
    if (_memoryCache.containsKey(cacheKey)) {
      return true;
    }
    final prefs = await _prefs();
    return prefs.containsKey(cacheKey);
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

  void _recordResponseInfo(String cacheKey, JsonResponseInfo response) {
    _lastStatusCodes[cacheKey] = response.statusCode;
    _lastContentTypes[cacheKey] = response.contentType;
    _lastContentLengths[cacheKey] = response.contentLengthHeader;
    _lastResponseSnippetsStart[cacheKey] = response.responseSnippetStart;
    _lastResponseSnippetsEnd[cacheKey] = response.responseSnippetEnd;
    _lastResponseStringLengths[cacheKey] = response.stringLength;
    _lastResponseByteLengths[cacheKey] = response.bytesLength;
  }

  Never _throwLoadFailure(Object error, {required String cacheKey}) {
    if (error is DataLoadException) {
      throw error;
    }
    throw DataLoadException(error.toString(), cacheKey: cacheKey);
  }

  bool _isNetworkUnavailable(Object error) {
    return error is TimeoutException ||
        error is http.ClientException ||
        error.toString().contains('SocketException');
  }

  List<SpreadModel> _parseSpreads(Object decoded) {
    if (decoded is! List) {
      throw UnexpectedStructureException(
        'Root must be a List, got ${decoded.runtimeType}',
      );
    }
    if (decoded.isEmpty) {
      throw UnexpectedStructureException('Spreads payload is empty');
    }
    final spreads = <SpreadModel>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        throw UnexpectedStructureException('Spread item must be an object');
      }
      final item = Map<String, dynamic>.from(entry as Map);
      spreads.add(_parseSpreadEntry(item));
    }
    return spreads;
  }

  SpreadModel _parseSpreadEntry(Map<String, dynamic> item) {
    final id = item['id'];
    final name = item['name'];
    final title = item['title'];
    final description = item['description'];
    final cardsCount = item['cardsCount'];
    final positions = item['positions'];

    if (id is! String || id.trim().isEmpty) {
      throw UnexpectedStructureException('Spread id must be a string');
    }
    if (name is! String || name.trim().isEmpty) {
      throw UnexpectedStructureException('Spread $id missing name');
    }
    if (title is! String || title.trim().isEmpty) {
      throw UnexpectedStructureException('Spread $id missing title');
    }
    if (description is! String || description.trim().isEmpty) {
      throw UnexpectedStructureException('Spread $id missing description');
    }
    if (cardsCount is! num) {
      throw UnexpectedStructureException('Spread $id cardsCount must be a number');
    }
    if (positions is! List || positions.isEmpty) {
      throw UnexpectedStructureException('Spread $id positions must be a list');
    }

    final resolvedPositions = <SpreadPosition>[];
    for (final position in positions) {
      if (position is! Map) {
        throw UnexpectedStructureException(
          'Spread $id position must be an object',
        );
      }
      final pos = Map<String, dynamic>.from(position as Map);
      final posId = pos['id'];
      final posTitle = pos['title'];
      final posMeaning = pos['meaning'];
      if (posId is! String || posId.trim().isEmpty) {
        throw UnexpectedStructureException('Spread $id position missing id');
      }
      if (posTitle is! String || posTitle.trim().isEmpty) {
        throw UnexpectedStructureException('Spread $id position missing title');
      }
      if (posMeaning is! String || posMeaning.trim().isEmpty) {
        throw UnexpectedStructureException('Spread $id position missing meaning');
      }
      resolvedPositions.add(
        SpreadPosition(
          id: posId,
          title: posTitle,
          meaning: posMeaning,
        ),
      );
    }

    return SpreadModel(
      id: id,
      name: name,
      title: title,
      description: description,
      positions: resolvedPositions,
      cardsCount: cardsCount.toInt(),
    );
  }
}

class _CacheEntry {
  _CacheEntry({required this.raw, required this.timestamp, required this.ttl});

  final String raw;
  final DateTime? timestamp;
  final Duration ttl;

  bool get isExpired {
    final value = timestamp;
    if (value == null) {
      return false;
    }
    return DateTime.now().difference(value) > ttl;
  }
}
