import 'package:hive/hive.dart';

import 'card_video.dart';
import 'deck_model.dart';

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
    return CardMeaning(
      general: json['general'] as String,
      light: json['light'] as String,
      shadow: json['shadow'] as String,
      advice: json['advice'] as String,
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
    return CardModel(
      id: json['id'] as String,
      deckId: deckIdFromString(json['deck'] as String?) ??
          _deckIdFromCardId(json['id'] as String),
      name: json['name'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      detailedDescription: json['detailedDescription'] as String?,
      funFact: json['funFact'] as String?,
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: _videoFileNameFromJson(json),
      imageUrl: json['imageUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
    );
  }

  factory CardModel.fromLocalizedEntry(String id, Map<String, dynamic> json) {
    final summary = json['summary'] as String?;
    final meaningPayload = json['meaning'] as Map<String, dynamic>?;
    final meaning = meaningPayload != null
        ? CardMeaning.fromJson(meaningPayload)
        : CardMeaning.fromGeneralMeaning(summary ?? '');
    return CardModel(
      id: id,
      deckId: deckIdFromString(json['deck'] as String?) ??
          _deckIdFromCardId(id),
      name: json['title'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: meaning,
      detailedDescription: json['description'] as String? ??
          json['detailedDescription'] as String?,
      funFact: json['fact'] as String? ?? json['funFact'] as String?,
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: _videoFileNameFromJson(json),
      imageUrl: json['imageUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
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
    return null;
  }
  if (explicitUrl.startsWith('http://') || explicitUrl.startsWith('https://')) {
    return explicitUrl;
  }
  final normalized = explicitUrl.replaceFirst(RegExp(r'^/+'), '');
  return '$assetsBaseUrl/video/$normalized';
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
