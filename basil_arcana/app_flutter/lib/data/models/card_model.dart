import 'package:hive/hive.dart';

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
  @HiveField(4)
  final String detailed;

  const CardMeaning({
    required this.general,
    required this.light,
    required this.shadow,
    required this.advice,
    this.detailed = '',
  });

  factory CardMeaning.fromJson(Map<String, dynamic> json) {
    return CardMeaning(
      general: json['general'] as String,
      light: json['light'] as String,
      shadow: json['shadow'] as String,
      advice: json['advice'] as String,
      detailed: json['detailed'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'general': general,
        'light': light,
        'shadow': shadow,
        'advice': advice,
        'detailed': detailed,
      };
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

  factory CardStats.fromJson(Map<String, dynamic> json) {
    return CardStats(
      luck: json['luck'] as int,
      power: json['power'] as int,
      love: json['love'] as int,
      clarity: json['clarity'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'luck': luck,
        'power': power,
        'love': love,
        'clarity': clarity,
      };
}

class CardModel {
  final String id;
  final String name;
  final List<String> keywords;
  final CardMeaning meaning;
  final String funFact;
  final CardStats? stats;

  const CardModel({
    required this.id,
    required this.name,
    required this.keywords,
    required this.meaning,
    this.funFact = '',
    this.stats,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    final statsData = json['stats'];
    return CardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      funFact: json['funFact'] as String? ?? '',
      stats: statsData is Map<String, dynamic>
          ? CardStats.fromJson(statsData)
          : null,
    );
  }

  factory CardModel.fromLocalizedEntry(
    String id,
    Map<String, dynamic> json,
  ) {
    final statsData = json['stats'];
    return CardModel(
      id: id,
      name: json['title'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      funFact: json['funFact'] as String? ?? '',
      stats: statsData is Map<String, dynamic>
          ? CardStats.fromJson(statsData)
          : null,
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
      detailed: reader.availableBytes > 0 ? reader.readString() : '',
    );
  }

  @override
  void write(BinaryWriter writer, CardMeaning obj) {
    writer
      ..writeString(obj.general)
      ..writeString(obj.light)
      ..writeString(obj.shadow)
      ..writeString(obj.advice)
      ..writeString(obj.detailed);
  }
}
