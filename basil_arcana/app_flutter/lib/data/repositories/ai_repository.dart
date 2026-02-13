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
import '../../core/telegram/telegram_auth.dart';
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
    this.responseBody,
  });

  final AiErrorType type;
  final int? statusCode;
  final String? message;
  final String? responseBody;

  @override
  String toString() {
    final buffer = StringBuffer('AiRepositoryException(')..write(type.name);
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

class _TelegramAuthState {
  const _TelegramAuthState({
    required this.isTelegram,
    required this.initData,
  });

  final bool isTelegram;
  final String initData;

  bool get hasInitData => initData.trim().isNotEmpty;
  int get initDataLength => initData.length;
}

class AiRepository {
  bool get isApiConfigured => apiBaseUrl.trim().isNotEmpty;

  http.Client _wrapClient(http.Client client) {
    return TelegramApiClient(client);
  }

  Future<_TelegramAuthState> _getTelegramAuthState({
    bool forceRefresh = false,
  }) async {
    final isTelegram = kIsWeb && TelegramAuth.instance.isTelegram;
    final initData = await TelegramAuth.instance.getInitData(
      forceRefresh: forceRefresh,
    );
    return _TelegramAuthState(
      isTelegram: isTelegram,
      initData: initData,
    );
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
    final telegramAuth = await _getTelegramAuthState();
    if (kIsWeb && telegramAuth.isTelegram && !telegramAuth.hasInitData) {
      debugPrint(
        '[AiRepository] Telegram initData empty; check web bridge timing.',
      );
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
      response = await httpClient.get(
        uri,
        headers: {
          'x-request-id': requestId,
          if (telegramAuth.hasInitData)
            'X-Telegram-InitData': telegramAuth.initData,
        },
      ).timeout(timeout);
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

    _logReadingApiResponse(
      uri: uri,
      isTelegram: telegramAuth.isTelegram,
      hasTelegramInitDataHeader: telegramAuth.hasInitData,
      initDataLength: telegramAuth.initDataLength,
      statusCode: response.statusCode,
      responseBody: response.body,
      requestId: requestId,
    );

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
        requestId: 'unknown',
      );
      throw const AiRepositoryException(
        AiErrorType.misconfigured,
        message: 'Missing API_BASE_URL',
      );
    }

    final telegramAuth = await _getTelegramAuthState();
    if (kIsWeb && telegramAuth.isTelegram && !telegramAuth.hasInitData) {
      debugPrint(
        '[AiRepository] Telegram initData empty; check web bridge timing.',
      );
      _reportWebError(
        AiErrorType.unauthorized,
        message: 'Open this experience inside Telegram to continue.',
        requestId: 'unknown',
      );
      throw const AiRepositoryException(
        AiErrorType.unauthorized,
        message: 'Telegram WebApp required',
      );
    }

    final useTelegramWeb = kIsWeb && telegramAuth.isTelegram;
    final endpoint =
        useTelegramWeb ? '/api/reading/generate_web' : '/api/reading/generate';
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
    final spreadCardCount = spread.cardsCount ?? spread.positions.length;
    final isFiveCardSpread = spreadCardCount >= 5 || totalCards >= 5;
    final promptQuestion = _composeReadingPromptQuestion(
      question: question,
      languageCode: languageCode,
      mode: mode,
      spread: spread,
      drawnCards: drawnCards,
    );
    final responseConstraints = mode == ReadingMode.fast
        ? isFiveCardSpread
            ? {
                'tldrMaxChars': 260,
                'sectionMaxChars': 520,
                'whyMaxChars': 560,
                'actionMaxChars': 280,
              }
            : {
                'tldrMaxChars': 180,
                'sectionMaxChars': 340,
                'actionMaxChars': 220,
              }
        : {
            'tldrMaxChars': 220,
            'sectionMaxChars': 700,
            'whyMaxChars': 480,
            'actionMaxChars': 320,
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
      'question': promptQuestion,
      'userQuestion': question.trim(),
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
      if (telegramAuth.hasInitData)
        'X-Telegram-InitData': telegramAuth.initData,
    };
    if (useTelegramWeb && kDebugMode) {
      _logTelegramInitDataDebug(
        endpoint: endpoint,
        initData: telegramAuth.initData,
      );
    }
    final requestPayload = useTelegramWeb
        ? {
            if (telegramAuth.hasInitData) 'initData': telegramAuth.initData,
            'payload': payload,
          }
        : {
            ...payload,
            if (telegramAuth.hasInitData) 'initData': telegramAuth.initData,
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
      _reportWebError(AiErrorType.timeout,
          message: error.toString(), requestId: requestId);
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
        _reportWebError(AiErrorType.noInternet,
            message: error.toString(), requestId: requestId);
        throw const AiRepositoryException(AiErrorType.noInternet);
      }
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    _logReadingApiResponse(
      uri: uri,
      isTelegram: telegramAuth.isTelegram,
      hasTelegramInitDataHeader: telegramAuth.hasInitData,
      initDataLength: telegramAuth.initDataLength,
      statusCode: response.statusCode,
      responseBody: response.body,
      requestId: requestId,
    );

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
        requestId: requestId,
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
        requestId: requestId,
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
        requestId: requestId,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.serverError,
        statusCode: response.statusCode,
        responseBody: response.body,
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
        requestId: requestId,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    try {
      final result = _parseAiResultResponse(
        body: response.body,
        requestId: requestId,
      );
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
        requestId: requestId,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw AiRepositoryException(
        AiErrorType.badResponse,
        message: error.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  AiResultModel _parseAiResultResponse({
    required String body,
    required String requestId,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error) {
      throw FormatException('Invalid JSON: $error');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Response root must be an object.');
    }

    final payload = _extractResultPayload(decoded);
    if (kDebugMode) {
      debugPrint(
        '[AiRepository] responseKeys requestId=$requestId '
        'keys=${payload.keys.toList()}',
      );
    }

    final result = AiResultModel.fromJson(payload);
    final hasAnyContent = result.tldr.trim().isNotEmpty ||
        result.sections.isNotEmpty ||
        result.why.trim().isNotEmpty ||
        result.action.trim().isNotEmpty ||
        result.fullText.trim().isNotEmpty;
    if (!hasAnyContent) {
      throw const FormatException(
          'Reading payload has no displayable content.');
    }

    final fallbackFullText = [
      result.tldr,
      ...result.sections.map((section) => section.text),
      result.why,
      result.action,
    ].where((line) => line.trim().isNotEmpty).join('\n\n');

    return AiResultModel(
      tldr: result.tldr.trim().isEmpty ? 'Your reading is ready.' : result.tldr,
      sections: result.sections,
      why: result.why,
      action: result.action,
      fullText: result.fullText.trim().isNotEmpty
          ? result.fullText
          : fallbackFullText,
      detailsText: result.detailsText,
      requestId: result.requestId ?? requestId,
    );
  }

  Map<String, dynamic> _extractResultPayload(Map<String, dynamic> root) {
    const nestedKeys = ['data', 'result', 'payload', 'reading'];
    for (final key in nestedKeys) {
      final candidate = root[key];
      if (candidate is Map<String, dynamic>) {
        return candidate;
      }
    }
    return root;
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

    final telegramAuth = await _getTelegramAuthState();
    final useTelegramAuth = kIsWeb && telegramAuth.hasInitData;
    final endpoint = kIsWeb
        ? (useTelegramAuth
            ? '/api/natal-chart/generate_web'
            : '/api/natal-chart/generate')
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
      if (telegramAuth.hasInitData)
        'X-Telegram-InitData': telegramAuth.initData,
    };
    final requestPayload = useTelegramAuth
        ? {
            if (telegramAuth.hasInitData) 'initData': telegramAuth.initData,
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
      _reportWebError(AiErrorType.timeout,
          message: error.toString(), requestId: requestId);
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
        _reportWebError(AiErrorType.noInternet,
            message: error.toString(), requestId: requestId);
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
    final telegramAuth = await _getTelegramAuthState();
    if (kIsWeb && telegramAuth.isTelegram && !telegramAuth.hasInitData) {
      debugPrint(
        '[AiRepository] Telegram initData empty; check web bridge timing.',
      );
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
    final requestId = requestIdOverride ?? 'details-$timestamp-$randomSuffix';
    final startTimestamp = DateTime.now().toIso8601String();
    final stopwatch = Stopwatch()..start();
    final totalCards = spread.positions.length;
    final promptQuestion = _composeReadingPromptQuestion(
      question: question,
      languageCode: locale,
      mode: ReadingMode.deep,
      spread: spread,
      drawnCards: drawnCards,
    );
    final payload = {
      if (telegramAuth.hasInitData) 'initData': telegramAuth.initData,
      'question': promptQuestion,
      'spread': spread.toJson(),
      'cards': drawnCards
          .map((drawn) => drawn.toAiDeepJson(totalCards: totalCards))
          .toList(),
      'locale': locale,
    };

    final headers = {
      'Content-Type': 'application/json',
      'x-request-id': requestId,
      if (telegramAuth.hasInitData)
        'X-Telegram-InitData': telegramAuth.initData,
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
      _reportWebError(AiErrorType.timeout,
          message: error.toString(), requestId: requestId);
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
        _reportWebError(AiErrorType.noInternet,
            message: error.toString(), requestId: requestId);
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
    final telegramAuth = await _getTelegramAuthState();
    final initData = telegramAuth.initData;
    print('[AiRepository] smokeTest:start baseUrl=$apiBaseUrl');
    print(
      '[AiRepository] smokeTest:initData length=${initData.length} '
      'startsWithQueryId=${initData.startsWith('query_id=')}',
    );
    final available = await isBackendAvailable();
    print('[AiRepository] smokeTest:availability ok=$available');
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

  String _composeReadingPromptQuestion({
    required String question,
    required String languageCode,
    required ReadingMode mode,
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
  }) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    final focus = question.trim().isEmpty
        ? (normalizedLanguage == 'ru'
            ? 'общая жизненная ситуация'
            : normalizedLanguage == 'kk'
                ? 'жалпы өмірлік жағдай'
                : 'current life situation')
        : question.trim();
    final cardNames = drawnCards
        .map((drawn) => drawn.cardName.trim())
        .where((name) => name.isNotEmpty)
        .take(5)
        .join(', ');
    final positions = spread.positions
        .map((position) => position.title.trim())
        .where((title) => title.isNotEmpty)
        .take(5)
        .join(', ');
    final spreadCardCount = spread.cardsCount ?? spread.positions.length;
    final isFiveCardSpread = spreadCardCount >= 5 || drawnCards.length >= 5;

    if (normalizedLanguage == 'ru') {
      final depthLine = mode == ReadingMode.deep ||
              mode == ReadingMode.detailsRelationshipsCareer
          ? 'Объясни причинно-следственные связи и внутренние мотивы, а не только итог.'
          : 'Дай прямой и практичный ответ уже в первых строках.';
      final premiumDepthLine = isFiveCardSpread
          ? 'Это премиум-расклад на 5 карт: собери целостный сценарий из всех позиций, явно выдели 2-3 ключевых связки между картами и покажи, как каждая связка меняет прогноз. Добавь короткую оценку рисков и возможностей по шкале от низкого к высокому и переведи вывод в конкретный план действий.'
          : '';
      return '''
Фокус запроса пользователя: "$focus".
Ответ должен быть адресным и персональным: напрямую свяжи выводы с вопросом пользователя, позициями расклада ($positions) и картами ($cardNames).
$depthLine
$premiumDepthLine
Избегай общих фраз и повторов. В конце дай 1-2 конкретных шага, что делать дальше именно по этому запросу.''';
    }

    if (normalizedLanguage == 'kk' || normalizedLanguage == 'kz') {
      final depthLine = mode == ReadingMode.deep ||
              mode == ReadingMode.detailsRelationshipsCareer
          ? 'Себеп-салдарды және ішкі уәждерді ашып түсіндір.'
          : 'Жауаптың басында-ақ нақты практикалық бағыт бер.';
      final premiumDepthLine = isFiveCardSpread
          ? 'Бұл 5 карталық премиум жайылма: барлық позицияны біртұтас сценарийге біріктір, карталар арасындағы 2-3 негізгі байланысты анық көрсет және әр байланыс болжамға қалай әсер ететінін түсіндір. Тәуекелдер мен мүмкіндіктерді қысқа түрде төменнен жоғарыға дейін бағалап, қорытындыны нақты әрекет жоспарына айналдыр.'
          : '';
      return '''
Пайдаланушы сұрағының фокусы: "$focus".
Жауап жеке әрі нысаналы болсын: қорытындыны сұрақпен, жайылма позицияларымен ($positions) және карталармен ($cardNames) тікелей байланыстыр.
$depthLine
$premiumDepthLine
Жалпылама, шаблон тіркестерден қаш. Соңында осы сұраққа сай 1-2 нақты қадам ұсын.''';
    }

    final depthLine = mode == ReadingMode.deep ||
            mode == ReadingMode.detailsRelationshipsCareer
        ? 'Explain cause-and-effect and inner drivers, not only conclusions.'
        : 'Give a direct, practical answer in the opening lines.';
    final premiumDepthLine = isFiveCardSpread
        ? 'This is a premium 5-card spread: build one coherent scenario across all positions, call out 2-3 pivotal card-to-card links, and explain how each link changes the forecast. Add a brief risk/opportunity estimate from low to high and convert the synthesis into a concrete action plan.'
        : '';
    return '''
User focus: "$focus".
Make the reading specific and personal: tie conclusions directly to the question, spread positions ($positions), and drawn cards ($cardNames).
$depthLine
$premiumDepthLine
Avoid generic filler and repetition. Finish with 1-2 concrete next steps tailored to this question.''';
  }

  void _logTelegramInitDataDebug({
    required String endpoint,
    required String initData,
  }) {
    if (!kDebugMode) {
      return;
    }
    final trimmed = initData.trim();
    if (trimmed.isEmpty) {
      debugPrint('[AiRepository] telegramInitData endpoint=$endpoint empty');
      return;
    }
    final prefixLength = min(10, trimmed.length);
    final prefix = trimmed.substring(0, prefixLength);
    debugPrint(
      '[AiRepository] telegramInitData endpoint=$endpoint '
      'length=${trimmed.length} prefix=${prefix}***',
    );
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

  void _logReadingApiResponse({
    required Uri uri,
    required bool isTelegram,
    required bool hasTelegramInitDataHeader,
    required int initDataLength,
    required int statusCode,
    required String responseBody,
    required String requestId,
  }) {
    final responseRequestId = _extractRequestId(responseBody);
    final preview = responseBody.substring(
      0,
      responseBody.length > 500 ? 500 : responseBody.length,
    );
    print(
      '[AiRepository] readingApiResponse url=$uri '
      'requestId=${responseRequestId ?? requestId} '
      'isTelegram=$isTelegram '
      'telegram_header=$hasTelegramInitDataHeader '
      'initData_length=$initDataLength '
      'status=$statusCode '
      'body="${preview.replaceAll('\n', ' ')}"',
    );
    if (kDebugMode) {
      debugPrint(
        '[AiRepository] telegramAuth endpoint=${uri.path} '
        'requestId=${responseRequestId ?? requestId} '
        'status=$statusCode '
        'isTelegram=$isTelegram '
        'initDataPresent=$hasTelegramInitDataHeader '
        'initDataLength=$initDataLength',
      );
    }
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
    String? requestId,
  }) {
    if (!kIsWeb || !kEnableDevDiagnostics) {
      return;
    }
    final preview = _trimBody(responseBody, maxLength: 400);
    final buildMode = kReleaseMode ? 'release' : 'debug';
    final parts = [
      'API error: ${type.name}',
      'build=$buildMode',
      'apiBaseUrl=$apiBaseUrl',
      'requestId=${requestId ?? _extractRequestId(responseBody) ?? 'unknown'}',
      if (statusCode != null) 'status=$statusCode',
      if (message != null && message.trim().isNotEmpty)
        'message=${message.trim()}',
      if (preview.isNotEmpty) 'body=$preview',
    ];
    WebErrorReporter.instance.report(parts.join(' | '));
  }

  String _trimBody(String? responseBody, {int maxLength = 300}) {
    if (responseBody == null) {
      return '';
    }
    final sanitized = responseBody.replaceAll('\n', ' ').trim();
    if (sanitized.isEmpty) {
      return '';
    }
    if (sanitized.length <= maxLength) {
      return sanitized;
    }
    return '${sanitized.substring(0, maxLength)}…';
  }
}
