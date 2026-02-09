import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/network/json_loader.dart';
import '../../core/config/diagnostics.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';

class CardsRepository {
  CardsRepository();

  static const int _cacheVersion = 4;
  static const String _cardsPrefix = 'cdn_cards_';
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
      '${_cardsPrefix}v${_cacheVersion}_${locale.languageCode}';

  String cardsFileNameForLocale(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kz.json',
      _ => 'cards_en.json',
    };
  }

  String cardsUrlForLocale(Locale locale) {
    return 'assets/data/${cardsFileNameForLocale(locale)}';
  }

  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckType deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    final raw = await _loadLocalCards(cacheKey: cacheKey, locale: locale);
    return _parseCards(raw: raw, deckId: deckId);
  }

  Future<String> _loadLocalCards({
    required String cacheKey,
    required Locale locale,
  }) async {
    final assetPath = 'assets/data/${cardsFileNameForLocale(locale)}';
    _lastAttemptedUrls[cacheKey] = assetPath;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final parsed = parseJsonString(raw);
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (rootType != 'Map' || !_isValidCardsJson(parsed.decoded)) {
        if (kEnableRuntimeLogs) {
          debugPrint(
            '[CardsRepository] local schemaMismatch cacheKey=$cacheKey rootType=$rootType',
          );
        }
        _lastError = 'Cards data failed schema validation';
        throw CardsLoadException(_lastError!, cacheKey: cacheKey);
      }
      _recordLocalResponseInfo(cacheKey, parsed.raw);
      _lastCacheTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (kEnableDevDiagnostics) {
        logDevFailure(buildDevFailureInfo(FailedStage.cardsLocalLoad, error));
      }
      if (kEnableRuntimeLogs) {
        debugPrint('[CardsRepository] local load failed: $error');
      }
      throw CardsLoadException(
        'Failed to load cards',
        cacheKey: cacheKey,
      );
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

String _snippetStart(String body) {
  if (body.isEmpty) {
    return '';
  }
  return body.length <= 200 ? body : body.substring(0, 200);
}

String _snippetEnd(String body) {
  if (body.isEmpty) {
    return '';
  }
  if (body.length <= 200) {
    return body;
  }
  return body.substring(body.length - 200);
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
    if (entry.key is! String) {
      if (kEnableRuntimeLogs) {
        debugPrint(
          '[CardsRepository] skipping non-string card key: ${entry.key}',
        );
      }
      continue;
    }
    if (entry.value is! Map<String, dynamic>) {
      if (kEnableRuntimeLogs) {
        debugPrint(
          '[CardsRepository] skipping invalid card payload for ${entry.key}',
        );
      }
      continue;
    }
    final key = canonicalCardId(entry.key as String);
    canonical[key] = Map<String, dynamic>.from(entry.value as Map);
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
