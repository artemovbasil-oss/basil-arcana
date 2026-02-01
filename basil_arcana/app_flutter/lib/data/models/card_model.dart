class CardMeaning {
  final String general;
  final String light;
  final String shadow;
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

  const CardModel({
    required this.id,
    required this.name,
    required this.keywords,
    required this.meaning,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      meaning: CardMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
    );
  }
}
