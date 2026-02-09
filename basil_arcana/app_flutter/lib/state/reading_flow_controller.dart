import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/telegram/telegram_env.dart';
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
  http.Client? _activeClient;
  int _requestCounter = 0;
  int _activeRequestId = 0;
  http.Client? _activeDeepClient;
  int _deepRequestCounter = 0;
  int _activeDeepRequestId = 0;

  bool _requiresTelegramAccess() {
    if (!kIsWeb) {
      return false;
    }
    return !TelegramEnv.instance.isTelegram;
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
    final l10n = _l10n();

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

    final requiresTelegram = _requiresTelegramAccess();
    state = state.copyWith(
      drawnCards: drawnCards,
      isLoading: !requiresTelegram,
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      isDeepLoading: false,
      requiresTelegram: requiresTelegram,
      clearDeepError: true,
      clearError: true,
    );

    if (requiresTelegram) {
      await _autoSaveReading();
      return;
    }
    await _generateReading(spread: spread, drawnCards: drawnCards, l10n: l10n);
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

  AiResultModel _offlineFallback(
    SpreadModel spread,
    List<DrawnCardModel> drawnCards,
    AppLocalizations l10n,
  ) {
    final tldrKeywords = drawnCards.isNotEmpty
        ? drawnCards.first.keywords.join(', ')
        : l10n.offlineFallbackReflection;
    final tldr = l10n.offlineFallbackSummary(
      state.question,
      tldrKeywords,
    );

    final sections = drawnCards.map((drawn) {
      final general = drawn.meaning.general;
      final advice = drawn.meaning.advice;
      final adviceText = advice.isNotEmpty
          ? l10n.offlineFallbackAdviceLabel(advice)
          : '';
      final text =
          '${drawn.positionTitle}: $general ${adviceText.isNotEmpty ? adviceText : ''}';
      return AiSectionModel(
        positionId: drawn.positionId,
        title: drawn.positionTitle,
        text: text.trim(),
      );
    }).toList();

    final why = l10n.offlineFallbackWhy;
    final action = drawnCards
        .map((drawn) {
          return drawn.meaning.advice;
        })
        .where((advice) => advice.isNotEmpty)
        .take(2)
        .join(' ');

    final fullText = [
      tldr,
      ...sections.map((section) => section.text),
      why,
      action,
    ].join('\n\n');

    return AiResultModel(
      tldr: tldr,
      sections: sections,
      why: why,
      action: action.isEmpty
          ? l10n.offlineFallbackAction
          : action,
      fullText: fullText,
      detailsText: '',
      requestId: null,
    );
  }

  Future<void> retryGenerate() async {
    final spread = state.spread;
    if (spread == null || state.drawnCards.isEmpty) {
      return;
    }

    if (_requiresTelegramAccess()) {
      state = state.copyWith(
        isLoading: false,
        aiResult: null,
        detailsStatus: DetailsStatus.idle,
        detailsText: null,
        detailsError: null,
        showDetailsCta: false,
        requiresTelegram: true,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      aiResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsText: null,
      detailsError: null,
      showDetailsCta: false,
      clearError: true,
    );

    await _generateReading(
      spread: spread,
      drawnCards: state.drawnCards,
      l10n: _l10n(),
    );
  }

  Future<void> _generateReading({
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
    required AppLocalizations l10n,
  }) async {
    if (_requiresTelegramAccess()) {
      state = state.copyWith(
        aiResult: null,
        isLoading: false,
        aiUsed: false,
        showDetailsCta: false,
        requiresTelegram: true,
        clearError: true,
      );
      return;
    }
    final requestId = ++_requestCounter;
    _activeRequestId = requestId;
    final client = http.Client();
    _activeClient?.close();
    _activeClient = client;
    try {
      final aiRepository = ref.read(aiRepositoryProvider);
      var backendAvailable = true;
      try {
        backendAvailable =
            await aiRepository.isBackendAvailable(client: client);
      } on AiRepositoryException catch (error) {
        if (_activeRequestId != requestId) {
          return;
        }
        if (kDebugMode) {
          debugPrint(
            '[ReadingFlow] availabilityCheckSkipped type=${error.type.name}',
          );
        }
      }
      if (_activeRequestId != requestId) {
        return;
      }
      if (!backendAvailable && kDebugMode) {
        debugPrint('[ReadingFlow] availabilityCheckFalse');
      }
      final locale = ref.read(localeProvider);
      final result = await aiRepository.generateReading(
        question: state.question,
        spread: spread,
        drawnCards: drawnCards,
        languageCode: locale.languageCode,
        mode: ReadingMode.fast,
        client: client,
      );
      if (_activeRequestId != requestId) {
        return;
      }
      await _incrementCardStats(drawnCards);
      state = state.copyWith(
        aiResult: result,
        isLoading: false,
        aiUsed: true,
        showDetailsCta: true,
        clearError: true,
      );
      await _autoSaveReading();
    } on AiRepositoryException catch (error) {
      if (_activeRequestId != requestId) {
        return;
      }
      final shouldFallback = error.type != AiErrorType.unauthorized;
      if (shouldFallback) {
        final fallback = _offlineFallback(spread, drawnCards, l10n);
        await _incrementCardStats(drawnCards);
        state = state.copyWith(
          aiResult: fallback,
          isLoading: false,
          aiUsed: false,
          showDetailsCta: true,
          aiErrorType: error.type,
          aiErrorStatusCode: error.statusCode,
          errorMessage: _messageForError(error, l10n),
        );
        await _autoSaveReading();
        return;
      }

      state = state.copyWith(
        aiResult: null,
        isLoading: false,
        aiUsed: false,
        showDetailsCta: false,
        aiErrorType: error.type,
        aiErrorStatusCode: error.statusCode,
        errorMessage: _messageForError(error, l10n),
      );
      await _autoSaveReading();
    } catch (_) {
      if (_activeRequestId != requestId) {
        return;
      }
      state = state.copyWith(
        aiResult: null,
        isLoading: false,
        aiUsed: false,
        showDetailsCta: false,
        aiErrorType: AiErrorType.serverError,
        errorMessage: l10n.resultStatusServerUnavailable,
      );
      await _autoSaveReading();
    } finally {
      if (_activeClient == client) {
        _activeClient = null;
      }
      client.close();
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
      debugPrint(
        '[ReadingFlow] detailsResponse:error id=$requestId type=${error.type.name}',
      );
      final message = _messageForError(error, _l10n());
      state = state.copyWith(
        detailsStatus: DetailsStatus.error,
        detailsText: null,
        detailsError: message,
      );
    } catch (_) {
      if (_activeDeepRequestId != requestId) {
        return;
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
