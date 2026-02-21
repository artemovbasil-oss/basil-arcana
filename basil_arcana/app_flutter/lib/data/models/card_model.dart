import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../core/config/diagnostics.dart';
import 'card_video.dart';
import 'deck_model.dart';

const int kCardSchemaVersion = 1;

@HiveType(typeId: 0)
class CardMeaning {
  @HiveField(0)
  final String general;
  @HiveField(1)
  final String light;
  @HiveField(2)
  final String shadow;
  @HiveField(3)
  final String advice;

  const CardMeaning({
    required this.general,
    required this.light,
    required this.shadow,
    required this.advice,
  });

  factory CardMeaning.fromJson(Map<String, dynamic> json) {
    return CardMeaning.fromJsonSafe(json);
  }

  factory CardMeaning.fromJsonSafe(
    Map<String, dynamic>? json, {
    String fallbackGeneral = '',
  }) {
    final fallback = fallbackGeneral.trim();
    final general = _stringFromJson(json?['general']);
    final light = _stringFromJson(json?['light']);
    final shadow = _stringFromJson(json?['shadow']);
    final advice = _stringFromJson(json?['advice']);
    final resolvedGeneral = general.isNotEmpty ? general : fallback;
    return CardMeaning(
      general: resolvedGeneral,
      light: light.isNotEmpty ? light : resolvedGeneral,
      shadow: shadow.isNotEmpty ? shadow : resolvedGeneral,
      advice: advice.isNotEmpty ? advice : resolvedGeneral,
    );
  }

  factory CardMeaning.fromGeneralMeaning(String general) {
    final normalized = general.trim();
    return CardMeaning(
      general: normalized,
      light: normalized,
      shadow: normalized,
      advice: normalized,
    );
  }

  Map<String, dynamic> toJson() => {
        'general': general,
        'light': light,
        'shadow': shadow,
        'advice': advice,
      };
}

class CardDto {
  const CardDto({
    required this.id,
    required this.deckId,
    required this.name,
    required this.keywords,
    required this.meaning,
    required this.detailedDescription,
    required this.fact,
    required this.stats,
    required this.videoFileName,
    required this.imageUrl,
    required this.videoUrl,
  });

  final String id;
  final DeckType deckId;
  final String name;
  final List<String> keywords;
  final CardMeaning meaning;
  final String detailedDescription;
  final String fact;
  final CardStats? stats;
  final String? videoFileName;
  final String imageUrl;
  final String? videoUrl;

  factory CardDto.fromJson({
    required String id,
    required Map<String, dynamic> json,
  }) {
    final name = _stringFromJson(json['title']).isNotEmpty
        ? _stringFromJson(json['title'])
        : _stringFromJson(json['name']);
    if (name.isEmpty) {
      _logCardParseWarning(id, 'Missing title/name');
    }
    final keywords = _normalizeKeywords(json['keywords'], id: id);
    final summary = _stringFromJson(json['summary']).isNotEmpty
        ? _stringFromJson(json['summary'])
        : _stringFromJson(json['generalMeaning']);
    final meaningPayload = json['meaning'];
    final meaning = meaningPayload is Map<String, dynamic>
        ? CardMeaning.fromJsonSafe(
            meaningPayload,
            fallbackGeneral: summary,
          )
        : CardMeaning.fromGeneralMeaning(summary);
    final detailed = _stringFromJson(json['description']).isNotEmpty
        ? _stringFromJson(json['description'])
        : _stringFromJson(json['detailedDescription']);
    final fact = _stringFromJson(json['fact']).isNotEmpty
        ? _stringFromJson(json['fact'])
        : _stringFromJson(json['funFact']);
    final deckId =
        deckIdFromString(json['deck'] as String?) ?? _deckIdFromCardId(id);
    return CardDto(
      id: id,
      deckId: deckId,
      name: name,
      keywords: keywords,
      meaning: meaning,
      detailedDescription: detailed,
      fact: fact,
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: _videoFileNameFromJson(json),
      imageUrl: _stringFromJson(json['imageUrl']),
      videoUrl: _stringFromJson(json['videoUrl']).isEmpty
          ? null
          : _stringFromJson(json['videoUrl']),
    );
  }
}

class CardModel {
  final String id;
  final DeckType deckId;
  final String name;
  final List<String> keywords;
  final CardMeaning meaning;
  final String? detailedDescription;
  final String? funFact;
  final CardStats? stats;
  final String? videoFileName;
  final String imageUrl;
  final String? videoUrl;

  const CardModel({
    required this.id,
    required this.deckId,
    required this.name,
    required this.keywords,
    required this.meaning,
    this.detailedDescription,
    this.funFact,
    this.stats,
    this.videoFileName,
    required this.imageUrl,
    this.videoUrl,
  });

  CardModel copyWith({
    String? id,
    DeckType? deckId,
    String? name,
    List<String>? keywords,
    CardMeaning? meaning,
    String? detailedDescription,
    String? funFact,
    CardStats? stats,
    String? videoFileName,
    String? imageUrl,
    String? videoUrl,
  }) {
    return CardModel(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      name: name ?? this.name,
      keywords: keywords ?? this.keywords,
      meaning: meaning ?? this.meaning,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      funFact: funFact ?? this.funFact,
      stats: stats ?? this.stats,
      videoFileName: videoFileName ?? this.videoFileName,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return CardModel(
      id: id,
      deckId:
          deckIdFromString(json['deck'] as String?) ?? _deckIdFromCardId(id),
      name: json['name'] as String,
      keywords: _normalizeKeywords(json['keywords'], id: id),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      detailedDescription: json['detailedDescription'] as String?,
      funFact: (json['fact'] as String?) ?? (json['funFact'] as String?),
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: _videoFileNameFromJson(json),
      imageUrl: json['imageUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
    );
  }

  factory CardModel.fromLocalizedEntry(String id, Map<String, dynamic> json) {
    final dto = CardDto.fromJson(id: id, json: json);
    return CardModel(
      id: dto.id,
      deckId: dto.deckId,
      name: dto.name,
      keywords: dto.keywords,
      meaning: dto.meaning,
      detailedDescription:
          dto.detailedDescription.isEmpty ? null : dto.detailedDescription,
      funFact: dto.fact.isEmpty ? null : dto.fact,
      stats: dto.stats,
      videoFileName: dto.videoFileName,
      imageUrl: dto.imageUrl,
      videoUrl: dto.videoUrl,
    );
  }
}

String? cardVideoUrl(CardModel card, String assetsBaseUrl) {
  final fileName = card.videoFileName?.trim();
  if (fileName != null && fileName.isNotEmpty) {
    final normalized = normalizeVideoFileName(fileName);
    return '$assetsBaseUrl/video/$normalized';
  }
  final explicitUrl = card.videoUrl?.trim();
  if (explicitUrl == null || explicitUrl.isEmpty) {
    if (card.deckId == DeckType.lenormand) {
      final fallbackName = _lenormandVideoFileName(card.id);
      if (fallbackName != null) {
        return '$assetsBaseUrl/video/$fallbackName';
      }
    }
    return null;
  }
  if (explicitUrl.startsWith('http://') || explicitUrl.startsWith('https://')) {
    return explicitUrl;
  }
  final normalized = explicitUrl.replaceFirst(RegExp(r'^/+'), '');
  return '$assetsBaseUrl/video/$normalized';
}

String? _lenormandVideoFileName(String cardId) {
  return lenormandVideoFileNameFromCardId(cardId);
}

String? _videoFileNameFromJson(Map<String, dynamic> json) {
  final raw = json['video'] ?? json['videoFileName'];
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return normalizeVideoFileName(trimmed);
}

String _stringFromJson(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}

List<String> _normalizeKeywords(Object? value, {required String id}) {
  final raw = <String>[];
  if (value is List) {
    raw.addAll(
      value
          .whereType<String>()
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty),
    );
  } else if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      raw.addAll(
        trimmed
            .split(RegExp(r'[;,]'))
            .map((keyword) => keyword.trim())
            .where((keyword) => keyword.isNotEmpty),
      );
    }
  } else if (value != null) {
    _logCardParseWarning(id, 'Unexpected keywords type: ${value.runtimeType}');
  }
  if (raw.isEmpty) {
    return const [];
  }
  final deck = _deckIdFromCardId(id);
  final seen = <String>{};
  final filtered = <String>[];
  for (final keyword in raw) {
    if (_isDeckOnlyKeyword(keyword, deck: deck)) {
      continue;
    }
    final normalized = _normalizeKeywordToken(keyword);
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    filtered.add(keyword);
  }
  return filtered;
}

String _normalizeKeywordToken(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[«»"\'`]+'), '')
      .replaceAll(RegExp(r'[\s_\-]+'), ' ')
      .trim();
}

bool _isDeckOnlyKeyword(
  String keyword, {
  required DeckType deck,
}) {
  final normalized = _normalizeKeywordToken(keyword);
  if (normalized.isEmpty) {
    return true;
  }
  final common = <String>{
    'deck',
    'tarot',
    'таро',
    'колода',
  };
  if (common.contains(normalized)) {
    return true;
  }
  final lenormand = <String>{
    'lenormand',
    'ленорман',
    'ленорманд',
    'lenormand deck',
    'колода ленорман',
    'карты ленорман',
  };
  final crowley = <String>{
    'crowley',
    'кроули',
    'thelema',
    'телема',
    'crowley tarot',
    'таро кроули',
    'колода кроули',
  };
  if (deck == DeckType.lenormand && lenormand.contains(normalized)) {
    return true;
  }
  if (deck == DeckType.crowley && crowley.contains(normalized)) {
    return true;
  }
  return false;
}

void _logCardParseWarning(String id, String message) {
  if (!kEnableRuntimeLogs) {
    return;
  }
  debugPrint('[CardDto] id=$id $message');
}

class CardStats {
  final int luck;
  final int power;
  final int love;
  final int clarity;

  const CardStats({
    required this.luck,
    required this.power,
    required this.love,
    required this.clarity,
  });

  static CardStats? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CardStats(
      luck: json['luck'] as int? ?? 0,
      power: json['power'] as int? ?? 0,
      love: json['love'] as int? ?? 0,
      clarity: json['clarity'] as int? ?? 0,
    );
  }
}

DeckType _deckIdFromCardId(String id) {
  final normalized = canonicalCardId(id);
  if (normalized.startsWith('lenormand_')) {
    return DeckType.lenormand;
  }
  if (normalized.startsWith('ac_')) {
    return DeckType.crowley;
  }
  if (normalized.startsWith('wands_')) {
    return DeckType.wands;
  }
  if (normalized.startsWith('swords_')) {
    return DeckType.swords;
  }
  if (normalized.startsWith('pentacles_')) {
    return DeckType.pentacles;
  }
  if (normalized.startsWith('cups_')) {
    return DeckType.cups;
  }
  return DeckType.major;
}

class CardMeaningAdapter extends TypeAdapter<CardMeaning> {
  @override
  final int typeId = 0;

  @override
  CardMeaning read(BinaryReader reader) {
    return CardMeaning(
      general: reader.readString(),
      light: reader.readString(),
      shadow: reader.readString(),
      advice: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, CardMeaning obj) {
    writer
      ..writeString(obj.general)
      ..writeString(obj.light)
      ..writeString(obj.shadow)
      ..writeString(obj.advice);
  }
}
