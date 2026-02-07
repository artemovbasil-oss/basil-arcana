import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/network/json_loader.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';

class CardsRepository {
  CardsRepository();

  static const String _cardsPrefix = 'cdn_cards_';
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
    return cardsUrl(locale.languageCode);
  }

  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckType deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadBundledOnly(cacheKey: cacheKey);
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

  Future<String> _loadBundledOnly({required String cacheKey}) async {
    _lastAttemptedUrls[cacheKey] = _bundledAssetPath(cacheKey);
    final bundled = await _loadBundledCards(cacheKey, _isValidCardsJson);
    if (bundled != null) {
      return bundled;
    }
    final cached = await _readCache(cacheKey);
    if (cached != null) {
      final parsed = parseJsonString(cached);
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (rootType == 'Map' && _isValidCardsJson(parsed.decoded)) {
        _lastCacheTimes[cacheKey] = DateTime.now();
        return parsed.raw;
      }
    }
    _lastError = 'Bundled cards data is missing or invalid';
    throw CardsLoadException(
      'Bundled cards data is missing or invalid',
      cacheKey: cacheKey,
    );
  }

  Future<String?> _loadBundledCards(
    String cacheKey,
    bool Function(Object?) validator,
  ) async {
    final asset = _bundledAssetPath(cacheKey);
    try {
      final bundled = await rootBundle.loadString(asset);
      final parsed = parseJsonString(bundled);
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (rootType == 'Map' && validator(parsed.decoded)) {
        await _storeCache(cacheKey, parsed.raw);
        _lastCacheTimes[cacheKey] = DateTime.now();
        _lastError = null;
        return parsed.raw;
      }
    } on FlutterError {
      return null;
    }
    return null;
  }

  String _bundledAssetPath(String cacheKey) {
    return cacheKey == '${_cardsPrefix}ru'
        ? 'assets/data/cards_ru.json'
        : cacheKey == '${_cardsPrefix}kk'
            ? 'assets/data/cards_kz.json'
            : 'assets/data/cards_en.json';
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
  if (decoded is! Map<String, dynamic>) {
    return const [];
  }
  final canonicalData = _canonicalizeCardData(decoded);

  List<CardModel> buildDeckCards(List<String> ids) {
    return ids.where(canonicalData.containsKey).map((id) {
      final card = CardModel.fromLocalizedEntry(
        id,
        canonicalData[id] as Map<String, dynamic>,
      );
      final resolvedImageUrl = _resolveImageUrl(
        card.imageUrl,
        card.id,
        card.deckId,
      );
      return resolvedImageUrl == card.imageUrl
          ? card
          : card.copyWith(imageUrl: resolvedImageUrl);
    }).toList();
  }

  final deckRegistry = <DeckType, List<CardModel>>{
    DeckType.major: buildDeckCards(majorCardIds),
    DeckType.wands: buildDeckCards(wandsCardIds),
    DeckType.swords: buildDeckCards(swordsCardIds),
    DeckType.pentacles: buildDeckCards(pentaclesCardIds),
    DeckType.cups: buildDeckCards(cupsCardIds),
  };

  return _getActiveDeckCards(deckId, deckRegistry);
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

List<CardModel> _getActiveDeckCards(
  DeckType? selectedDeckType,
  Map<DeckType, List<CardModel>> deckRegistry,
) {
  if (selectedDeckType == null || selectedDeckType == DeckType.all) {
    return deckRegistry.values.expand((cards) => cards).toList();
  }
  return deckRegistry[selectedDeckType] ?? const [];
}
