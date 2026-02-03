import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../data/models/ai_result_model.dart';
import '../data/models/card_model.dart';
import '../data/models/drawn_card_model.dart';
import '../data/models/reading_model.dart';
import '../data/models/spread_model.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/readings_repository.dart';
import 'providers.dart';

enum DetailsStatus { idle, loading, success, error }

class ReadingFlowState {
  final String question;
  final SpreadModel? spread;
  final List<DrawnCardModel> drawnCards;
  final AiResultModel? aiResult;
  final AiResultModel? deepResult;
  final DetailsStatus detailsStatus;
  final String? detailsMessage;
  final bool isLoading;
  final bool isDeepLoading;
  final String? errorMessage;
  final String? deepErrorMessage;
  final bool aiUsed;
  final AiErrorType? aiErrorType;
  final AiErrorType? deepErrorType;
  final int? aiErrorStatusCode;
  final int? deepErrorStatusCode;

  const ReadingFlowState({
    required this.question,
    required this.spread,
    required this.drawnCards,
    required this.aiResult,
    required this.deepResult,
    required this.detailsStatus,
    required this.detailsMessage,
    required this.isLoading,
    required this.isDeepLoading,
    required this.errorMessage,
    required this.deepErrorMessage,
    required this.aiUsed,
    required this.aiErrorType,
    required this.deepErrorType,
    required this.aiErrorStatusCode,
    required this.deepErrorStatusCode,
  });

  factory ReadingFlowState.initial() {
    return const ReadingFlowState(
      question: '',
      spread: null,
      drawnCards: [],
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsMessage: null,
      isLoading: false,
      isDeepLoading: false,
      errorMessage: null,
      deepErrorMessage: null,
      aiUsed: true,
      aiErrorType: null,
      deepErrorType: null,
      aiErrorStatusCode: null,
      deepErrorStatusCode: null,
    );
  }

  ReadingFlowState copyWith({
    String? question,
    SpreadModel? spread,
    List<DrawnCardModel>? drawnCards,
    AiResultModel? aiResult,
    AiResultModel? deepResult,
    DetailsStatus? detailsStatus,
    String? detailsMessage,
    bool? isLoading,
    bool? isDeepLoading,
    String? errorMessage,
    String? deepErrorMessage,
    bool? aiUsed,
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
      drawnCards: drawnCards ?? this.drawnCards,
      aiResult: aiResult ?? this.aiResult,
      deepResult: deepResult ?? this.deepResult,
      detailsStatus: detailsStatus ?? this.detailsStatus,
      detailsMessage: detailsMessage ?? this.detailsMessage,
      isLoading: isLoading ?? this.isLoading,
      isDeepLoading: isDeepLoading ?? this.isDeepLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      deepErrorMessage:
          clearDeepError ? null : (deepErrorMessage ?? this.deepErrorMessage),
      aiUsed: aiUsed ?? this.aiUsed,
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

  void setQuestion(String question) {
    state = state.copyWith(question: question, clearError: true);
  }

  void selectSpread(SpreadModel spread) {
    state = state.copyWith(
      spread: spread,
      drawnCards: [],
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsMessage: null,
      isDeepLoading: false,
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
      detailsMessage: null,
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
      detailsMessage: null,
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

    state = state.copyWith(
      drawnCards: drawnCards,
      isLoading: true,
      aiResult: null,
      deepResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsMessage: null,
      isDeepLoading: false,
      clearDeepError: true,
      clearError: true,
    );

    await _generateReading(spread: spread, drawnCards: drawnCards, l10n: l10n);
  }

  AppLocalizations _l10n() {
    final locale = ref.read(localeProvider);
    return lookupAppLocalizations(locale);
  }

  String _messageForError(AiRepositoryException error, AppLocalizations l10n) {
    switch (error.type) {
      case AiErrorType.missingApiKey:
        return l10n.resultStatusMissingApiKey;
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
      requestId: null,
    );
  }

  Future<void> retryGenerate() async {
    final spread = state.spread;
    if (spread == null || state.drawnCards.isEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      aiResult: null,
      detailsStatus: DetailsStatus.idle,
      detailsMessage: null,
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
      );
      if (_activeRequestId != requestId) {
        return;
      }
      await _incrementCardStats(drawnCards);
      state = state.copyWith(
        aiResult: result,
        isLoading: false,
        aiUsed: true,
      );
    } on AiRepositoryException catch (error) {
      if (_activeRequestId != requestId) {
        return;
      }
      if (error.type == AiErrorType.noInternet) {
        final fallback = _offlineFallback(spread, drawnCards, l10n);
        await _incrementCardStats(drawnCards);
        state = state.copyWith(
          aiResult: fallback,
          isLoading: false,
          aiUsed: false,
          aiErrorType: error.type,
          aiErrorStatusCode: error.statusCode,
          errorMessage: _messageForError(error, l10n),
        );
        return;
      }

      state = state.copyWith(
        aiResult: null,
        isLoading: false,
        aiUsed: false,
        aiErrorType: error.type,
        aiErrorStatusCode: error.statusCode,
        errorMessage: _messageForError(error, l10n),
      );
    } catch (_) {
      if (_activeRequestId != requestId) {
        return;
      }
      state = state.copyWith(
        aiResult: null,
        isLoading: false,
        aiUsed: false,
        aiErrorType: AiErrorType.serverError,
        errorMessage: l10n.resultStatusServerUnavailable,
      );
    } finally {
      if (_activeClient == client) {
        _activeClient = null;
      }
      client.close();
    }
  }

  Future<void> requestDeepReading() async {
    final spread = state.spread;
    final aiResult = state.aiResult;
    if (spread == null ||
        aiResult == null ||
        state.drawnCards.isEmpty ||
        state.detailsStatus == DetailsStatus.loading) {
      return;
    }

    state = state.copyWith(
      isDeepLoading: true,
      deepResult: null,
      detailsStatus: DetailsStatus.loading,
      detailsMessage: null,
      clearDeepError: true,
    );

    await _generateDeepReading(
      spread: spread,
      drawnCards: state.drawnCards,
      l10n: _l10n(),
      fastReading: {
        'tldr': aiResult.tldr,
        'sections': aiResult.sections
            .map((section) => section.toJson())
            .toList(),
        'action': aiResult.action,
      },
    );
  }

  Future<void> _generateDeepReading({
    required SpreadModel spread,
    required List<DrawnCardModel> drawnCards,
    required AppLocalizations l10n,
    Map<String, dynamic>? fastReading,
  }) async {
    final requestId = ++_deepRequestCounter;
    _activeDeepRequestId = requestId;
    final detailsRequestId = 'details-${const Uuid().v4()}';
    final client = http.Client();
    _activeDeepClient?.close();
    _activeDeepClient = client;
    try {
      if (kDebugMode) {
        debugPrint(
          '[ReadingFlow] detailsRequest:start id=$requestId '
          'requestId=$detailsRequestId',
        );
      }
      final aiRepository = ref.read(aiRepositoryProvider);
      final locale = ref.read(localeProvider);
      final result = await aiRepository.generateReading(
        question: state.question,
        spread: spread,
        drawnCards: drawnCards,
        languageCode: locale.languageCode,
        mode: ReadingMode.detailsRelationshipsCareer,
        fastReading: fastReading,
        client: client,
        timeout: const Duration(seconds: 30),
        requestIdOverride: detailsRequestId,
      );
      if (_activeDeepRequestId != requestId) {
        return;
      }
      state = state.copyWith(
        deepResult: result,
        isDeepLoading: false,
        detailsStatus: DetailsStatus.success,
        detailsMessage: _buildDetailsMessage(result, l10n),
      );
      if (kDebugMode) {
        debugPrint(
          '[ReadingFlow] detailsRequest:success id=$requestId '
          'requestId=${result.requestId ?? detailsRequestId}',
        );
      }
    } on AiRepositoryException catch (error) {
      if (_activeDeepRequestId != requestId) {
        return;
      }
      final message = _messageForError(error, l10n);
      state = state.copyWith(
        deepResult: null,
        isDeepLoading: false,
        deepErrorType: error.type,
        deepErrorStatusCode: error.statusCode,
        deepErrorMessage: message,
        detailsStatus: DetailsStatus.error,
        detailsMessage: message,
      );
      if (kDebugMode) {
        debugPrint(
          '[ReadingFlow] detailsRequest:error id=$requestId '
          'type=${error.type.name} status=${error.statusCode ?? 'n/a'}',
        );
      }
    } catch (_) {
      if (_activeDeepRequestId != requestId) {
        return;
      }
      final message = l10n.resultStatusServerUnavailable;
      state = state.copyWith(
        deepResult: null,
        isDeepLoading: false,
        deepErrorType: AiErrorType.serverError,
        deepErrorMessage: message,
        detailsStatus: DetailsStatus.error,
        detailsMessage: message,
      );
      if (kDebugMode) {
        debugPrint(
          '[ReadingFlow] detailsRequest:error id=$requestId '
          'type=${AiErrorType.serverError.name}',
        );
      }
    } finally {
      if (_activeDeepClient == client) {
        _activeDeepClient = null;
      }
      if (kDebugMode) {
        debugPrint(
          '[ReadingFlow] detailsRequest:finish id=$requestId '
          'requestId=$detailsRequestId',
        );
      }
      client.close();
    }
  }

  String _buildDetailsMessage(AiResultModel result, AppLocalizations l10n) {
    final sections = result.sections;
    String pickSectionText(int index) {
      if (index < sections.length) {
        final text = sections[index].text.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
      final full = result.fullText.trim();
      if (full.isNotEmpty) {
        return full;
      }
      return result.tldr.trim();
    }

    final relationshipsText = pickSectionText(0);
    final careerText = pickSectionText(1);
    return [
      l10n.resultDeepRelationshipsHeading,
      relationshipsText,
      '',
      l10n.resultDeepCareerHeading,
      careerText,
    ].join('\n');
  }

  Future<void> saveReading() async {
    final spread = state.spread;
    final aiResult = state.deepResult ?? state.aiResult;
    if (spread == null || aiResult == null) {
      return;
    }

    final readingsRepository = ref.read(readingsRepositoryProvider);
    final reading = ReadingModel(
      readingId: const Uuid().v4(),
      createdAt: DateTime.now(),
      question: state.question,
      spreadId: spread.id,
      spreadName: spread.name,
      drawnCards: state.drawnCards,
      tldr: aiResult.tldr,
      sections: aiResult.sections,
      why: aiResult.why,
      action: aiResult.action,
      fullText: aiResult.fullText,
      aiUsed: state.aiUsed,
      requestId: aiResult.requestId,
    );
    await readingsRepository.saveReading(reading);
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
}
