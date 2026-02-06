import 'package:hive/hive.dart';

import 'card_video.dart';

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

  Map<String, dynamic> toJson() => {
        'general': general,
        'light': light,
        'shadow': shadow,
        'advice': advice,
      };
}

class CardModel {
  final String id;
  final String name;
  final List<String> keywords;
  final CardMeaning meaning;
  final String? detailedDescription;
  final String? funFact;
  final CardStats? stats;
  final String? videoFileName;

  const CardModel({
    required this.id,
    required this.name,
    required this.keywords,
    required this.meaning,
    this.detailedDescription,
    this.funFact,
    this.stats,
    this.videoFileName,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      detailedDescription: json['detailedDescription'] as String?,
      funFact: json['funFact'] as String?,
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: resolveCardVideoFileName(json['id'] as String),
    );
  }

  factory CardModel.fromLocalizedEntry(
    String id,
    Map<String, dynamic> json,
  ) {
    return CardModel(
      id: id,
      name: json['title'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      detailedDescription: json['detailedDescription'] as String?,
      funFact: json['funFact'] as String?,
      stats: CardStats.fromJson(json['stats'] as Map<String, dynamic>?),
      videoFileName: resolveCardVideoFileName(id),
    );
  }
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
      luck: json['luck'] as int,
      power: json['power'] as int,
      love: json['love'] as int,
      clarity: json['clarity'] as int,
    );
  }
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
