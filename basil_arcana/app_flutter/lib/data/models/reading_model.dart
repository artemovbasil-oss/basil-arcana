import 'package:hive/hive.dart';

import 'ai_result_model.dart';
import 'drawn_card_model.dart';

@HiveType(typeId: 3)
class ReadingModel {
  @HiveField(0)
  final String readingId;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  final String question;

  @HiveField(3)
  final String spreadId;

  @HiveField(4)
  final String spreadName;

  @HiveField(5)
  final List<DrawnCardModel> drawnCards;

  @HiveField(6)
  final String tldr;

  @HiveField(7)
  final List<AiSectionModel> sections;

  @HiveField(8)
  final String why;

  @HiveField(9)
  final String action;

  @HiveField(10)
  final String fullText;

  @HiveField(11)
  final bool aiUsed;

  @HiveField(12)
  final String? requestId;

  const ReadingModel({
    required this.readingId,
    required this.createdAt,
    required this.question,
    required this.spreadId,
    required this.spreadName,
    required this.drawnCards,
    required this.tldr,
    required this.sections,
    required this.why,
    required this.action,
    required this.fullText,
    required this.aiUsed,
    required this.requestId,
  });
}

class ReadingModelAdapter extends TypeAdapter<ReadingModel> {
  @override
  final int typeId = 3;

  @override
  ReadingModel read(BinaryReader reader) {
    return ReadingModel(
      readingId: reader.readString(),
      createdAt: reader.read() as DateTime,
      question: reader.readString(),
      spreadId: reader.readString(),
      spreadName: reader.readString(),
      drawnCards: reader.readList().cast<DrawnCardModel>(),
      tldr: reader.readString(),
      sections: reader.readList().cast<AiSectionModel>(),
      why: reader.readString(),
      action: reader.readString(),
      fullText: reader.readString(),
      aiUsed: reader.readBool(),
      requestId: reader.read() as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingModel obj) {
    writer
      ..writeString(obj.readingId)
      ..write(obj.createdAt)
      ..writeString(obj.question)
      ..writeString(obj.spreadId)
      ..writeString(obj.spreadName)
      ..writeList(obj.drawnCards)
      ..writeString(obj.tldr)
      ..writeList(obj.sections)
      ..writeString(obj.why)
      ..writeString(obj.action)
      ..writeString(obj.fullText)
      ..writeBool(obj.aiUsed)
      ..write(obj.requestId);
  }
}
