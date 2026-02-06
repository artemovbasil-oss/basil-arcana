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

class CardsRepository {
  CardsRepository({http.Client? client}) : _client = client ?? http.Client();

  static const String _cardsPrefix = 'cdn_cards_';
  final http.Client _client;
  final Map<String, String> _memoryCache = {};
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, DateTime> _lastCacheTimes = {};
  final Map<String, String> _lastAttemptedUrls = {};
  final Map<String, int> _lastStatusCodes = {};
  final Map<String, String> _lastResponseBodies = {};
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
  UnmodifiableMapView<String, String> get lastResponseBodies =>
      UnmodifiableMapView(_lastResponseBodies);
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
    required DeckId deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadJsonWithFallback(
      uri: Uri.parse(cardsUrlForLocale(locale)),
      cacheKey: cacheKey,
      validator: _isValidCardsJson,
    );
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<List<CardModel>> loadCachedCards({
    required Locale locale,
    required DeckId deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _readCache(cacheKey);
    if (raw == null) {
      throw CardsLoadException('No cached cards available', cacheKey: cacheKey);
    }
    if (!_isValidCardsJson(jsonDecode(raw))) {
      throw CardsLoadException('Cached cards are invalid', cacheKey: cacheKey);
    }
    _lastCacheTimes[cacheKey] = DateTime.now();
    return _parseCards(raw: raw, deckId: deckId);
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
  }) async {
    _lastAttemptedUrls[cacheKey] = uri.toString();
    try {
      final response = await _client.get(uri);
      _lastStatusCodes[cacheKey] = response.statusCode;
      _lastResponseBodies[cacheKey] = _responseSnippet(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CardsLoadException(
          'HTTP ${response.statusCode} for ${uri.toString()}',
          cacheKey: cacheKey,
        );
      }
      try {
        if (!validator(jsonDecode(response.body))) {
          throw CardsLoadException('Invalid JSON payload', cacheKey: cacheKey);
        }
      } on FormatException catch (error) {
        throw CardsLoadException(
          'Invalid JSON payload: ${error.message}',
          cacheKey: cacheKey,
        );
      }
      await _storeCache(cacheKey, response.body);
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return response.body;
    } catch (error) {
      _lastError = error.toString();
      if (kDebugMode) {
        debugPrint(
          '[CardsRepository] fetchError url=${uri.toString()} '
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
}

class CardsLoadException implements Exception {
  CardsLoadException(this.message, {this.cacheKey});

  final String message;
  final String? cacheKey;

  @override
  String toString() => message;
}

bool _isValidCardsJson(Object? payload) {
  if (payload is List<dynamic>) {
    return payload.isNotEmpty &&
        payload.whereType<Map<String, dynamic>>().every(_isValidCardEntry);
  }
  if (payload is Map<String, dynamic>) {
    if (payload.isEmpty) {
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
  return false;
}

bool _isValidCardEntry(Map<String, dynamic> card) {
  return card.containsKey('id') &&
      card.containsKey('deck') &&
      (card.containsKey('title') || card.containsKey('name'));
}

List<CardModel> _parseCards({required String raw, required DeckId deckId}) {
  final decoded = jsonDecode(raw);
  final entries = <Map<String, dynamic>>[];
  if (decoded is List<dynamic>) {
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        entries.add(item);
      }
    }
  } else if (decoded is Map<String, dynamic>) {
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final card = Map<String, dynamic>.from(value);
        card['id'] ??= entry.key;
        entries.add(card);
      }
    }
  }

  final deckRegistry = <DeckId, List<CardModel>>{
    DeckId.major: [],
    DeckId.wands: [],
    DeckId.swords: [],
    DeckId.pentacles: [],
    DeckId.cups: [],
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

  _sortDeckCards(deckRegistry[DeckId.major] ?? const [], majorCardIds);
  _sortDeckCards(deckRegistry[DeckId.wands] ?? const [], wandsCardIds);
  _sortDeckCards(deckRegistry[DeckId.swords] ?? const [], swordsCardIds);
  _sortDeckCards(deckRegistry[DeckId.pentacles] ?? const [], pentaclesCardIds);
  _sortDeckCards(deckRegistry[DeckId.cups] ?? const [], cupsCardIds);

  return _getActiveDeckCards(deckId, deckRegistry);
}

String _responseSnippet(String body) {
  if (body.isEmpty) {
    return '';
  }
  return body.length <= 200 ? body : body.substring(0, 200);
}

String _resolveImageUrl(String rawUrl, String cardId, DeckId deckId) {
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
  DeckId? selectedDeckId,
  Map<DeckId, List<CardModel>> deckRegistry,
) {
  if (selectedDeckId == null || selectedDeckId == DeckId.all) {
    return deckRegistry.values.expand((cards) => cards).toList();
  }
  return deckRegistry[selectedDeckId] ?? const [];
}
