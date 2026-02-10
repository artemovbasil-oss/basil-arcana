import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/config/diagnostics.dart';
import '../core/telegram/telegram_env.dart';
import '../core/utils/local_reading_builder.dart';
import '../data/models/ai_result_model.dart';
import '../data/models/card_model.dart';
import '../data/models/drawn_card_model.dart';
import '../data/models/reading_model.dart';
import '../data/models/spread_model.dart';
import '../data/models/app_enums.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/readings_repository.dart';
import 'providers.dart';

enum DetailsStatus { idle, loading, success, error }

class ReadingFlowState {
  final String question;
  final SpreadModel? spread;
  final SpreadType? spreadType;
  final List<DrawnCardModel> drawnCards;
  final AiResultModel? aiResult;
  final AiResultModel? deepResult;
  final DetailsStatus detailsStatus;
  final String? detailsText;
  final String? detailsError;
  final bool showDetailsCta;
  final bool isLoading;
  final bool isDeepLoading;
  final String? errorMessage;
  final String? deepErrorMessage;
  final bool aiUsed;
  final bool requiresTelegram;
  final bool isSaved;
  final AiErrorType? aiErrorType;
  final AiErrorType? deepErrorType;
  final int? aiErrorStatusCode;
  final int? deepErrorStatusCode;

  const ReadingFlowState({
    required this.question,
    required this.spread,
    required this.spreadType,
    required this.drawnCards,
    required this.aiResult,
    required this.deepResult,
    required this.detailsStatus,
    required this.detailsText,
    required this.detailsError,
    required this.showDetailsCta,
    required this.isLoading,
    required this.isDeepLoading,
    required this.errorMessage,
    required this.deepErrorMessage,
    required this.aiUsed,
    required this.requiresTelegram,
    required this.isSaved,
    required this.aiErrorType,
    required this.deepErrorType,
    required this.aiErrorStatusCode,
    required this.deepErrorStatusCode,
  });

  factory ReadingFlowState.initial() {
    return const ReadingFlowState(
      question: '',
      spread: null,
      spreadType: null,
      drawnCards: [],
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      isLoading: false,
      isDeepLoading: false,
      errorMessage: null,
      deepErrorMessage: null,
      aiUsed: true,
      requiresTelegram: false,
      isSaved: false,
      aiErrorType: null,
      deepErrorType: null,
      aiErrorStatusCode: null,
      deepErrorStatusCode: null,
    );
  }

  ReadingFlowState copyWith({
    String? question,
    SpreadModel? spread,
    SpreadType? spreadType,
    List<DrawnCardModel>? drawnCards,
    AiResultModel? aiResult,
    AiResultModel? deepResult,
    DetailsStatus? detailsStatus,
    String? detailsText,
    String? detailsError,
    bool? showDetailsCta,
    bool? isLoading,
    bool? isDeepLoading,
    String? errorMessage,
    String? deepErrorMessage,
    bool? aiUsed,
    bool? requiresTelegram,
    bool? isSaved,
    AiErrorType? aiErrorType,
    AiErrorType? deepErrorType,
    int? aiErrorStatusCode,
    int? deepErrorStatusCode,
    bool clearError = false,
    bool clearDeepError = false,
  }) {
    return ReadingFlowState(
      question: question ?? this.question,
      spread: spread ?? this.spread,
      spreadType: spreadType ?? this.spreadType,
      drawnCards: drawnCards ?? this.drawnCards,
      aiResult: aiResult ?? this.aiResult,
      deepResult: deepResult ?? this.deepResult,
      detailsStatus: detailsStatus ?? this.detailsStatus,
      detailsText: detailsText ?? this.detailsText,
      detailsError: detailsError ?? this.detailsError,
      showDetailsCta: showDetailsCta ?? this.showDetailsCta,
      isLoading: isLoading ?? this.isLoading,
      isDeepLoading: isDeepLoading ?? this.isDeepLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      deepErrorMessage:
          clearDeepError ? null : (deepErrorMessage ?? this.deepErrorMessage),
      aiUsed: aiUsed ?? this.aiUsed,
      requiresTelegram: requiresTelegram ?? this.requiresTelegram,
      isSaved: isSaved ?? this.isSaved,
      aiErrorType: clearError ? null : (aiErrorType ?? this.aiErrorType),
      deepErrorType:
          clearDeepError ? null : (deepErrorType ?? this.deepErrorType),
      aiErrorStatusCode:
          clearError ? null : (aiErrorStatusCode ?? this.aiErrorStatusCode),
      deepErrorStatusCode: clearDeepError
          ? null
          : (deepErrorStatusCode ?? this.deepErrorStatusCode),
    );
  }
}

class ReadingFlowController extends StateNotifier<ReadingFlowState> {
  ReadingFlowController(this.ref) : super(ReadingFlowState.initial());

  final Ref ref;
  final LocalReadingBuilder _localReadingBuilder = const LocalReadingBuilder();
  http.Client? _activeClient;
  int _requestCounter = 0;
  int _activeRequestId = 0;
  http.Client? _activeDeepClient;
  int _deepRequestCounter = 0;
  int _activeDeepRequestId = 0;

  void _logStateTransition(String label, ReadingFlowState nextState) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[ReadingFlow] state:$label '
      'loading=${nextState.isLoading} '
      'hasResult=${nextState.aiResult != null} '
      "errorType=${nextState.aiErrorType?.name ?? 'none'} "
      'requiresTelegram=${nextState.requiresTelegram}',
    );
  }

  Future<bool> _ensureTelegramInitData() async {
    if (!kIsWeb) {
      return true;
    }
    final telegramEnv = TelegramEnv.instance;
    if (!telegramEnv.isTelegram) {
      return true;
    }
    final initData = await telegramEnv.ensureInitData();
    if (initData.trim().isEmpty && kDebugMode) {
      debugPrint(
        '[ReadingFlow] Telegram initData still empty after retry.',
      );
    }
    return initData.trim().isNotEmpty;
  }

  void setQuestion(String question) {
    state = state.copyWith(question: question, clearError: true);
  }

  void selectSpread(SpreadModel spread, SpreadType spreadType) {
    final normalizedSpread = _normalizeSpread(spread, spreadType);
    state = state.copyWith(
      spread: normalizedSpread,
      spreadType: spreadType,
      drawnCards: [],
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      isDeepLoading: false,
      requiresTelegram: false,
      isSaved: false,
      deepErrorType: null,
      deepErrorMessage: null,
      clearDeepError: true,
    );
  }

  void reset() {
    state = ReadingFlowState.initial();
  }

  void cancelGeneration() {
    _activeRequestId = ++_requestCounter;
    _activeClient?.close();
    _activeClient = null;
    state = state.copyWith(
      isLoading: false,
      aiResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      requiresTelegram: false,
      clearError: true,
    );
  }

  void cancelDeepReading() {
    _activeDeepRequestId = ++_deepRequestCounter;
    _activeDeepClient?.close();
    _activeDeepClient = null;
    state = state.copyWith(
      isDeepLoading: false,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      clearDeepError: true,
    );
  }

  List<CardModel> drawCards(int count, List<CardModel> deck) {
    final rng = Random();
    final shuffled = [...deck]..shuffle(rng);
    return shuffled.take(count).toList();
  }

  Future<void> drawAndGenerate(List<CardModel> cards) async {
    final spread = state.spread;
    if (spread == null) {
      return;
    }
    state = state.copyWith(isSaved: false);

    final drawn = drawCards(spread.positions.length, cards);
    final drawnCards = <DrawnCardModel>[];
    for (var i = 0; i < spread.positions.length; i++) {
      final position = spread.positions[i];
      final card = drawn[i];
      drawnCards.add(
        DrawnCardModel(
          positionId: position.id,
          positionTitle: position.title,
          cardId: card.id,
          cardName: card.name,
          keywords: card.keywords,
          meaning: card.meaning,
        ),
      );
    }

    state = state.copyWith(
      drawnCards: drawnCards,
      isLoading: true,
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      isDeepLoading: false,
      requiresTelegram: false,
      clearDeepError: true,
      clearError: true,
    );
    _logStateTransition('idle->generating', state);

    try {
      await _generateReading(spread: spread, drawnCards: drawnCards);
    } catch (error) {
      if (kDebugMode) {
        final message = error.toString();
        debugPrint(
          '[ReadingFlow] drawAndGenerate unexpected error '
          'bodyPreview="${message.substring(0, min(200, message.length))}"',
        );
      }
      await _useOfflineFallback(
        spread: spread,
        drawnCards: drawnCards,
        errorType: AiErrorType.serverError,
        errorMessage: 'AI temporarily unavailable — showing base interpretation',
        logLabel: 'generating->done(local-fallback:top-level)',
      );
    }
  }

  AppLocalizations _l10n() {
    final locale = ref.read(localeProvider);
    return lookupAppLocalizations(locale);
  }

  String _messageForError(AiRepositoryException error, AppLocalizations l10n) {
    switch (error.type) {
      case AiErrorType.misconfigured:
        return l10n.resultStatusMissingApiBaseUrl;
      case AiErrorType.unauthorized:
        return l10n.resultStatusServerUnavailable;
      case AiErrorType.rateLimited:
        return l10n.resultStatusTooManyAttempts;
      case AiErrorType.noInternet:
        return l10n.resultStatusNoInternet;
      case AiErrorType.timeout:
        return l10n.resultStatusTimeout;
      case AiErrorType.serverError:
        if (error.statusCode != null) {
          return l10n.resultStatusServerUnavailableWithStatus(
            error.statusCode!,
          );
        }
        return l10n.resultStatusServerUnavailable;
      case AiErrorType.badResponse:
        return l10n.resultStatusUnexpectedResponse;
    }
  }

  Future<void> retryGenerate() async {
    final spread = state.spread;
    if (spread == null || state.drawnCards.isEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      clearError: true,
    );

    await _generateReading(
      spread: spread,
      drawnCards: state.drawnCards,
    );
  }

  Future<void> _generateReading({
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
  }) async {
    final localResult = _localReadingBuilder.build(
      question: state.question,
      spread: spread,
      spreadType: state.spreadType ?? SpreadType.one,
      drawnCards: drawnCards,
    );

    state = state.copyWith(
      aiResult: localResult,
      isLoading: true,
      aiUsed: false,
      showDetailsCta: true,
      requiresTelegram: false,
      clearError: true,
    );

    final requestId = ++_requestCounter;
    _activeRequestId = requestId;
    final client = http.Client();
    _activeClient?.close();
    _activeClient = client;
    try {
      final aiRepository = ref.read(aiRepositoryProvider);
      final locale = ref.read(localeProvider);
      final result = await aiRepository.generateReading(
        question: state.question,
        spread: spread,
        drawnCards: drawnCards,
        languageCode: locale.languageCode,
        mode: ReadingMode.fast,
        client: client,
        timeout: const Duration(seconds: 12),
      );
      if (_activeRequestId != requestId) {
        return;
      }
      if (!_hasDisplayableResult(result)) {
        if (kDebugMode) {
          debugPrint(
            '[ReadingFlow] generateReading invalid payload '
            'status=200 bodyPreview="<parsed-empty-payload>"',
          );
        }
        await _useOfflineFallback(
          spread: spread,
          drawnCards: drawnCards,
          errorType: AiErrorType.badResponse,
          errorMessage:
              'AI temporarily unavailable — showing base interpretation',
          logLabel: 'generating->done(local-fallback:invalid-response)',
        );
        return;
      }
      state = state.copyWith(
        aiResult: result,
        isLoading: false,
        aiUsed: true,
        showDetailsCta: true,
        requiresTelegram: false,
        clearError: true,
      );
      _logStateTransition('generating->done', state);
      await _runPostGenerationSideEffects(drawnCards);
    } on AiRepositoryException catch (error) {
      if (_activeRequestId != requestId) {
        return;
      }
      _logAiFailure(error);
      if (kEnableDevDiagnostics) {
        logDevFailure(buildDevFailureInfo(FailedStage.openaiCall, error));
      }
      await _useOfflineFallback(
        spread: spread,
        drawnCards: drawnCards,
        errorType: error.type,
        errorStatusCode: error.statusCode,
        errorMessage:
            'AI temporarily unavailable — showing base interpretation',
        logLabel: 'generating->done(local-fallback:error)',
      );
    } catch (error) {
      if (_activeRequestId != requestId) {
        return;
      }
      if (kDebugMode) {
        debugPrint(
          '[ReadingFlow] generateReading unexpected error '
          'status=n/a bodyPreview="${error.toString().substring(0, min(200, error.toString().length))}"',
        );
      }
      if (kEnableDevDiagnostics) {
        logDevFailure(buildDevFailureInfo(FailedStage.openaiCall, error));
      }
      await _useOfflineFallback(
        spread: spread,
        drawnCards: drawnCards,
        errorType: AiErrorType.serverError,
        errorMessage:
            'AI temporarily unavailable — showing base interpretation',
        logLabel: 'generating->done(local-fallback:unknown)',
      );
    } finally {
      if (_activeRequestId == requestId && state.isLoading) {
        await _useOfflineFallback(
          spread: spread,
          drawnCards: drawnCards,
          errorType: AiErrorType.serverError,
          errorMessage:
              'AI temporarily unavailable — showing base interpretation',
          logLabel: 'generating->done(local-fallback:safety-net)',
        );
      }
      if (_activeClient == client) {
        _activeClient = null;
      }
      client.close();
    }
  }

  bool _hasDisplayableResult(AiResultModel result) {
    return result.tldr.trim().isNotEmpty ||
        result.sections.isNotEmpty ||
        result.why.trim().isNotEmpty ||
        result.action.trim().isNotEmpty ||
        result.fullText.trim().isNotEmpty;
  }

  void _logAiFailure(AiRepositoryException error) {
    if (!kDebugMode) {
      return;
    }
    final responsePreview = (error.responseBody ?? '').trim();
    final bodySnippet = responsePreview.isEmpty
        ? '<empty>'
        : responsePreview.substring(0, min(200, responsePreview.length));
    debugPrint(
      '[ReadingFlow] generateReading failed '
      'status=${error.statusCode ?? 'n/a'} '
      'bodyPreview="$bodySnippet"',
    );
  }

  Future<void> _useOfflineFallback({
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
    required AiErrorType errorType,
    int? errorStatusCode,
    required String errorMessage,
    required String logLabel,
  }) async {
    final fallbackResult = _offlineFallback(spread, drawnCards, _l10n());
    state = state.copyWith(
      aiResult: fallbackResult,
      isLoading: false,
      aiUsed: false,
      showDetailsCta: true,
      requiresTelegram: false,
      aiErrorType: errorType,
      aiErrorStatusCode: errorStatusCode,
      errorMessage: errorMessage,
    );
    _logStateTransition(logLabel, state);
    await _runPostGenerationSideEffects(drawnCards);
  }

  Future<void> _runPostGenerationSideEffects(
    List<DrawnCardModel> drawnCards,
  ) async {
    try {
      await _incrementCardStats(drawnCards);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ReadingFlow] incrementCardStats failed: $error');
      }
    }
    try {
      await _autoSaveReading();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ReadingFlow] autoSaveReading failed: $error');
      }
    }
  }

  Future<void> _autoSaveReading() async {
    if (state.isSaved) {
      return;
    }
    await saveReading();
  }

  Future<void> requestDetails() async {
    final spread = state.spread;
    if (spread == null ||
        state.drawnCards.isEmpty ||
        state.detailsStatus == DetailsStatus.loading) {
      return;
    }

    final hasTelegramInitData = await _ensureTelegramInitData();
    if (kIsWeb &&
        TelegramEnv.instance.isTelegram &&
        !hasTelegramInitData) {
      state = state.copyWith(
        detailsStatus: DetailsStatus.error,
        detailsText: null,
        detailsError: null,
        requiresTelegram: true,
      );
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[ReadingFlow] detailsRequest:tap status=${state.detailsStatus.name} '
        'showCta=${state.showDetailsCta}',
      );
    }

    state = state.copyWith(
      showDetailsCta: false,
      detailsStatus: DetailsStatus.loading,
      detailsText: null,
      detailsError: null,
    );

    if (kDebugMode) {
      debugPrint('[ReadingFlow] detailsStatus:loading');
    }

    final requestId = ++_deepRequestCounter;
    _activeDeepRequestId = requestId;
    final started = DateTime.now();
    final client = http.Client();
    _activeDeepClient?.close();
    _activeDeepClient = client;
    debugPrint('[ReadingFlow] detailsRequest:sent id=$requestId');
    try {
      final aiRepository = ref.read(aiRepositoryProvider);
      final locale = ref.read(localeProvider);
      final detailsText = await aiRepository.fetchReadingDetails(
        question: state.question,
        spread: spread,
        drawnCards: state.drawnCards,
        locale: locale.languageCode,
        client: client,
        timeout: const Duration(seconds: 35),
      );
      if (_activeDeepRequestId != requestId) {
        return;
      }
      final trimmed = detailsText?.trim() ?? '';
      if (trimmed.isEmpty) {
        final message = _l10n().resultStatusUnexpectedResponse;
        state = state.copyWith(
          detailsStatus: DetailsStatus.error,
          detailsText: null,
          detailsError: message,
        );
        return;
      }
      debugPrint(
        '[ReadingFlow] detailsResponse:received id=$requestId '
        'chars=${trimmed.length}',
      );
      state = state.copyWith(
        detailsStatus: DetailsStatus.success,
        detailsText: trimmed,
        detailsError: null,
      );
    } on AiRepositoryException catch (error) {
      if (_activeDeepRequestId != requestId) {
        return;
      }
      if (kEnableDevDiagnostics) {
        logDevFailure(buildDevFailureInfo(FailedStage.openaiCall, error));
      }
      debugPrint(
        '[ReadingFlow] detailsResponse:error id=$requestId type=${error.type.name}',
      );
      final message = _messageForError(error, _l10n());
      state = state.copyWith(
        detailsStatus: DetailsStatus.error,
        detailsText: null,
        detailsError: message,
      );
    } catch (error) {
      if (_activeDeepRequestId != requestId) {
        return;
      }
      if (kEnableDevDiagnostics) {
        logDevFailure(buildDevFailureInfo(FailedStage.openaiCall, error));
      }
      debugPrint('[ReadingFlow] detailsResponse:error id=$requestId');
      final message = _l10n().resultStatusServerUnavailable;
      state = state.copyWith(
        detailsStatus: DetailsStatus.error,
        detailsText: null,
        detailsError: message,
      );
    } finally {
      if (_activeDeepClient == client) {
        _activeDeepClient = null;
      }
      debugPrint(
        '[details] done in ${DateTime.now().difference(started).inMilliseconds}ms '
        'status=${state.detailsStatus}',
      );
      client.close();
    }
  }

  Future<void> tryAgainDetails() async {
    await requestDetails();
  }

  void dismissDetails() {
    state = state.copyWith(
      showDetailsCta: false,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
    );
  }

  Future<bool> saveReading() async {
    final spread = state.spread;
    final aiResult = state.deepResult ?? state.aiResult;
    if (spread == null || state.drawnCards.isEmpty) {
      return false;
    }
    final resolvedResult =
        aiResult ?? _offlineFallback(spread, state.drawnCards, _l10n());

    final readingsRepository = ref.read(readingsRepositoryProvider);
    final reading = ReadingModel(
      readingId: const Uuid().v4(),
      createdAt: DateTime.now(),
      question: state.question,
      spreadId: spread.id,
      spreadName: spread.name,
      drawnCards: state.drawnCards,
      tldr: resolvedResult.tldr,
      sections: resolvedResult.sections,
      why: resolvedResult.why,
      action: resolvedResult.action,
      fullText: resolvedResult.fullText,
      aiUsed: aiResult != null && state.aiUsed,
      requestId: aiResult?.requestId,
    );
    await readingsRepository.saveReading(reading);
    state = state.copyWith(isSaved: true);
    return true;
  }

  Future<void> runSmokeTest() async {
    final aiRepository = ref.read(aiRepositoryProvider);
    final locale = ref.read(localeProvider);
    await aiRepository.smokeTest(languageCode: locale.languageCode);
  }

  Future<void> _incrementCardStats(List<DrawnCardModel> drawnCards) async {
    final statsRepository = ref.read(cardStatsRepositoryProvider);
    for (final drawn in drawnCards) {
      await statsRepository.increment(drawn.cardId);
    }
  }

  AiResultModel _offlineFallback(
    SpreadModel spread,
    List<DrawnCardModel> drawnCards,
    AppLocalizations l10n,
  ) {
    final focus = state.question.trim().isEmpty
        ? l10n.offlineFallbackReflection
        : state.question.trim();

    final keywordPool = drawnCards
        .expand((card) => card.keywords)
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
    final keywordSummary = keywordPool.isNotEmpty
        ? keywordPool.join(', ')
        : drawnCards.map((card) => card.cardName).join(', ');

    final tldr = l10n.offlineFallbackSummary(focus, keywordSummary);

    final sections = <AiSectionModel>[];
    for (final drawn in drawnCards) {
      final baseMeaning = drawn.meaning.general.trim().isNotEmpty
          ? drawn.meaning.general.trim()
          : drawn.meaning.light.trim().isNotEmpty
              ? drawn.meaning.light.trim()
              : drawn.keywords.take(3).join(', ');
      final advice = drawn.meaning.advice.trim();
      final sectionText = advice.isNotEmpty
          ? '$baseMeaning ${l10n.offlineFallbackAdviceLabel(advice)}'
          : baseMeaning;
      sections.add(
        AiSectionModel(
          positionId: drawn.positionId,
          title: drawn.positionTitle,
          text: sectionText,
        ),
      );
    }

    final positionTitles = spread.positions
        .map((position) => position.title.trim())
        .where((title) => title.isNotEmpty)
        .join(', ');
    final why = positionTitles.isNotEmpty
        ? '${l10n.offlineFallbackWhy} ($positionTitles)'
        : l10n.offlineFallbackWhy;
    final action = l10n.offlineFallbackAction;
    final fullText = [
      tldr,
      ...sections.map((section) => '${section.title}: ${section.text}'),
      why,
      action,
    ].where((line) => line.trim().isNotEmpty).join('\n\n');

    return AiResultModel(
      tldr: tldr,
      sections: sections,
      why: why,
      action: action,
      fullText: fullText,
      detailsText: '',
      requestId: null,
    );
  }

  SpreadModel _normalizeSpread(SpreadModel spread, SpreadType spreadType) {
    final count = spreadType.cardCount;
    if (spread.positions.length == count) {
      return spread;
    }
    final positions = spread.positions.isNotEmpty
        ? spread.positions.take(count).toList()
        : [
            const SpreadPosition(id: 'focus', title: 'Focus'),
          ];
    return SpreadModel(
      id: spread.id,
      name: spread.name,
      positions: positions,
      cardsCount: count,
    );
  }
}
