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
  badResponse,
}

enum ReadingMode { fast, deep, lifeAreas }

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
    required String languageCode,
    required ReadingMode mode,
    Map<String, dynamic>? fastReading,
    http.Client? client,
  }) async {
    if (!hasApiKey) {
      throw const AiRepositoryException(
        AiErrorType.missingApiKey,
        message: 'API key not included in this build.',
      );
    }

    final uri = Uri.parse(apiBaseUrl).replace(
      path: '/api/reading/generate',
      queryParameters: {
        'mode': _modeParam(mode),
      },
    );
    final totalCards = drawnCards.length;
    final responseConstraints = mode == ReadingMode.fast
        ? {
            'tldrMaxChars': 180,
            'sectionMaxChars': 280,
            'actionMaxChars': 160,
          }
        : {
            'tldrMaxChars': 180,
            'sectionMaxChars': 700,
            'whyMaxChars': 400,
            'actionMaxChars': 240,
          };
    final cardsPayload = mode == ReadingMode.deep ||
            mode == ReadingMode.lifeAreas
        ? drawnCards
            .map((drawn) => drawn.toAiDeepJson(totalCards: totalCards))
            .toList()
        : drawnCards
            .map((drawn) => drawn.toAiJson(totalCards: totalCards))
            .toList();
    final tone = mode == ReadingMode.lifeAreas ? 'gentle' : 'neutral';
    final payload = {
      'question': question,
      'spread': spread.toJson(),
      'cards': cardsPayload,
      'tone': tone,
      'language': languageCode,
      'responseFormat': 'strict_json',
      'responseConstraints': responseConstraints,
      if (fastReading != null) 'fastReading': fastReading,
    };

    final headers = {
      'Content-Type': 'application/json',
      if (hasApiKey) 'x-api-key': apiKey,
    };

    final httpClient = client ?? http.Client();
    http.Response response;
    try {
      response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AiRepositoryException(AiErrorType.timeout);
    } on SocketException {
      throw const AiRepositoryException(AiErrorType.noInternet);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode == 401) {
      throw const AiRepositoryException(AiErrorType.unauthorized);
    }

    if (response.statusCode >= 500) {
      throw AiRepositoryException(
        AiErrorType.serverError,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRepositoryException(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AiResultModel.fromJson(data);
    } catch (error) {
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
      );
    }
  }

  String _modeParam(ReadingMode mode) {
    if (mode == ReadingMode.lifeAreas) {
      return 'life_areas';
    }
    return mode.name;
  }
}
