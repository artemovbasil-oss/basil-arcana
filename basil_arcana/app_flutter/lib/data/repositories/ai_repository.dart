import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_result_model.dart';
import '../models/card_model.dart';
import '../models/drawn_card_model.dart';
import '../models/spread_model.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.basilarcana.com',
);
const arcanaApiKey = String.fromEnvironment(
  'ARCANA_API_KEY',
  defaultValue: '',
);
const legacyApiKey = String.fromEnvironment(
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
  String get _resolvedApiKey =>
      arcanaApiKey.trim().isNotEmpty ? arcanaApiKey : legacyApiKey;

  bool get hasApiKey => _resolvedApiKey.trim().isNotEmpty;

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
      print(
        '[AiRepository] requestId=unknown url=$apiBaseUrl/api/reading/generate '
        'status=n/a duration_ms=0 error=${AiErrorType.missingApiKey.name}',
      );
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
    final stopwatch = Stopwatch()..start();
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
      if (hasApiKey) 'x-api-key': _resolvedApiKey,
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
      _logFailure(
        uri,
        stopwatch,
        errorType: AiErrorType.timeout,
      );
      throw const AiRepositoryException(AiErrorType.timeout);
    } on SocketException {
      _logFailure(
        uri,
        stopwatch,
        errorType: AiErrorType.noInternet,
      );
      throw const AiRepositoryException(AiErrorType.noInternet);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode == 401) {
      _logFailure(
        uri,
        stopwatch,
        statusCode: response.statusCode,
        errorType: AiErrorType.unauthorized,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.unauthorized);
    }

    if (response.statusCode >= 500) {
      _logFailure(
        uri,
        stopwatch,
        statusCode: response.statusCode,
        errorType: AiErrorType.serverError,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.serverError,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logFailure(
        uri,
        stopwatch,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = AiResultModel.fromJson(data);
      _logSuccess(
        uri,
        stopwatch,
        requestId: result.requestId,
        statusCode: response.statusCode,
      );
      return result;
    } catch (error) {
      _logFailure(
        uri,
        stopwatch,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
      );
    }
  }

  Future<void> smokeTest({required String languageCode}) async {
    const spread = SpreadModel(
      id: 'smoke_one',
      name: 'Smoke Test',
      positions: [
        SpreadPosition(id: 'single', title: 'Focus'),
      ],
    );
    const meaning = CardMeaning(
      general: 'A quick glance.',
      light: 'Calm clarity.',
      shadow: 'Rushed assumptions.',
      advice: 'Take one steady breath.',
    );
    const cards = [
      DrawnCardModel(
        positionId: 'single',
        positionTitle: 'Focus',
        cardId: 'smoke_card',
        cardName: 'The Lantern',
        keywords: ['clarity', 'focus'],
        meaning: meaning,
      ),
    ];
    print('[AiRepository] smokeTest:start baseUrl=$apiBaseUrl');
    final result = await generateReading(
      question: 'Smoke test',
      spread: spread,
      drawnCards: cards,
      languageCode: languageCode,
      mode: ReadingMode.fast,
    );
    print('[AiRepository] smokeTest:success requestId=${result.requestId}');
  }

  String _modeParam(ReadingMode mode) {
    if (mode == ReadingMode.lifeAreas) {
      return 'life_areas';
    }
    return mode.name;
  }

  void _logSuccess(
    Uri uri,
    Stopwatch stopwatch, {
    required String? requestId,
    required int statusCode,
  }) {
    final durationMs = stopwatch.elapsedMilliseconds;
    print(
      '[AiRepository] requestId=${requestId ?? 'unknown'} '
      'url=$uri status=$statusCode duration_ms=$durationMs',
    );
  }

  void _logFailure(
    Uri uri,
    Stopwatch stopwatch, {
    required AiErrorType errorType,
    int? statusCode,
    String? responseBody,
  }) {
    final durationMs = stopwatch.elapsedMilliseconds;
    final requestId = _extractRequestId(responseBody);
    final preview = responseBody == null
        ? null
        : responseBody.substring(
            0,
            responseBody.length > 300 ? 300 : responseBody.length,
          );
    final buffer = StringBuffer('[AiRepository] ')
      ..write('requestId=${requestId ?? 'unknown'} ')
      ..write('url=$uri ')
      ..write('status=${statusCode ?? 'n/a'} ')
      ..write('duration_ms=$durationMs ')
      ..write('error=${errorType.name}');
    if (preview != null && preview.isNotEmpty) {
      buffer.write(' body_preview="${preview.replaceAll('\n', ' ')}"');
    }
    print(buffer.toString());
  }

  String? _extractRequestId(String? responseBody) {
    if (responseBody == null || responseBody.isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(responseBody);
      if (data is Map<String, dynamic> && data['requestId'] is String) {
        return data['requestId'] as String;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
