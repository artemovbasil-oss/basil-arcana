class SpreadPosition {
  final String id;
  final String title;

  const SpreadPosition({
    required this.id,
    required this.title,
  });

  factory SpreadPosition.fromJson(Map<String, dynamic> json) {
    return SpreadPosition(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
      };
}

class SpreadModel {
  final String id;
  final String name;
  final List<SpreadPosition> positions;
  final int? cardsCount;

  const SpreadModel({
    required this.id,
    required this.name,
    required this.positions,
    this.cardsCount,
  });

  factory SpreadModel.fromJson(Map<String, dynamic> json) {
    return SpreadModel(
      id: json['id'] as String,
      name: json['name'] as String,
      positions: (json['positions'] as List<dynamic>)
          .map((position) => SpreadPosition.fromJson(position))
          .toList(),
      cardsCount: json['cardsCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'positions': positions.map((position) => position.toJson()).toList(),
        if (cardsCount != null) 'cardsCount': cardsCount,
      };
}
