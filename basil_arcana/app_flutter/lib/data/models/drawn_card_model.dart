import 'package:hive/hive.dart';

import 'card_model.dart';

@HiveType(typeId: 1)
class DrawnCardModel {
  @HiveField(0)
  final String positionId;

  @HiveField(1)
  final String positionTitle;

  @HiveField(2)
  final String cardId;

  @HiveField(3)
  final String cardName;

  @HiveField(4)
  final List<String> keywords;

  @HiveField(5)
  final CardMeaning meaning;

  const DrawnCardModel({
    required this.positionId,
    required this.positionTitle,
    required this.cardId,
    required this.cardName,
    required this.keywords,
    required this.meaning,
  });

  Map<String, dynamic> toJson() => {
        'positionId': positionId,
        'positionTitle': positionTitle,
        'cardId': cardId,
        'cardName': cardName,
        'keywords': keywords,
        'meaning': meaning.toJson(),
      };

  Map<String, dynamic> toAiJson({
    required int totalCards,
  }) {
    final keywordLimit = totalCards > 1 ? 3 : 5;
    final meaningLimit = totalCards > 1 ? 90 : 140;
    return {
      'positionId': positionId,
      'positionTitle': positionTitle,
      'cardId': cardId,
      'cardName': cardName,
      'keywords': keywords.take(keywordLimit).toList(),
      'meaning': {
        'general': _truncate(meaning.general, meaningLimit),
        'light': _truncate(meaning.light, meaningLimit),
        'shadow': _truncate(meaning.shadow, meaningLimit),
        'advice': _truncate(meaning.advice, meaningLimit),
      },
    };
  }
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return value.substring(0, maxLength).trimRight();
}

class DrawnCardModelAdapter extends TypeAdapter<DrawnCardModel> {
  @override
  final int typeId = 1;

  @override
  DrawnCardModel read(BinaryReader reader) {
    return DrawnCardModel(
      positionId: reader.readString(),
      positionTitle: reader.readString(),
      cardId: reader.readString(),
      cardName: reader.readString(),
      keywords: reader.readList().cast<String>(),
      meaning: reader.read() as CardMeaning,
    );
  }

  @override
  void write(BinaryWriter writer, DrawnCardModel obj) {
    writer
      ..writeString(obj.positionId)
      ..writeString(obj.positionTitle)
      ..writeString(obj.cardId)
      ..writeString(obj.cardName)
      ..writeList(obj.keywords)
      ..write(obj.meaning);
  }
}
