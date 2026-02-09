import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class AiSectionModel {
  @HiveField(0)
  final String positionId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String text;

  const AiSectionModel({
    required this.positionId,
    required this.title,
    required this.text,
  });

  factory AiSectionModel.fromJson(Map<String, dynamic> json) {
    return AiSectionModel(
      // Be tolerant of slightly different keys/types so valid JSON doesn't
      // surface as a server error for the user.
      positionId:
          (json['positionId'] ?? json['position_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'positionId': positionId,
        'title': title,
        'text': text,
      };
}

class AiResultModel {
  final String tldr;
  final List<AiSectionModel> sections;
  final String why;
  final String action;
  final String fullText;
  final String detailsText;
  final String? requestId;

  const AiResultModel({
    required this.tldr,
    required this.sections,
    required this.why,
    required this.action,
    required this.fullText,
    required this.detailsText,
    required this.requestId,
  });

  factory AiResultModel.fromJson(Map<String, dynamic> json) {
    // Some responses can return sections as a map keyed by positionId.
    final rawSections = json['sections'];
    final sectionList = rawSections is Map
        ? rawSections.values.toList()
        : (rawSections as List<dynamic>? ?? []);
    return AiResultModel(
      tldr: (json['tldr'] ?? json['tldr_text'] ?? '').toString(),
      sections: sectionList
          .whereType<Map<String, dynamic>>()
          .map((section) => AiSectionModel.fromJson(section))
          .toList(),
      why: (json['why'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      fullText: (json['fullText'] ?? json['full_text'] ?? '').toString(),
      detailsText:
          (json['detailsText'] ?? json['details_text'] ?? '').toString(),
      requestId: json['requestId'] as String?,
    );
  }
}

class AiSectionModelAdapter extends TypeAdapter<AiSectionModel> {
  @override
  final int typeId = 2;

  @override
  AiSectionModel read(BinaryReader reader) {
    return AiSectionModel(
      positionId: reader.readString(),
      title: reader.readString(),
      text: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, AiSectionModel obj) {
    writer
      ..writeString(obj.positionId)
      ..writeString(obj.title)
      ..writeString(obj.text);
  }
}
