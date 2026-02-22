import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const int _cacheVersion = 5;
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
    final raw = await _loadLocalCards(cacheKey: cacheKey, locale: locale);
    var cards = _parseCards(raw: raw, deckId: deckId);

    final shouldCompleteCrowley = deckId == DeckType.crowley ||
        (deckId == DeckType.all &&
            _countCrowleyCards(cards) > 0 &&
            _countCrowleyCards(cards) < 78);
    if (shouldCompleteCrowley && _countCrowleyCards(cards) < 78) {
      cards = _completeCrowleyCards(cards, locale: locale, deckId: deckId);
    }

    if (deckId == DeckType.lenormand && cards.isEmpty) {
      return _buildLenormandFallback(locale);
    }
    if (deckId == DeckType.crowley && cards.isEmpty) {
      return _buildCrowleyFallback(locale);
    }
    if (deckId == DeckType.all &&
        !cards.any((card) => card.deckId == DeckType.lenormand)) {
      return [...cards, ..._buildLenormandFallback(locale)];
    }
    if (deckId == DeckType.all &&
        !cards.any((card) => card.deckId == DeckType.crowley)) {
      return [...cards, ..._buildCrowleyFallback(locale)];
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

int _countCrowleyCards(List<CardModel> cards) {
  return cards.where((card) => card.deckId == DeckType.crowley).length;
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
    DeckType.crowley: buildDeckCards(crowleyCardIds),
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
      description: general,
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

List<CardModel> _buildCrowleyFallback(Locale locale) {
  final lang = locale.languageCode.toLowerCase();
  final majors = _crowleyDefs.map((def) {
    final title = switch (lang) {
      'ru' => def.titleRu,
      'kk' => def.titleKk,
      _ => def.titleEn,
    };
    final keywords = switch (lang) {
      'ru' => <String>[title, 'Кроули', 'архетип'],
      'kk' => <String>[title, 'Кроули', 'архетип'],
      _ => <String>[title, 'Crowley', 'archetype'],
    };
    final general = switch (lang) {
      'ru' =>
        '$title показывает ключевой архетип момента и усиливает фокус на внутреннем выборе.',
      'kk' =>
        '$title сәттің негізгі архетипін көрсетіп, ішкі таңдауға назарды күшейтеді.',
      _ =>
        '$title reveals the key archetype of the moment and sharpens your inner choice.',
    };
    final light = switch (lang) {
      'ru' =>
        'В светлом проявлении помогает действовать зрелее и точнее по выбранному курсу.',
      'kk' =>
        'Жарық қырында таңдалған бағыт бойынша дәлірек әрі жетілген әрекет етуге көмектеседі.',
      _ =>
        'In light, it supports mature, precise action aligned with your chosen direction.',
    };
    final shadow = switch (lang) {
      'ru' =>
        'В тени может давать крайности, жесткий контроль или эмоциональные качели.',
      'kk' =>
        'Көлеңке қырында шектен шығу, қатаң бақылау не эмоциялық тербеліс беруі мүмкін.',
      _ =>
        'In shadow, it can amplify extremes, rigid control, or emotional swings.',
    };
    final advice = switch (lang) {
      'ru' =>
        'Сверь символ карты с контекстом вопроса и переведи инсайт в один конкретный шаг сегодня.',
      'kk' =>
        'Карта символын сұрағыңыздың контекстімен салыстырып, инсайтты бүгінгі бір нақты қадамға айналдырыңыз.',
      _ =>
        'Match the card symbol to your question context and turn the insight into one concrete step today.',
    };
    final fact = switch (lang) {
      'ru' =>
        '$title в колоде Кроули читается через архетип, композицию и ритм символов.',
      'kk' =>
        '$title Кроули колодасында архетип, композиция және символдар ырғағы арқылы оқылады.',
      _ =>
        '$title in the Crowley deck is read through archetype, composition, and symbolic rhythm.',
    };
    return CardModel(
      id: def.id,
      deckId: DeckType.crowley,
      name: title,
      description: general,
      keywords: keywords,
      meaning: CardMeaning(
        general: general,
        light: light,
        shadow: shadow,
        advice: advice,
      ),
      detailedDescription: '$general $light $shadow $advice',
      funFact: fact,
      stats: _crowleyFallbackStats(def.number),
      imageUrl: cardImageUrl(def.id, deckId: DeckType.crowley),
    );
  }).toList(growable: true);

  for (var suitIndex = 0; suitIndex < _crowleyMinorSuits.length; suitIndex++) {
    final suit = _crowleyMinorSuits[suitIndex];
    for (var rankIndex = 0;
        rankIndex < _crowleyMinorRanks.length;
        rankIndex++) {
      final rank = _crowleyMinorRanks[rankIndex];
      final id = 'ac_${suit.id}_${rank.id}';
      final title = switch (lang) {
        'ru' => '${rank.titleRu} ${suit.titleRu}',
        'kk' => '${suit.titleKk} ${rank.titleKk}',
        _ => '${rank.titleEn} of ${suit.titleEn}',
      };
      final keywords = switch (lang) {
        'ru' => <String>[suit.keywordRu, rank.keywordRu, 'Кроули', 'Телема'],
        'kk' => <String>[suit.keywordKk, rank.keywordKk, 'Кроули', 'Телема'],
        _ => <String>[suit.keywordEn, rank.keywordEn, 'Crowley', 'Thelema'],
      };
      final general = switch (lang) {
        'ru' =>
          '$title в Таро Кроули показывает рабочую формулу энергии масти и текущий ритм воли.',
        'kk' =>
          '$title Кроули таросында масть энергиясының жұмыс формуласын және ерік ырғағын ашады.',
        _ =>
          '$title in Crowley Tarot shows the active suit formula and the present rhythm of will.',
      };
      final light = switch (lang) {
        'ru' =>
          'В плюсе карта даёт точный вектор, ясную сборку ресурса и зрелое управление импульсом.',
        'kk' =>
          'Жарық қырында карта нақты вектор, ресурсты дұрыс жинау және импульсті жетілген басқару береді.',
        _ =>
          'In light, the card brings clear direction, coherent resource use, and mature impulse control.',
      };
      final shadow = switch (lang) {
        'ru' =>
          'В тени включаются крайности: перегрев, контроль, эмоциональная турбулентность или расфокус.',
        'kk' =>
          'Көлеңке қырында шектен шығу байқалады: қызып кету, бақылау, эмоциялық турбуленттік не шашыраңқылық.',
        _ =>
          'In shadow, extremes appear: overheating, control loops, emotional turbulence, or scattered focus.',
      };
      final advice = switch (lang) {
        'ru' =>
          'Сверь символ карты с вопросом и закрепи инсайт одним конкретным действием сегодня.',
        'kk' =>
          'Карта символын сұрақпен сәйкестендіріп, инсайтты бүгін бір нақты әрекетпен бекіт.',
        _ =>
          'Match the card symbol to your question and lock the insight with one concrete action today.',
      };
      final fact = switch (lang) {
        'ru' =>
          '$title в системе Кроули читается через декады, планетарные соответствия и телемическую практику воли.',
        'kk' =>
          '$title Кроули жүйесінде декадтар, планеталық сәйкестіктер және Телема ерік практикасы арқылы оқылады.',
        _ =>
          '$title in the Crowley system is read through decans, planetary correspondences, and practical Thelemic will.',
      };
      majors.add(
        CardModel(
          id: id,
          deckId: DeckType.crowley,
          name: title,
          description: general,
          keywords: keywords,
          meaning: CardMeaning(
            general: general,
            light: light,
            shadow: shadow,
            advice: advice,
          ),
          detailedDescription: '$general $light $shadow $advice',
          funFact: fact,
          stats: _crowleyMinorFallbackStats(
            suitIndex: suitIndex,
            rankIndex: rankIndex,
          ),
          imageUrl: cardImageUrl(id, deckId: DeckType.crowley),
        ),
      );
    }
  }

  final byId = <String, CardModel>{for (final card in majors) card.id: card};
  return crowleyCardIds
      .where(byId.containsKey)
      .map((id) => byId[id]!)
      .toList(growable: false);
}

CardStats _crowleyFallbackStats(int cardNumber) {
  final base = (cardNumber * 5) % 21;
  return CardStats(
    luck: 44 + base,
    power: 46 + ((base + 4) % 21),
    love: 43 + ((base + 9) % 21),
    clarity: 45 + ((base + 14) % 21),
  );
}

CardStats _crowleyMinorFallbackStats({
  required int suitIndex,
  required int rankIndex,
}) {
  final suitBase = <CardStats>[
    const CardStats(luck: 53, power: 74, love: 46, clarity: 59), // wands
    const CardStats(luck: 56, power: 51, love: 75, clarity: 57), // cups
    const CardStats(luck: 49, power: 55, love: 47, clarity: 77), // swords
    const CardStats(luck: 72, power: 58, love: 53, clarity: 63), // pentacles
  ][suitIndex];
  final rankShift = <(int, int, int, int)>[
    (4, 6, 4, 6), // ace
    (0, 2, 0, 2), // two
    (2, 4, 2, 2), // three
    (2, 0, 2, 2), // four
    (-4, 2, -4, 2), // five
    (4, 2, 4, 2), // six
    (-2, 2, -2, 4), // seven
    (-2, 4, -2, 4), // eight
    (2, 2, 2, 4), // nine
    (-1, 1, -1, 1), // ten
    (0, 2, 0, 2), // page
    (1, 5, 0, 1), // knight
    (1, 0, 4, 2), // queen
    (2, 4, 2, 2), // king
  ][rankIndex];
  int clamp(int value) => value.clamp(35, 92);
  return CardStats(
    luck: clamp(suitBase.luck + rankShift.$1),
    power: clamp(suitBase.power + rankShift.$2),
    love: clamp(suitBase.love + rankShift.$3),
    clarity: clamp(suitBase.clarity + rankShift.$4),
  );
}

List<CardModel> _completeCrowleyCards(
  List<CardModel> cards, {
  required Locale locale,
  required DeckType deckId,
}) {
  final fallbackCrowley = _buildCrowleyFallback(locale);
  final fallbackById = {for (final card in fallbackCrowley) card.id: card};
  if (deckId == DeckType.crowley) {
    return crowleyCardIds
        .where(fallbackById.containsKey)
        .map((id) => fallbackById[id]!)
        .toList(growable: false);
  }

  final preserved =
      cards.where((card) => card.deckId != DeckType.crowley).toList(
            growable: true,
          );
  for (final id in crowleyCardIds) {
    final card = fallbackById[id];
    if (card != null) {
      preserved.add(card);
    }
  }
  return preserved;
}

class _CrowleyMinorSuitDef {
  const _CrowleyMinorSuitDef({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleKk,
    required this.keywordEn,
    required this.keywordRu,
    required this.keywordKk,
  });

  final String id;
  final String titleEn;
  final String titleRu;
  final String titleKk;
  final String keywordEn;
  final String keywordRu;
  final String keywordKk;
}

class _CrowleyMinorRankDef {
  const _CrowleyMinorRankDef({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleKk,
    required this.keywordEn,
    required this.keywordRu,
    required this.keywordKk,
  });

  final String id;
  final String titleEn;
  final String titleRu;
  final String titleKk;
  final String keywordEn;
  final String keywordRu;
  final String keywordKk;
}

const List<_CrowleyMinorSuitDef> _crowleyMinorSuits = [
  _CrowleyMinorSuitDef(
    id: 'wands',
    titleEn: 'Wands',
    titleRu: 'Жезлов',
    titleKk: 'Таяқтар',
    keywordEn: 'will',
    keywordRu: 'воля',
    keywordKk: 'ерік',
  ),
  _CrowleyMinorSuitDef(
    id: 'cups',
    titleEn: 'Cups',
    titleRu: 'Кубков',
    titleKk: 'Тостағандар',
    keywordEn: 'emotion',
    keywordRu: 'чувства',
    keywordKk: 'сезім',
  ),
  _CrowleyMinorSuitDef(
    id: 'swords',
    titleEn: 'Swords',
    titleRu: 'Мечей',
    titleKk: 'Қылыштар',
    keywordEn: 'mind',
    keywordRu: 'разум',
    keywordKk: 'ой',
  ),
  _CrowleyMinorSuitDef(
    id: 'pentacles',
    titleEn: 'Pentacles',
    titleRu: 'Пентаклей',
    titleKk: 'Пентакльдер',
    keywordEn: 'matter',
    keywordRu: 'материя',
    keywordKk: 'материя',
  ),
];

const List<_CrowleyMinorRankDef> _crowleyMinorRanks = [
  _CrowleyMinorRankDef(
    id: 'ace',
    titleEn: 'Ace',
    titleRu: 'Туз',
    titleKk: 'Тузы',
    keywordEn: 'ignition',
    keywordRu: 'импульс',
    keywordKk: 'импульс',
  ),
  _CrowleyMinorRankDef(
    id: 'two',
    titleEn: 'Two',
    titleRu: 'Двойка',
    titleKk: 'Екісі',
    keywordEn: 'duality',
    keywordRu: 'полярность',
    keywordKk: 'екілік',
  ),
  _CrowleyMinorRankDef(
    id: 'three',
    titleEn: 'Three',
    titleRu: 'Тройка',
    titleKk: 'Үші',
    keywordEn: 'expansion',
    keywordRu: 'рост',
    keywordKk: 'өсу',
  ),
  _CrowleyMinorRankDef(
    id: 'four',
    titleEn: 'Four',
    titleRu: 'Четверка',
    titleKk: 'Төрті',
    keywordEn: 'structure',
    keywordRu: 'структура',
    keywordKk: 'құрылым',
  ),
  _CrowleyMinorRankDef(
    id: 'five',
    titleEn: 'Five',
    titleRu: 'Пятерка',
    titleKk: 'Бесі',
    keywordEn: 'trial',
    keywordRu: 'испытание',
    keywordKk: 'сынақ',
  ),
  _CrowleyMinorRankDef(
    id: 'six',
    titleEn: 'Six',
    titleRu: 'Шестерка',
    titleKk: 'Алтысы',
    keywordEn: 'harmony',
    keywordRu: 'гармония',
    keywordKk: 'үйлесім',
  ),
  _CrowleyMinorRankDef(
    id: 'seven',
    titleEn: 'Seven',
    titleRu: 'Семерка',
    titleKk: 'Жетісі',
    keywordEn: 'threshold',
    keywordRu: 'порог',
    keywordKk: 'шек',
  ),
  _CrowleyMinorRankDef(
    id: 'eight',
    titleEn: 'Eight',
    titleRu: 'Восьмерка',
    titleKk: 'Сегізі',
    keywordEn: 'velocity',
    keywordRu: 'ускорение',
    keywordKk: 'жылдамдық',
  ),
  _CrowleyMinorRankDef(
    id: 'nine',
    titleEn: 'Nine',
    titleRu: 'Девятка',
    titleKk: 'Тоғызы',
    keywordEn: 'focus',
    keywordRu: 'фокус',
    keywordKk: 'фокус',
  ),
  _CrowleyMinorRankDef(
    id: 'ten',
    titleEn: 'Ten',
    titleRu: 'Десятка',
    titleKk: 'Оны',
    keywordEn: 'completion',
    keywordRu: 'завершение',
    keywordKk: 'аяқталу',
  ),
  _CrowleyMinorRankDef(
    id: 'page',
    titleEn: 'Page',
    titleRu: 'Паж',
    titleKk: 'Пажы',
    keywordEn: 'message',
    keywordRu: 'вестник',
    keywordKk: 'хабар',
  ),
  _CrowleyMinorRankDef(
    id: 'knight',
    titleEn: 'Knight',
    titleRu: 'Рыцарь',
    titleKk: 'Рыцары',
    keywordEn: 'charge',
    keywordRu: 'рывок',
    keywordKk: 'серпін',
  ),
  _CrowleyMinorRankDef(
    id: 'queen',
    titleEn: 'Queen',
    titleRu: 'Королева',
    titleKk: 'Ханшайымы',
    keywordEn: 'magnetism',
    keywordRu: 'магнетизм',
    keywordKk: 'тартылыс',
  ),
  _CrowleyMinorRankDef(
    id: 'king',
    titleEn: 'King',
    titleRu: 'Король',
    titleKk: 'Патшасы',
    keywordEn: 'mastery',
    keywordRu: 'мастерство',
    keywordKk: 'шеберлік',
  ),
];

class _CrowleyDef {
  const _CrowleyDef({
    required this.number,
    required this.slug,
    required this.titleEn,
    required this.titleRu,
    required this.titleKk,
    required this.imagePath,
  });

  final int number;
  final String slug;
  final String titleEn;
  final String titleRu;
  final String titleKk;
  final String imagePath;

  String get id => 'ac_${number.toString().padLeft(2, '0')}_$slug';
}

const List<_CrowleyDef> _crowleyDefs = [
  _CrowleyDef(
    number: 0,
    slug: 'fool',
    titleEn: 'The Fool',
    titleRu: 'Шут',
    titleKk: 'Ақымақ',
    imagePath: 'cards/ac/ac-joker.webp',
  ),
  _CrowleyDef(
    number: 1,
    slug: 'magician',
    titleEn: 'The Magician',
    titleRu: 'Маг',
    titleKk: 'Сиқыршы',
    imagePath: 'cards/ac/ac-magician.webp',
  ),
  _CrowleyDef(
    number: 2,
    slug: 'high_priestess',
    titleEn: 'The High Priestess',
    titleRu: 'Верховная Жрица',
    titleKk: 'Жоғарғы Абыз әйел',
    imagePath: 'cards/ac/ac-high-priestess.webp',
  ),
  _CrowleyDef(
    number: 3,
    slug: 'empress',
    titleEn: 'The Empress',
    titleRu: 'Императрица',
    titleKk: 'Императрица',
    imagePath: 'cards/ac/ac-empress.webp',
  ),
  _CrowleyDef(
    number: 4,
    slug: 'emperor',
    titleEn: 'The Emperor',
    titleRu: 'Император',
    titleKk: 'Император',
    imagePath: 'cards/ac/ac-emperor.webp',
  ),
  _CrowleyDef(
    number: 5,
    slug: 'hierophant',
    titleEn: 'The Hierophant',
    titleRu: 'Иерофант',
    titleKk: 'Иерофант',
    imagePath: 'cards/ac/ac-hierophant.webp',
  ),
  _CrowleyDef(
    number: 6,
    slug: 'lovers',
    titleEn: 'The Lovers',
    titleRu: 'Влюблённые',
    titleKk: 'Ғашықтар',
    imagePath: 'cards/ac/ac-lovers.webp',
  ),
  _CrowleyDef(
    number: 7,
    slug: 'chariot',
    titleEn: 'The Chariot',
    titleRu: 'Колесница',
    titleKk: 'Арба',
    imagePath: 'cards/ac/ac-chariot.webp',
  ),
  _CrowleyDef(
    number: 8,
    slug: 'strength',
    titleEn: 'Strength',
    titleRu: 'Сила',
    titleKk: 'Күш',
    imagePath: 'cards/ac/ac-power.webp',
  ),
  _CrowleyDef(
    number: 9,
    slug: 'hermit',
    titleEn: 'The Hermit',
    titleRu: 'Отшельник',
    titleKk: 'Тақуа',
    imagePath: 'cards/ac/ac-hermit.webp',
  ),
  _CrowleyDef(
    number: 10,
    slug: 'wheel_of_fortune',
    titleEn: 'Wheel of Fortune',
    titleRu: 'Колесо Фортуны',
    titleKk: 'Фортуна Дөңгелегі',
    imagePath: 'cards/ac/ac-wheel-of-fortune.webp',
  ),
  _CrowleyDef(
    number: 11,
    slug: 'justice',
    titleEn: 'Justice',
    titleRu: 'Правосудие',
    titleKk: 'Әділет',
    imagePath: 'cards/ac/ac-justice.webp',
  ),
  _CrowleyDef(
    number: 12,
    slug: 'hanged_man',
    titleEn: 'The Hanged Man',
    titleRu: 'Повешенный',
    titleKk: 'Асылған',
    imagePath: 'cards/ac/ac-punishment.webp',
  ),
  _CrowleyDef(
    number: 13,
    slug: 'death',
    titleEn: 'Death',
    titleRu: 'Смерть',
    titleKk: 'Өлім',
    imagePath: 'cards/ac/ac-death.webp',
  ),
  _CrowleyDef(
    number: 14,
    slug: 'temperance',
    titleEn: 'Temperance',
    titleRu: 'Умеренность',
    titleKk: 'Теңгерім',
    imagePath: 'cards/ac/ac-temperance.webp',
  ),
  _CrowleyDef(
    number: 15,
    slug: 'devil',
    titleEn: 'The Devil',
    titleRu: 'Дьявол',
    titleKk: 'Ібіліс',
    imagePath: 'cards/ac/ac-devil.webp',
  ),
  _CrowleyDef(
    number: 16,
    slug: 'tower',
    titleEn: 'The Tower',
    titleRu: 'Башня',
    titleKk: 'Мұнара',
    imagePath: 'cards/ac/ac-tower.webp',
  ),
  _CrowleyDef(
    number: 17,
    slug: 'star',
    titleEn: 'The Star',
    titleRu: 'Звезда',
    titleKk: 'Жұлдыз',
    imagePath: 'cards/ac/ac-star.webp',
  ),
  _CrowleyDef(
    number: 18,
    slug: 'moon',
    titleEn: 'The Moon',
    titleRu: 'Луна',
    titleKk: 'Ай',
    imagePath: 'cards/ac/ac-moon.webp',
  ),
  _CrowleyDef(
    number: 19,
    slug: 'sun',
    titleEn: 'The Sun',
    titleRu: 'Солнце',
    titleKk: 'Күн',
    imagePath: 'cards/ac/ac-sun.webp',
  ),
  _CrowleyDef(
    number: 20,
    slug: 'judgement',
    titleEn: 'Judgement',
    titleRu: 'Суд',
    titleKk: 'Сот',
    imagePath: 'cards/ac/ac-judgement.webp',
  ),
  _CrowleyDef(
    number: 21,
    slug: 'world',
    titleEn: 'The World',
    titleRu: 'Мир',
    titleKk: 'Әлем',
    imagePath: 'cards/ac/ac-world.webp',
  ),
];

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
