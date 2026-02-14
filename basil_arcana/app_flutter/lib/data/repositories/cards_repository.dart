import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/config/app_config.dart';
import '../../core/config/web_build_version.dart';
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
      '${_cardsPrefix}v${_cacheVersion}_${_buildVersionTag()}_${locale.languageCode}';

  String cardsFileNameForLocale(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kz.json',
      _ => 'cards_en.json',
    };
  }

  String _buildVersionTag() {
    final runtimeVersion = (AppConfig.appVersion.isNotEmpty
            ? AppConfig.appVersion
            : readWebBuildVersion())
        .trim();
    return runtimeVersion.isNotEmpty ? runtimeVersion : 'dev';
  }

  String cardsUrlForLocale(Locale locale) {
    return 'assets/data/${cardsFileNameForLocale(locale)}';
  }

  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckType deckId,
  }) async {
    final cacheKey = cardsCacheKey(locale);
    var raw = await _loadLocalCards(cacheKey: cacheKey, locale: locale);
    if (_isLegacyCardsPayload(raw)) {
      final remoteRaw = await _tryLoadRemoteCards(
        cacheKey: cacheKey,
        locale: locale,
      );
      if (remoteRaw != null) {
        raw = remoteRaw;
      }
    }
    var cards = _parseCards(raw: raw, deckId: deckId);

    // Safety fallback for newly introduced decks in older app bundles.
    // If Lenormand data is missing locally, retry from CDN once.
    final lenormandMissing = deckId == DeckType.lenormand
        ? cards.isEmpty
        : deckId == DeckType.all &&
            !cards.any((card) => card.deckId == DeckType.lenormand);
    if (lenormandMissing) {
      final remoteRaw = await _tryLoadRemoteCards(
        cacheKey: cacheKey,
        locale: locale,
      );
      if (remoteRaw != null) {
        final remoteCards = _parseCards(raw: remoteRaw, deckId: deckId);
        final remoteHasLenormand = deckId == DeckType.lenormand
            ? remoteCards.isNotEmpty
            : remoteCards.any((card) => card.deckId == DeckType.lenormand);
        if (remoteHasLenormand) {
          cards = remoteCards;
        }
      }
    }

    if (deckId == DeckType.lenormand && cards.isEmpty) {
      return _buildLenormandFallback(locale);
    }
    if (deckId == DeckType.all &&
        !cards.any((card) => card.deckId == DeckType.lenormand)) {
      return [...cards, ..._buildLenormandFallback(locale)];
    }

    return cards;
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

  Future<String?> _tryLoadRemoteCards({
    required String cacheKey,
    required Locale locale,
  }) async {
    final uri = Uri.parse(cardsUrl(locale.languageCode));
    _lastAttemptedUrls[cacheKey] = uri.toString();
    final client = http.Client();
    try {
      final response = await client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      final parsed = decodeJsonResponse(response: response, uri: uri);
      _recordRemoteResponseInfo(cacheKey, parsed.response);
      _lastResponseRootTypes[cacheKey] = jsonRootType(parsed.decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (!_isValidCardsJson(parsed.decoded) ||
          _isLegacyCardsPayload(parsed.raw)) {
        return null;
      }
      _lastFetchTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (kEnableRuntimeLogs) {
        debugPrint('[CardsRepository] remote load skipped: $error');
      }
      return null;
    } finally {
      client.close();
    }
  }

  void _recordRemoteResponseInfo(String cacheKey, JsonResponseInfo response) {
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

bool _isLegacyCardsPayload(String raw) {
  try {
    final decoded = parseJsonString(raw).decoded;
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
      return true;
    }
    var richCards = 0;
    for (final value in decoded.values) {
      if (value is! Map<String, dynamic>) {
        continue;
      }
      final detailed =
          _stringOrEmpty(value['detailedDescription']).isNotEmpty ||
              _stringOrEmpty(value['description']).isNotEmpty;
      final fact = _stringOrEmpty(value['fact']).isNotEmpty ||
          _stringOrEmpty(value['funFact']).isNotEmpty;
      final stats = value['stats'] is Map<String, dynamic> &&
          (value['stats'] as Map<String, dynamic>).isNotEmpty;
      if (detailed && fact && stats) {
        richCards++;
      }
    }
    final total = decoded.length;
    if (total < 70) {
      return true;
    }
    return (richCards / total) < 0.35;
  } catch (_) {
    return true;
  }
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
    DeckType.lenormand: buildDeckCards(lenormandCardIds),
  };

  return _getActiveDeckCards(deckId, deckRegistry);
}

Map<String, Map<String, dynamic>> _canonicalizeCardData(
  Map<String, dynamic> data,
) {
  final canonical = <String, Map<String, dynamic>>{};
  for (final entry in data.entries) {
    if (entry.value is! Map<String, dynamic>) {
      if (kEnableRuntimeLogs) {
        debugPrint(
          '[CardsRepository] skipping invalid card payload for ${entry.key}',
        );
      }
      continue;
    }
    final key = canonicalCardId(entry.key);
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
  if (normalized.startsWith('cards/') ||
      (normalized.contains('/') && normalized.endsWith('.webp'))) {
    if (deckId == DeckType.lenormand &&
        normalized.startsWith('cards/lenormand/')) {
      final corrected = _normalizeLenormandImagePath(
        normalized,
        cardId: cardId,
      );
      return '${AssetsConfig.assetsBaseUrl}/$corrected';
    }
    return '${AssetsConfig.assetsBaseUrl}/$normalized';
  }
  return cardImageUrl(cardId, deckId: deckId);
}

String _normalizeLenormandImagePath(
  String rawPath, {
  required String cardId,
}) {
  final path = rawPath.replaceFirst(RegExp(r'^/+'), '');
  final basename = path.split('/').last;
  if (basename.startsWith('ln_')) {
    return path;
  }
  final stem = lenormandImageFileStemFromCardId(cardId);
  if (stem == null) {
    return path;
  }
  return 'cards/lenormand/$stem.webp';
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

String _stringOrEmpty(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}

List<CardModel> _buildLenormandFallback(Locale locale) {
  final lang = locale.languageCode.toLowerCase();
  return _lenormandDefs.map((def) {
    final title = switch (lang) {
      'ru' => def.titleRu,
      'kk' => def.titleKk,
      _ => def.titleEn,
    };
    final keywords = switch (lang) {
      'ru' => <String>[title, 'последовательность', 'сигнал'],
      'kk' => <String>[title, 'тізбек', 'белгі'],
      _ => <String>[title, 'sequence', 'signal'],
    };
    final general = switch (lang) {
      'ru' => '$title указывает на конкретный фактор ситуации прямо сейчас.',
      'kk' => '$title дәл қазір жағдайға әсер ететін нақты факторды көрсетеді.',
      _ => '$title points to a concrete factor shaping the situation now.',
    };
    final light = switch (lang) {
      'ru' => 'В светлом проявлении помогает быстро увидеть рабочий вектор.',
      'kk' => 'Жарық қырында жұмыс істейтін бағытты жылдам көруге көмектеседі.',
      _ => 'In light, it helps you spot the workable direction quickly.',
    };
    final shadow = switch (lang) {
      'ru' => 'В тени дает поспешность или неверное чтение контекста.',
      'kk' => 'Көлеңке қырында асығыстық не контексті қате оқу байқалады.',
      _ => 'In shadow, it can produce haste or a misread of context.',
    };
    final advice = switch (lang) {
      'ru' =>
        'Сверьте карту с предыдущими: в Ленорман смысл раскрывается цепочкой.',
      'kk' =>
        'Алдыңғы карталармен бірге оқыңыз: Ленорманда мағына тізбекпен ашылады.',
      _ =>
        'Read it with previous cards: in Lenormand, meaning unfolds as a chain.',
    };
    final fact = switch (lang) {
      'ru' =>
        '$title в Ленорман читается буквально и усиливает смысл соседних карт.',
      'kk' =>
        '$title Ленорманда көбіне нақты белгі ретінде, көрші карталармен бірге оқылады.',
      _ =>
        '$title in Lenormand is read literally and sharpened by nearby cards.',
    };
    final normalizedSlug = normalizeLenormandAssetSlug(def.slug);
    final imageUrl =
        'https://basilarcana-assets.b-cdn.net/cards/lenormand/ln_${normalizedSlug}.webp';
    final videoFileName = lenormandVideoFileNameFromCardId(def.id);
    final videoUrl = videoFileName == null
        ? null
        : 'https://basilarcana-assets.b-cdn.net/video/$videoFileName';

    return CardModel(
      id: def.id,
      deckId: DeckType.lenormand,
      name: title,
      keywords: keywords,
      meaning: CardMeaning(
        general: general,
        light: light,
        shadow: shadow,
        advice: advice,
      ),
      detailedDescription: '$general $light $shadow $advice',
      funFact: fact,
      stats: _lenormandFallbackStats(def.number),
      imageUrl: imageUrl,
      videoUrl: videoUrl,
    );
  }).toList(growable: false);
}

CardStats _lenormandFallbackStats(int cardNumber) {
  final base = (cardNumber * 7) % 21;
  return CardStats(
    luck: 45 + base,
    power: 42 + ((base + 5) % 21),
    love: 44 + ((base + 10) % 21),
    clarity: 46 + ((base + 15) % 21),
  );
}

class _LenormandDef {
  const _LenormandDef({
    required this.number,
    required this.slug,
    required this.titleEn,
    required this.titleRu,
    required this.titleKk,
  });

  final int number;
  final String slug;
  final String titleEn;
  final String titleRu;
  final String titleKk;

  String get id => 'lenormand_${number.toString().padLeft(2, '0')}_$slug';
}

const List<_LenormandDef> _lenormandDefs = [
  _LenormandDef(
      number: 1,
      slug: 'rider',
      titleEn: 'Rider',
      titleRu: 'Всадник',
      titleKk: 'Салт аттылы'),
  _LenormandDef(
      number: 2,
      slug: 'clover',
      titleEn: 'Clover',
      titleRu: 'Клевер',
      titleKk: 'Беде'),
  _LenormandDef(
      number: 3,
      slug: 'ship',
      titleEn: 'Ship',
      titleRu: 'Корабль',
      titleKk: 'Кеме'),
  _LenormandDef(
      number: 4,
      slug: 'house',
      titleEn: 'House',
      titleRu: 'Дом',
      titleKk: 'Үй'),
  _LenormandDef(
      number: 5,
      slug: 'tree',
      titleEn: 'Tree',
      titleRu: 'Дерево',
      titleKk: 'Ағаш'),
  _LenormandDef(
      number: 6,
      slug: 'clouds',
      titleEn: 'Clouds',
      titleRu: 'Тучи',
      titleKk: 'Бұлттар'),
  _LenormandDef(
      number: 7,
      slug: 'snake',
      titleEn: 'Snake',
      titleRu: 'Змея',
      titleKk: 'Жылан'),
  _LenormandDef(
      number: 8,
      slug: 'coffin',
      titleEn: 'Coffin',
      titleRu: 'Гроб',
      titleKk: 'Табыт'),
  _LenormandDef(
      number: 9,
      slug: 'bouquet',
      titleEn: 'Bouquet',
      titleRu: 'Букет',
      titleKk: 'Гүл шоғы'),
  _LenormandDef(
      number: 10,
      slug: 'scythe',
      titleEn: 'Scythe',
      titleRu: 'Коса',
      titleKk: 'Орақ'),
  _LenormandDef(
      number: 11,
      slug: 'whip',
      titleEn: 'Whip',
      titleRu: 'Метла и Плеть',
      titleKk: 'Қамшы'),
  _LenormandDef(
      number: 12,
      slug: 'birds',
      titleEn: 'Birds',
      titleRu: 'Птицы',
      titleKk: 'Құстар'),
  _LenormandDef(
      number: 13,
      slug: 'child',
      titleEn: 'Child',
      titleRu: 'Ребенок',
      titleKk: 'Бала'),
  _LenormandDef(
      number: 14,
      slug: 'fox',
      titleEn: 'Fox',
      titleRu: 'Лиса',
      titleKk: 'Түлкі'),
  _LenormandDef(
      number: 15,
      slug: 'bear',
      titleEn: 'Bear',
      titleRu: 'Медведь',
      titleKk: 'Аю'),
  _LenormandDef(
      number: 16,
      slug: 'stars',
      titleEn: 'Stars',
      titleRu: 'Звезды',
      titleKk: 'Жұлдыздар'),
  _LenormandDef(
      number: 17,
      slug: 'stork',
      titleEn: 'Stork',
      titleRu: 'Аист',
      titleKk: 'Ләйлек'),
  _LenormandDef(
      number: 18,
      slug: 'dog',
      titleEn: 'Dog',
      titleRu: 'Собака',
      titleKk: 'Ит'),
  _LenormandDef(
      number: 19,
      slug: 'tower',
      titleEn: 'Tower',
      titleRu: 'Башня',
      titleKk: 'Мұнара'),
  _LenormandDef(
      number: 20,
      slug: 'garden',
      titleEn: 'Garden',
      titleRu: 'Сад',
      titleKk: 'Бақ'),
  _LenormandDef(
      number: 21,
      slug: 'mountain',
      titleEn: 'Mountain',
      titleRu: 'Гора',
      titleKk: 'Тау'),
  _LenormandDef(
      number: 22,
      slug: 'crossroads',
      titleEn: 'Crossroads',
      titleRu: 'Развилка',
      titleKk: 'Жол айырығы'),
  _LenormandDef(
      number: 23,
      slug: 'mice',
      titleEn: 'Mice',
      titleRu: 'Мыши',
      titleKk: 'Тышқандар'),
  _LenormandDef(
      number: 24,
      slug: 'heart',
      titleEn: 'Heart',
      titleRu: 'Сердце',
      titleKk: 'Жүрек'),
  _LenormandDef(
      number: 25,
      slug: 'ring',
      titleEn: 'Ring',
      titleRu: 'Кольцо',
      titleKk: 'Сақина'),
  _LenormandDef(
      number: 26,
      slug: 'book',
      titleEn: 'Book',
      titleRu: 'Книга',
      titleKk: 'Кітап'),
  _LenormandDef(
      number: 27,
      slug: 'letter',
      titleEn: 'Letter',
      titleRu: 'Письмо',
      titleKk: 'Хат'),
  _LenormandDef(
      number: 28,
      slug: 'man',
      titleEn: 'Man',
      titleRu: 'Мужчина',
      titleKk: 'Ер адам'),
  _LenormandDef(
      number: 29,
      slug: 'woman',
      titleEn: 'Woman',
      titleRu: 'Женщина',
      titleKk: 'Әйел'),
  _LenormandDef(
      number: 30,
      slug: 'lily',
      titleEn: 'Lily',
      titleRu: 'Лилии',
      titleKk: 'Лалагүл'),
  _LenormandDef(
      number: 31,
      slug: 'sun',
      titleEn: 'Sun',
      titleRu: 'Солнце',
      titleKk: 'Күн'),
  _LenormandDef(
      number: 32,
      slug: 'moon',
      titleEn: 'Moon',
      titleRu: 'Луна',
      titleKk: 'Ай'),
  _LenormandDef(
      number: 33,
      slug: 'key',
      titleEn: 'Key',
      titleRu: 'Ключ',
      titleKk: 'Кілт'),
  _LenormandDef(
      number: 34,
      slug: 'fish',
      titleEn: 'Fish',
      titleRu: 'Рыбы',
      titleKk: 'Балықтар'),
  _LenormandDef(
      number: 35,
      slug: 'anchor',
      titleEn: 'Anchor',
      titleRu: 'Якорь',
      titleKk: 'Зәкір'),
  _LenormandDef(
      number: 36,
      slug: 'cross',
      titleEn: 'Cross',
      titleRu: 'Крест',
      titleKk: 'Айқыш'),
];
