import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_result_model.dart';
import '../models/card_model.dart';
import '../models/drawn_card_model.dart';
import '../models/spread_model.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.basilarcana.com',
);

class AiRepository {
  Future<AiResultModel> generateReading({
    required String question,
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
    required Map<String, CardModel> cardLookup,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/api/reading/generate');
    final payload = {
      'question': question,
      'spread': spread.toJson(),
      'cards': drawnCards.map((drawn) {
        final card = cardLookup[drawn.cardId];
        return {
          'positionId': drawn.positionId,
          'positionTitle': drawn.positionTitle,
          'cardId': drawn.cardId,
          'cardName': drawn.cardName,
          'keywords': drawn.keywords,
          'meaning': card?.meaning.toJson(),
        };
      }).toList(),
      'tone': 'neutral',
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API failed ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AiResultModel.fromJson(data);
  }
}
