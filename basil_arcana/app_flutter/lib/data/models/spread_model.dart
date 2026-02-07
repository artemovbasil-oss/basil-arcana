class SpreadPosition {
  final String id;
  final String title;
  final String? meaning;

  const SpreadPosition({
    required this.id,
    required this.title,
    this.meaning,
  });

  factory SpreadPosition.fromJson(Map<String, dynamic> json) {
    return SpreadPosition(
      id: json['id'] as String,
      title: json['title'] as String,
      meaning: json['meaning'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (meaning != null) 'meaning': meaning,
      };
}

class SpreadModel {
  final String id;
  final String name;
  final String? title;
  final String? description;
  final List<SpreadPosition> positions;
  final int? cardsCount;

  const SpreadModel({
    required this.id,
    required this.name,
    required this.positions,
    this.title,
    this.description,
    this.cardsCount,
  });

  factory SpreadModel.fromJson(Map<String, dynamic> json) {
    return SpreadModel(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      positions: (json['positions'] as List<dynamic>)
          .map((position) => SpreadPosition.fromJson(position))
          .toList(),
      cardsCount: json['cardsCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        'positions': positions.map((position) => position.toJson()).toList(),
        if (cardsCount != null) 'cardsCount': cardsCount,
      };
}
