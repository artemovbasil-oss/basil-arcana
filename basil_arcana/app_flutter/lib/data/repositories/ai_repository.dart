import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

enum AiErrorType {
  missingApiKey,
  unauthorized,
  noInternet,
  timeout,
  serverError,
}

class AiRepositoryException implements Exception {
  const AiRepositoryException(
    this.type, {
    this.statusCode,
    this.message,
  });

  final AiErrorType type;
  final int? statusCode;
  final String? message;

  @override
  String toString() {
    final buffer = StringBuffer('AiRepositoryException(')
      ..write(type.name);
    if (statusCode != null) {
      buffer.write(':$statusCode');
    }
    if (message != null) {
      buffer.write(', $message');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

class AiRepository {
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Future<AiResultModel> generateReading({
    required String question,
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
  }) async {
    if (!hasApiKey) {
      throw const AiRepositoryException(
        AiErrorType.missingApiKey,
        message: 'API key not included in this build.',
      );
    }

    final uri = Uri.parse(apiBaseUrl).resolve('/api/reading/generate');
    final payload = {
      'question': question,
      'spread': spread.toJson(),
      'cards': drawnCards.map((drawn) => drawn.toJson()).toList(),
      'tone': 'neutral',
    };

    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
    };

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const AiRepositoryException(AiErrorType.timeout);
    } on SocketException {
      throw const AiRepositoryException(AiErrorType.noInternet);
    }

    if (response.statusCode == 401) {
      throw const AiRepositoryException(AiErrorType.unauthorized);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRepositoryException(
        AiErrorType.serverError,
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AiResultModel.fromJson(data);
  }
}
