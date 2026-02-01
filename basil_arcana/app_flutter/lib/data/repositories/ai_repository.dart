import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_result_model.dart';
import '../models/drawn_card_model.dart';
import '../models/spread_model.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.basilarcana.com',
);
const apiKey = String.fromEnvironment(
  'API_KEY',
  defaultValue: '',
);

class AiRepository {
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Future<AiResultModel> generateReading({
    required String question,
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
  }) async {
    if (!hasApiKey) {
      throw Exception('Missing API key');
    }

    final uri = Uri.parse(apiBaseUrl).resolve('/api/reading/generate');
    final payload = {
      'question': question,
      'spread': spread.toJson(),
      'cards': drawnCards.map((drawn) => drawn.toJson()).toList(),
      'tone': 'neutral',
    };

    final headers = {'Content-Type': 'application/json'};
    if (apiKey.trim().isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API failed ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AiResultModel.fromJson(data);
  }
}
