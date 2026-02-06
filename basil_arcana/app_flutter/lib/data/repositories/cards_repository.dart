import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/network/json_loader.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';

class CardsRepository {
  CardsRepository({http.Client? client}) : _client = client ?? http.Client();

  static const String _cardsPrefix = 'cdn_cards_';
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

  String cardsCacheKey(Locale locale) =>
      '$_cardsPrefix${locale.languageCode}';

  String cardsFileNameForLocale(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kz.json',
      _ => 'cards_en.json',
    };
  }

  String cardsUrlForLocale(Locale locale) {
    final normalized = locale.languageCode.trim().toLowerCase();
    final lang = switch (normalized) {
      'ru' => 'ru',
      'kk' => 'kz',
      'kz' => 'kz',
      _ => 'en',
    };
    return '${AssetsConfig.assetsBaseUrl}/data/cards_$lang.json';
  }

  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckType deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadJsonWithFallback(
      uri: Uri.parse(cardsUrlForLocale(locale)),
      cacheKey: cacheKey,
      validator: _isValidCardsJson,
      expectedRootTypes: {'Map'},
    );
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<List<CardModel>> loadCachedCards({
    required Locale locale,
    required DeckType deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _readCache(cacheKey);
    if (raw == null) {
      throw CardsLoadException('No cached cards available', cacheKey: cacheKey);
    }
    final parsed = parseJsonString(raw);
    final rootType = jsonRootType(parsed.decoded);
    _lastResponseRootTypes[cacheKey] = rootType;
    if (rootType != 'Map' || !_isValidCardsJson(parsed.decoded)) {
      throw CardsLoadException('Cached cards are invalid', cacheKey: cacheKey);
    }
    _lastCacheTimes[cacheKey] = DateTime.now();
    return _parseCards(raw: parsed.raw, deckId: deckId);
  }

  Future<bool> hasCachedData(String cacheKey) async {
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
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
        throw CardsLoadException(
          'Unexpected JSON root type: $rootType (expected $expected)',
          cacheKey: cacheKey,
        );
      }
      if (!validator(result.decoded)) {
        throw CardsLoadException(
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
          '[CardsRepository] fetchError url=${uri.toString()} '
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
      if (error is CardsLoadException) {
        throw error;
      }
      throw CardsLoadException(error.toString(), cacheKey: cacheKey);
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

class CardsLoadException implements Exception {
  CardsLoadException(this.message, {this.cacheKey});

  final String message;
  final String? cacheKey;

  @override
  String toString() => message;
}

bool _isValidCardsJson(Object? payload) {
  if (payload is! Map<String, dynamic> || payload.isEmpty) {
    return false;
  }
  return payload.entries.every((entry) {
    final value = entry.value;
    if (value is! Map<String, dynamic>) {
      return false;
    }
    final card = Map<String, dynamic>.from(value);
    card['id'] ??= entry.key;
    return _isValidCardEntry(card);
  });
}

bool _isValidCardEntry(Map<String, dynamic> card) {
  final hasTitle = card.containsKey('title') || card.containsKey('name');
  final hasMeaning = card.containsKey('meaning') ||
      card.containsKey('summary') ||
      card.containsKey('generalMeaning');
  return card.containsKey('id') && hasTitle && hasMeaning;
}

List<CardModel> _parseCards({required String raw, required DeckType deckId}) {
  final decoded = parseJsonString(raw).decoded;
  final entries = <Map<String, dynamic>>[];
  if (decoded is Map<String, dynamic>) {
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final card = Map<String, dynamic>.from(value);
        card['id'] ??= entry.key;
        entries.add(card);
      }
    }
  }

  final deckRegistry = <DeckType, List<CardModel>>{
    DeckType.major: [],
    DeckType.wands: [],
    DeckType.swords: [],
    DeckType.pentacles: [],
    DeckType.cups: [],
  };

  for (final entry in entries) {
    final card = CardModel.fromCdnEntry(entry);
    final resolvedImageUrl = _resolveImageUrl(
      card.imageUrl,
      card.id,
      card.deckId,
    );
    final resolvedCard = resolvedImageUrl == card.imageUrl
        ? card
        : card.copyWith(imageUrl: resolvedImageUrl);
    final deckList = deckRegistry[card.deckId];
    if (deckList != null) {
      deckList.add(resolvedCard);
    }
  }

  _sortDeckCards(deckRegistry[DeckType.major] ?? const [], majorCardIds);
  _sortDeckCards(deckRegistry[DeckType.wands] ?? const [], wandsCardIds);
  _sortDeckCards(deckRegistry[DeckType.swords] ?? const [], swordsCardIds);
  _sortDeckCards(deckRegistry[DeckType.pentacles] ?? const [], pentaclesCardIds);
  _sortDeckCards(deckRegistry[DeckType.cups] ?? const [], cupsCardIds);

  return _getActiveDeckCards(deckId, deckRegistry);
}

String _resolveImageUrl(String rawUrl, String cardId, DeckType deckId) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    return cardImageUrl(cardId, deckId: deckId);
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
  if (normalized.startsWith('cards/')) {
    return '${AssetsConfig.assetsBaseUrl}/$normalized';
  }
  return '${AssetsConfig.assetsBaseUrl}/$normalized';
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
