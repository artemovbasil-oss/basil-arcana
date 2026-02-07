import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/network/json_loader.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';

class CardLibraryRepository {
  CardLibraryRepository({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _cacheTtl = Duration(days: 30);
  static const String _cardsPrefix = 'cards_';
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

  String cardsCacheKey(String languageCode) =>
      '$_cardsPrefix${resolveLanguageCode(languageCode)}';

  String cardsTimestampKey(String languageCode) =>
      '${cardsCacheKey(languageCode)}$_timestampSuffix';

  String cardsFileNameForLanguage(String languageCode) {
    return switch (resolveLanguageCode(languageCode)) {
      'ru' => 'cards_ru.json',
      'kz' => 'cards_kz.json',
      _ => 'cards_en.json',
    };
  }

  String cardsUrlForLanguage(String languageCode) {
    final resolved = resolveLanguageCode(languageCode);
    return '${AssetsConfig.assetsBaseUrl}/data/cards_$resolved.json';
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

  Future<List<CardModel>> loadCards(
    String languageCode, {
    required DeckType deckId,
  }) async {
    final resolved = resolveLanguageCode(languageCode);
    if (kDebugMode) {
      debugPrint(
        '[CardLibraryRepository] deviceLocale=$languageCode resolved=$resolved',
      );
    }

    try {
      return await _fetchCardsFromNetwork(resolved, deckId: deckId);
    } catch (error) {
      if (_isNetworkUnavailable(error)) {
        return await _loadCardsFromCacheFallback(resolved, deckId: deckId) ??
            _throwLoadFailure(error, cacheKey: cardsCacheKey(resolved));
      }

      if (resolved != 'en') {
        try {
          return await _fetchCardsFromNetwork('en', deckId: deckId);
        } catch (fallbackError) {
          if (_isNetworkUnavailable(fallbackError)) {
            return await _loadCardsFromCacheFallback(resolved, deckId: deckId) ??
                _throwLoadFailure(
                  fallbackError,
                  cacheKey: cardsCacheKey('en'),
                );
          }
          _throwLoadFailure(
            fallbackError,
            cacheKey: cardsCacheKey('en'),
          );
        }
      }

      _throwLoadFailure(error, cacheKey: cardsCacheKey(resolved));
    }
  }

  Future<List<CardModel>> loadCachedCards(
    String languageCode, {
    required DeckType deckId,
  }) async {
    final resolved = resolveLanguageCode(languageCode);
    final cached = await _loadCardsFromCache(resolved, deckId: deckId);
    if (cached != null) {
      return cached;
    }
    if (resolved != 'en') {
      final fallback = await _loadCardsFromCache('en', deckId: deckId);
      if (fallback != null) {
        return fallback;
      }
    }
    throw DataLoadException(
      'No cached cards available',
      cacheKey: cardsCacheKey(resolved),
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

  Future<List<CardModel>> _fetchCardsFromNetwork(
    String languageCode, {
    required DeckType deckId,
  }) async {
    final resolved = resolveLanguageCode(languageCode);
    final cacheKey = cardsCacheKey(resolved);
    final uri = Uri.parse(cardsUrlForLanguage(resolved));
    _lastAttemptedUrls[cacheKey] = uri.toString();
    if (kDebugMode) {
      debugPrint('[CardLibraryRepository] fetch url=$uri');
    }

    try {
      final result = await fetchJson(client: _client, uri: uri);
      _recordResponseInfo(cacheKey, result.response);
      _lastResponseRootTypes[cacheKey] = jsonRootType(result.decoded);
      final cards = _parseCards(result.decoded, deckId: deckId);
      await _storeCache(cacheKey, result.raw);
      await _storeTimestamp(cacheKey, DateTime.now());
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      if (kDebugMode) {
        debugPrint('[CardLibraryRepository] fetch success cacheKey=$cacheKey');
      }
      return cards;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (error is JsonFetchException && error.response != null) {
        _recordResponseInfo(cacheKey, error.response!);
      }
      if (kDebugMode) {
        debugPrint(
          '[CardLibraryRepository] fetchError url=${uri.toString()} '
          'cacheKey=$cacheKey error=${error.toString()}',
        );
      }
      rethrow;
    }
  }

  Future<List<CardModel>?> _loadCardsFromCacheFallback(
    String languageCode, {
    required DeckType deckId,
  }) async {
    final resolved = resolveLanguageCode(languageCode);
    final cached = await _loadCardsFromCache(resolved, deckId: deckId);
    if (cached != null) {
      return cached;
    }
    if (resolved != 'en') {
      return _loadCardsFromCache('en', deckId: deckId);
    }
    return null;
  }

  Future<List<CardModel>?> _loadCardsFromCache(
    String languageCode, {
    required DeckType deckId,
  }) async {
    final resolved = resolveLanguageCode(languageCode);
    final cacheKey = cardsCacheKey(resolved);
    final entry = await _readCacheEntry(cacheKey);
    if (entry == null) {
      return null;
    }
    try {
      final parsed = parseJsonString(entry.raw);
      _lastResponseRootTypes[cacheKey] = jsonRootType(parsed.decoded);
      final cards = _parseCards(parsed.decoded, deckId: deckId);
      _lastCacheTimes[cacheKey] = DateTime.now();
      if (kDebugMode) {
        final staleLabel = entry.isExpired ? 'stale' : 'fresh';
        debugPrint(
          '[CardLibraryRepository] cache hit cacheKey=$cacheKey ($staleLabel)',
        );
      }
      return cards;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[CardLibraryRepository] cache invalid cacheKey=$cacheKey '
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
    final cacheKey = cardsCacheKey(languageCode);
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

  List<CardModel> _parseCards(Object decoded, {required DeckType deckId}) {
    if (decoded is! Map) {
      throw UnexpectedStructureException(
        'Root must be a Map, got ${decoded.runtimeType}',
      );
    }
    if (decoded.isEmpty) {
      throw UnexpectedStructureException('Cards payload is empty');
    }

    final deckRegistry = <DeckType, List<CardModel>>{
      DeckType.major: [],
      DeckType.wands: [],
      DeckType.swords: [],
      DeckType.pentacles: [],
      DeckType.cups: [],
    };

    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw UnexpectedStructureException('Card id must be a string');
      }
      if (entry.value is! Map) {
        throw UnexpectedStructureException(
          'Card ${entry.key} must be an object',
        );
      }
      final cardId = canonicalCardId(entry.key as String);
      final payload = Map<String, dynamic>.from(entry.value as Map);
      final card = _parseCardEntry(cardId, payload);
      final deckList = deckRegistry[card.deckId];
      if (deckList != null) {
        deckList.add(card);
      }
    }

    _sortDeckCards(deckRegistry[DeckType.major] ?? const [], majorCardIds);
    _sortDeckCards(deckRegistry[DeckType.wands] ?? const [], wandsCardIds);
    _sortDeckCards(deckRegistry[DeckType.swords] ?? const [], swordsCardIds);
    _sortDeckCards(deckRegistry[DeckType.pentacles] ?? const [], pentaclesCardIds);
    _sortDeckCards(deckRegistry[DeckType.cups] ?? const [], cupsCardIds);

    return _getActiveDeckCards(deckId, deckRegistry);
  }

  CardModel _parseCardEntry(String cardId, Map<String, dynamic> payload) {
    final title = payload['title'];
    if (title is! String || title.trim().isEmpty) {
      throw UnexpectedStructureException('Card $cardId missing title');
    }

    final keywords = payload['keywords'];
    if (keywords is! List) {
      throw UnexpectedStructureException('Card $cardId keywords must be a list');
    }
    final keywordList = <String>[];
    for (final item in keywords) {
      if (item is! String) {
        throw UnexpectedStructureException(
          'Card $cardId keywords must be strings',
        );
      }
      keywordList.add(item);
    }

    final meaning = payload['meaning'];
    if (meaning is! Map) {
      throw UnexpectedStructureException(
        'Card $cardId meaning must be an object',
      );
    }
    final meaningMap = Map<String, dynamic>.from(meaning as Map);
    final general = meaningMap['general'];
    final detailed = meaningMap['detailed'];
    if (general is! String || general.trim().isEmpty) {
      throw UnexpectedStructureException(
        'Card $cardId meaning.general must be a string',
      );
    }
    if (detailed is! String || detailed.trim().isEmpty) {
      throw UnexpectedStructureException(
        'Card $cardId meaning.detailed must be a string',
      );
    }

    final fact = payload['fact'];
    if (fact is! String || fact.trim().isEmpty) {
      throw UnexpectedStructureException('Card $cardId missing fact');
    }

    final stats = payload['stats'];
    if (stats is! Map) {
      throw UnexpectedStructureException('Card $cardId stats must be an object');
    }
    final statsMap = Map<String, dynamic>.from(stats as Map);
    final cardStats = CardStats(
      luck: _parseStat(statsMap['luck'], 'luck', cardId),
      power: _parseStat(statsMap['power'], 'power', cardId),
      love: _parseStat(statsMap['love'], 'love', cardId),
      clarity: _parseStat(statsMap['clarity'], 'clarity', cardId),
    );

    final deckId = _deckIdFromCardId(cardId);
    final imageUrl = _resolveImageUrl(payload['imageUrl'], cardId, deckId);

    return CardModel(
      id: cardId,
      deckId: deckId,
      name: title,
      keywords: keywordList,
      meaning: CardMeaning.fromGeneralMeaning(general),
      detailedDescription: detailed,
      funFact: fact,
      stats: cardStats,
      videoFileName: payload['video'] is String ? payload['video'] as String : null,
      imageUrl: imageUrl,
      videoUrl: payload['videoUrl'] as String?,
    );
  }

  int _parseStat(Object? value, String field, String cardId) {
    if (value is num) {
      return value.toInt();
    }
    throw UnexpectedStructureException(
      'Card $cardId stats.$field must be a number',
    );
  }

  String _resolveImageUrl(Object? rawUrl, String cardId, DeckType deckId) {
    if (rawUrl is! String) {
      return cardImageUrl(cardId, deckId: deckId);
    }
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return cardImageUrl(cardId, deckId: deckId);
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return '${AssetsConfig.assetsBaseUrl}/$normalized';
  }

  DeckType _deckIdFromCardId(String id) {
    if (id.startsWith('wands_')) {
      return DeckType.wands;
    }
    if (id.startsWith('swords_')) {
      return DeckType.swords;
    }
    if (id.startsWith('pentacles_')) {
      return DeckType.pentacles;
    }
    if (id.startsWith('cups_')) {
      return DeckType.cups;
    }
    return DeckType.major;
  }

  void _sortDeckCards(List<CardModel> cards, List<String> order) {
    if (cards.isEmpty) {
      return;
    }
    final orderMap = <String, int>{
      for (var i = 0; i < order.length; i++) canonicalCardId(order[i]): i,
    };
    cards.sort((a, b) {
      final aIndex = orderMap[a.id] ?? order.length;
      final bIndex = orderMap[b.id] ?? order.length;
      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }
      return a.id.compareTo(b.id);
    });
  }

  List<CardModel> _getActiveDeckCards(
    DeckType? selectedDeckType,
    Map<DeckType, List<CardModel>> deckRegistry,
  ) {
    if (selectedDeckType == null || selectedDeckType == DeckType.all) {
      return deckRegistry.values.expand((cards) => cards).toList();
    }
    return deckRegistry[selectedDeckType] ?? const [];
  }
}

class DataLoadException implements Exception {
  DataLoadException(this.message, {this.cacheKey});

  final String message;
  final String? cacheKey;

  @override
  String toString() => message;
}

class UnexpectedStructureException implements Exception {
  UnexpectedStructureException(this.message);

  final String message;

  @override
  String toString() => message;
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
