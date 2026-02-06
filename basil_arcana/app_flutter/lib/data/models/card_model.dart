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
  final DeckId deckId;
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
      videoFileName: resolveCardVideoFileName(json['id'] as String),
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
      videoFileName: resolveCardVideoFileName(id),
      imageUrl: json['imageUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
    );
  }

  factory CardModel.fromCdnEntry(Map<String, dynamic> json) {
    final id = canonicalCardId(json['id'] as String? ?? '');
    final deck = deckIdFromString(json['deck'] as String?) ??
        _deckIdFromCardId(id);
    final generalMeaning = json['generalMeaning'] as String? ??
        (json['meaning'] as Map<String, dynamic>?)?['general'] as String? ??
        (json['summary'] as String?) ??
        '';
    final meaning = json['meaning'] is Map<String, dynamic>
        ? CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>)
        : CardMeaning.fromGeneralMeaning(generalMeaning);
    return CardModel(
      id: id,
      deckId: deck,
      name: json['title'] as String? ?? json['name'] as String? ?? id,
      keywords: (json['keywords'] as List<dynamic>? ?? const []).cast<String>(),
      meaning: meaning,
      detailedDescription: json['description'] as String? ??
          json['detailedDescription'] as String?,
      funFact: json['interestingFact'] as String? ??
          json['fact'] as String? ??
          json['funFact'] as String?,
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: resolveCardVideoFileName(id),
      imageUrl: json['imageUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
    );
  }
}

const Map<String, String> _majorVideoSlugs = {
  'major_00_fool': 'fool',
  'major_01_magician': 'magician',
  'major_02_high_priestess': 'high_priestess',
  'major_03_empress': 'empress',
  'major_04_emperor': 'emperor',
  'major_05_hierophant': 'hierophant',
  'major_06_lovers': 'lovers',
  'major_07_chariot': 'chariot',
  'major_08_strength': 'strength',
  'major_09_hermit': 'hermit',
  'major_10_wheel': 'wheel_of_fortune',
  'major_11_justice': 'justice',
  'major_12_hanged_man': 'hanged_man',
  'major_13_death': 'death',
  'major_14_temperance': 'temperance',
  'major_15_devil': 'devil',
  'major_16_tower': 'tower',
  'major_17_star': 'star',
  'major_18_moon': 'moon',
  'major_19_sun': 'sun',
  'major_20_judgement': 'judgement',
  'major_21_world': 'world',
};

String? cardVideoUrl(CardModel card, String assetsBaseUrl) {
  final normalizedId = canonicalCardId(card.id);
  final majorSlug = _majorVideoSlugs[normalizedId];
  if (majorSlug != null) {
    return '$assetsBaseUrl/video/$majorSlug.mp4';
  }
  final parts = normalizedId.split('_');
  if (parts.length < 3) {
    return null;
  }
  final rank = parts.sublist(2).join('_');
  const courtRanks = {'king', 'queen', 'knight', 'page'};
  if (!courtRanks.contains(rank)) {
    return null;
  }
  return '$assetsBaseUrl/video/${parts.first}_$rank.mp4';
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

DeckId _deckIdFromCardId(String id) {
  final normalized = canonicalCardId(id);
  if (normalized.startsWith('wands_')) {
    return DeckId.wands;
  }
  if (normalized.startsWith('swords_')) {
    return DeckId.swords;
  }
  if (normalized.startsWith('pentacles_')) {
    return DeckId.pentacles;
  }
  if (normalized.startsWith('cups_')) {
    return DeckId.cups;
  }
  return DeckId.major;
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
