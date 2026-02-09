import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/network/network_exceptions.dart';
import '../../core/network/telegram_api_client.dart';
import '../../core/telegram/telegram_env.dart';
import '../../core/telemetry/web_error_reporter.dart';
import '../models/ai_result_model.dart';
import '../models/card_model.dart';
import '../models/drawn_card_model.dart';
import '../models/spread_model.dart';

String get apiBaseUrl => ApiConfig.apiBaseUrl;

const Duration _requestTimeout = Duration(seconds: 60);
const Duration _availabilityTimeout = Duration(seconds: 8);

enum AiErrorType {
  misconfigured,
  unauthorized,
  rateLimited,
  noInternet,
  timeout,
  serverError,
  badResponse,
}

enum ReadingMode { fast, deep, lifeAreas, detailsRelationshipsCareer }

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
  bool get isApiConfigured => apiBaseUrl.trim().isNotEmpty;

  String get _telegramInitData => TelegramEnv.instance.initData;
  bool get _hasTelegramInitData => _telegramInitData.trim().isNotEmpty;

  http.Client _wrapClient(http.Client client) {
    return TelegramApiClient(client);
  }

  Future<bool> isBackendAvailable({
    http.Client? client,
    Duration timeout = _availabilityTimeout,
  }) async {
    if (!isApiConfigured) {
      throw const AiRepositoryException(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
    }
    if (kIsWeb && TelegramEnv.instance.isTelegram && !_hasTelegramInitData) {
      const error = AiRepositoryException(
        AiErrorType.unauthorized,
        message: 'Missing Telegram initData',
      );
      if (kEnableDevDiagnostics) {
        logDevFailure(
          buildDevFailureInfo(FailedStage.telegramInitdata, error),
        );
      }
      throw error;
    }
    final uri = Uri.parse(apiBaseUrl).replace(
      path: '/api/reading/availability',
    );
    final requestId = const Uuid().v4();
    final baseClient = client ?? http.Client();
    final httpClient = _wrapClient(baseClient);
    http.Response response;
    try {
      response = await httpClient
          .get(
            uri,
        headers: {
          'x-request-id': requestId,
          if (_hasTelegramInitData)
            'X-Telegram-InitData': _telegramInitData,
        },
      )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] availabilityTimeout requestId=$requestId '
          'message="${error.toString()}"',
        );
      }
      throw const AiRepositoryException(AiErrorType.timeout);
    } on Exception catch (error) {
      if (isSocketException(error) || error is http.ClientException) {
        if (kDebugMode) {
          debugPrint(
            '[AiRepository] availabilityNoInternet requestId=$requestId '
            'message="${error.toString()}"',
          );
        }
        throw const AiRepositoryException(AiErrorType.noInternet);
      }
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] availabilityBadStatus requestId=$requestId '
          'status=${response.statusCode}',
        );
      }
      return false;
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final available = data['available'];
      if (available is bool) {
        return available;
      }
      final ok = data['ok'];
      if (ok is bool) {
        return ok;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] availabilityParseError requestId=$requestId '
          'message="${error.toString()}"',
        );
      }
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
      );
    }
    return false;
  }

  Future<AiResultModel> generateReading({
    required String question,
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
    required String languageCode,
    required ReadingMode mode,
    String? requestIdOverride,
    Map<String, dynamic>? fastReading,
    http.Client? client,
    Duration timeout = _requestTimeout,
  }) async {
    if (!isApiConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] requestId=unknown url=$apiBaseUrl/api/reading/generate '
          'status=n/a duration_ms=0 error=${AiErrorType.serverError.name}',
        );
      }
      _reportWebError(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
      throw const AiRepositoryException(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
    }

    final useTelegramAuth = kIsWeb && _hasTelegramInitData;
    final endpoint = kIsWeb
        ? (useTelegramAuth
            ? '/api/reading/generate'
            : '/api/reading/generate_web')
        : '/api/reading/generate';
    final uri = Uri.parse(apiBaseUrl).replace(
      path: endpoint,
      queryParameters: {
        'mode': _modeParam(mode),
      },
    );
    final requestId = requestIdOverride ?? const Uuid().v4();
    final startTimestamp = DateTime.now().toIso8601String();
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
            mode == ReadingMode.lifeAreas ||
            mode == ReadingMode.detailsRelationshipsCareer
        ? drawnCards
            .map((drawn) => drawn.toAiDeepJson(totalCards: totalCards))
            .toList()
        : drawnCards
            .map((drawn) => drawn.toAiJson(totalCards: totalCards))
            .toList();
    final tone = mode == ReadingMode.lifeAreas ||
            mode == ReadingMode.detailsRelationshipsCareer
        ? 'gentle'
        : 'neutral';
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
      'x-request-id': requestId,
      if (_hasTelegramInitData)
        'X-Telegram-InitData': _telegramInitData,
    };
    final requestPayload = useTelegramAuth
        ? {
            'initData': _telegramInitData,
            'payload': payload,
          }
        : payload;

    final baseClient = client ?? http.Client();
    final httpClient = _wrapClient(baseClient);
    http.Response response;
    try {
      _logStart(
        uri,
        requestId: requestId,
        startTimestamp: startTimestamp,
        timeout: timeout,
      );
      response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(requestPayload),
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        errorType: AiErrorType.timeout,
        exception: error,
      );
      _reportWebError(AiErrorType.timeout, message: error.toString());
      throw const AiRepositoryException(AiErrorType.timeout);
    } on Exception catch (error) {
      if (isSocketException(error) || error is http.ClientException) {
        _logFailure(
          uri,
          stopwatch,
          requestId: requestId,
          errorType: AiErrorType.noInternet,
          exception: error,
        );
        _reportWebError(AiErrorType.noInternet, message: error.toString());
        throw const AiRepositoryException(AiErrorType.noInternet);
      }
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.unauthorized,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.unauthorized,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.unauthorized);
    }

    if (response.statusCode == 429) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.rateLimited,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.rateLimited,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.rateLimited);
    }

    if (response.statusCode >= 500) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.serverError,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.serverError,
        statusCode: response.statusCode,
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
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] responseKeys requestId=$requestId '
          'keys=${data.keys.toList()}',
        );
      }
      final result = AiResultModel.fromJson(data);
      _logSuccess(
        uri,
        stopwatch,
        requestId: result.requestId ?? requestId,
        statusCode: response.statusCode,
      );
      return result;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] responseParseError requestId=$requestId '
          'type=${error.runtimeType} message="${error.toString()}"',
        );
      }
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
      );
    }
  }

  Future<String> generateNatalChart({
    required String birthDate,
    String? birthTime,
    required String languageCode,
    String? requestIdOverride,
    http.Client? client,
    Duration timeout = _requestTimeout,
  }) async {
    if (!isApiConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] requestId=unknown url=$apiBaseUrl/api/natal-chart/generate '
          'status=n/a duration_ms=0 error=${AiErrorType.serverError.name}',
        );
      }
      _reportWebError(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
      throw const AiRepositoryException(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
    }

    final useTelegramAuth = kIsWeb && _hasTelegramInitData;
    final endpoint = kIsWeb
        ? (useTelegramAuth
            ? '/api/natal-chart/generate'
            : '/api/natal-chart/generate_web')
        : '/api/natal-chart/generate';
    final uri = Uri.parse(apiBaseUrl).replace(path: endpoint);
    final requestId = requestIdOverride ?? const Uuid().v4();
    final startTimestamp = DateTime.now().toIso8601String();
    final stopwatch = Stopwatch()..start();
    final payload = {
      'birthDate': birthDate,
      'language': languageCode,
      if (birthTime != null && birthTime.trim().isNotEmpty)
        'birthTime': birthTime,
    };

    final headers = {
      'Content-Type': 'application/json',
      'x-request-id': requestId,
      if (_hasTelegramInitData)
        'X-Telegram-InitData': _telegramInitData,
    };
    final requestPayload = useTelegramAuth
        ? {
            'initData': _telegramInitData,
            'payload': payload,
          }
        : payload;

    final baseClient = client ?? http.Client();
    final httpClient = _wrapClient(baseClient);
    http.Response response;
    try {
      _logStart(
        uri,
        requestId: requestId,
        startTimestamp: startTimestamp,
        timeout: timeout,
      );
      response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(requestPayload),
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        errorType: AiErrorType.timeout,
        exception: error,
      );
      _reportWebError(AiErrorType.timeout, message: error.toString());
      throw const AiRepositoryException(AiErrorType.timeout);
    } on Exception catch (error) {
      if (isSocketException(error) || error is http.ClientException) {
        _logFailure(
          uri,
          stopwatch,
          requestId: requestId,
          errorType: AiErrorType.noInternet,
          exception: error,
        );
        _reportWebError(AiErrorType.noInternet, message: error.toString());
        throw const AiRepositoryException(AiErrorType.noInternet);
      }
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.unauthorized,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.unauthorized,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.unauthorized);
    }

    if (response.statusCode == 429) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.rateLimited,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.rateLimited,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.rateLimited);
    }

    if (response.statusCode >= 500) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.serverError,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.serverError,
        statusCode: response.statusCode,
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
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final interpretation = data['interpretation'];
      if (interpretation is String && interpretation.trim().isNotEmpty) {
        _logSuccess(
          uri,
          stopwatch,
          requestId: data['requestId'] as String? ?? requestId,
          statusCode: response.statusCode,
        );
        return interpretation.trim();
      }
      throw const FormatException('Missing interpretation');
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] natalParseError requestId=$requestId '
          'type=${error.runtimeType} message="${error.toString()}"',
        );
      }
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
      );
    }
  }

  Future<String?> fetchReadingDetails({
    required String question,
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
    required String locale,
    String? requestIdOverride,
    http.Client? client,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    if (!isApiConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] requestId=unknown url=$apiBaseUrl/api/reading/details '
          'status=n/a duration_ms=0 error=${AiErrorType.serverError.name}',
        );
      }
      _reportWebError(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
      throw const AiRepositoryException(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
    }
    if (kIsWeb && !_hasTelegramInitData) {
      _reportWebError(
        AiErrorType.unauthorized,
        message: 'Open this experience inside Telegram to continue.',
      );
      throw const AiRepositoryException(
        AiErrorType.unauthorized,
        message: 'Telegram WebApp required',
      );
    }

    final uri = Uri.parse(apiBaseUrl).replace(
      path: '/api/reading/details',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(900000) + 100000;
    final requestId = requestIdOverride ??
        'details-$timestamp-$randomSuffix';
    final startTimestamp = DateTime.now().toIso8601String();
    final stopwatch = Stopwatch()..start();
    final totalCards = spread.positions.length;
    final payload = {
      'question': question,
      'spread': spread.toJson(),
      'cards': drawnCards
          .map((drawn) => drawn.toAiDeepJson(totalCards: totalCards))
          .toList(),
      'locale': locale,
    };

    final headers = {
      'Content-Type': 'application/json',
      'x-request-id': requestId,
      if (_hasTelegramInitData)
        'X-Telegram-InitData': _telegramInitData,
    };

    final baseClient = client ?? http.Client();
    final httpClient = _wrapClient(baseClient);
    http.Response response;
    try {
      _logStart(
        uri,
        requestId: requestId,
        startTimestamp: startTimestamp,
        timeout: timeout,
      );
      response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        errorType: AiErrorType.timeout,
        exception: error,
      );
      _reportWebError(AiErrorType.timeout, message: error.toString());
      throw const AiRepositoryException(AiErrorType.timeout);
    } on Exception catch (error) {
      if (isSocketException(error) || error is http.ClientException) {
        _logFailure(
          uri,
          stopwatch,
          requestId: requestId,
          errorType: AiErrorType.noInternet,
          exception: error,
        );
        _reportWebError(AiErrorType.noInternet, message: error.toString());
        throw const AiRepositoryException(AiErrorType.noInternet);
      }
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.unauthorized,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.unauthorized,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.unauthorized);
    }

    if (response.statusCode == 429) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.rateLimited,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.rateLimited,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw const AiRepositoryException(AiErrorType.rateLimited);
    }

    if (response.statusCode >= 500) {
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.serverError,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.serverError,
        statusCode: response.statusCode,
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
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
      );
    }

    try {
      final parsed = _parseDetailsText(response.body);
      if (parsed == null || parsed.trim().isEmpty) {
        throw const FormatException('Missing detailsText');
      }
      final responseRequestId = _extractRequestId(response.body);
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] detailsResponse requestId=${responseRequestId ?? requestId} '
          'status=${response.statusCode} '
          'preview="${parsed.substring(0, min(parsed.length, 80))}"',
        );
      }
      _logSuccess(
        uri,
        stopwatch,
        requestId: responseRequestId ?? requestId,
        statusCode: response.statusCode,
      );
      return parsed.trim();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AiRepository] detailsParseError requestId=$requestId '
          'type=${error.runtimeType} message="${error.toString()}"',
        );
      }
      _logFailure(
        uri,
        stopwatch,
        requestId: requestId,
        statusCode: response.statusCode,
        errorType: AiErrorType.badResponse,
        responseBody: response.body,
      );
      _reportWebError(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
      );
    }
  }

  String? _parseDetailsText(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is String) {
        return decoded.trim();
      }
      if (decoded is Map<String, dynamic>) {
        final direct = decoded['detailsText'];
        if (direct is String && direct.trim().isNotEmpty) {
          return direct.trim();
        }
        final nested = decoded['data'];
        if (nested is Map<String, dynamic>) {
          final nestedText = nested['detailsText'];
          if (nestedText is String && nestedText.trim().isNotEmpty) {
            return nestedText.trim();
          }
        }
      }
    } catch (_) {
      return trimmed;
    }
    return trimmed;
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
    if (mode == ReadingMode.detailsRelationshipsCareer) {
      return 'details_relationships_career';
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

  void _logStart(
    Uri uri, {
    required String requestId,
    required String startTimestamp,
    required Duration timeout,
  }) {
    print(
      '[AiRepository] requestId=$requestId url=$uri '
      'start_ts=$startTimestamp timeout_ms=${timeout.inMilliseconds}',
    );
  }

  void _logFailure(
    Uri uri,
    Stopwatch stopwatch, {
    required AiErrorType errorType,
    required String requestId,
    int? statusCode,
    String? responseBody,
    Object? exception,
  }) {
    final durationMs = stopwatch.elapsedMilliseconds;
    final responseRequestId = _extractRequestId(responseBody);
    final preview = responseBody == null
        ? null
        : responseBody.substring(
            0,
            responseBody.length > 300 ? 300 : responseBody.length,
          );
    final buffer = StringBuffer('[AiRepository] ')
      ..write('requestId=${responseRequestId ?? requestId} ')
      ..write('url=$uri ')
      ..write('status=${statusCode ?? 'n/a'} ')
      ..write('duration_ms=$durationMs ')
      ..write('error=${errorType.name}');
    if (exception != null) {
      buffer.write(
        ' exception=${exception.runtimeType} message="${exception.toString()}"',
      );
    }
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

  void _reportWebError(
    AiErrorType type, {
    int? statusCode,
    String? message,
    String? responseBody,
  }) {
    if (!kIsWeb) {
      return;
    }
    final preview = responseBody == null
        ? ''
        : responseBody.substring(
            0,
            responseBody.length > 240 ? 240 : responseBody.length,
          );
    final parts = [
      'API error: ${type.name}',
      if (statusCode != null) 'status=$statusCode',
      if (message != null && message.trim().isNotEmpty)
        'message=${message.trim()}',
      if (preview.trim().isNotEmpty) 'body=${preview.trim()}',
    ];
    WebErrorReporter.instance.report(parts.join(' | '));
  }
}
