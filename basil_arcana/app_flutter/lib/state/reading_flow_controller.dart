import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/ai_result_model.dart';
import '../data/models/card_model.dart';
import '../data/models/drawn_card_model.dart';
import '../data/models/reading_model.dart';
import '../data/models/spread_model.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/readings_repository.dart';
import 'providers.dart';

class ReadingFlowState {
  final String question;
  final SpreadModel? spread;
  final List<DrawnCardModel> drawnCards;
  final AiResultModel? aiResult;
  final bool isLoading;
  final String? errorMessage;
  final bool aiUsed;
  final AiErrorType? aiErrorType;
  final int? aiErrorStatusCode;

  const ReadingFlowState({
    required this.question,
    required this.spread,
    required this.drawnCards,
    required this.aiResult,
    required this.isLoading,
    required this.errorMessage,
    required this.aiUsed,
    required this.aiErrorType,
    required this.aiErrorStatusCode,
  });

  factory ReadingFlowState.initial() {
    return const ReadingFlowState(
      question: '',
      spread: null,
      drawnCards: [],
      aiResult: null,
      isLoading: false,
      errorMessage: null,
      aiUsed: true,
      aiErrorType: null,
      aiErrorStatusCode: null,
    );
  }

  ReadingFlowState copyWith({
    String? question,
    SpreadModel? spread,
    List<DrawnCardModel>? drawnCards,
    AiResultModel? aiResult,
    bool? isLoading,
    String? errorMessage,
    bool? aiUsed,
    AiErrorType? aiErrorType,
    int? aiErrorStatusCode,
    bool clearError = false,
  }) {
    return ReadingFlowState(
      question: question ?? this.question,
      spread: spread ?? this.spread,
      drawnCards: drawnCards ?? this.drawnCards,
      aiResult: aiResult ?? this.aiResult,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      aiUsed: aiUsed ?? this.aiUsed,
      aiErrorType: clearError ? null : (aiErrorType ?? this.aiErrorType),
      aiErrorStatusCode:
          clearError ? null : (aiErrorStatusCode ?? this.aiErrorStatusCode),
    );
  }
}

class ReadingFlowController extends StateNotifier<ReadingFlowState> {
  ReadingFlowController(this.ref) : super(ReadingFlowState.initial());

  final Ref ref;

  void setQuestion(String question) {
    state = state.copyWith(question: question, clearError: true);
  }

  void selectSpread(SpreadModel spread) {
    state = state.copyWith(spread: spread, drawnCards: [], aiResult: null);
  }

  void reset() {
    state = ReadingFlowState.initial();
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
      clearError: true,
    );

    try {
      final aiRepository = ref.read(aiRepositoryProvider);
      final result = await aiRepository.generateReading(
        question: state.question,
        spread: spread,
        drawnCards: drawnCards,
      );
      state = state.copyWith(
        aiResult: result,
        isLoading: false,
        aiUsed: true,
      );
    } on AiRepositoryException catch (error) {
      final fallback = _offlineFallback(spread, drawnCards);
      state = state.copyWith(
        aiResult: fallback,
        isLoading: false,
        aiUsed: false,
        aiErrorType: error.type,
        aiErrorStatusCode: error.statusCode,
        errorMessage: _messageForError(error),
      );
    } catch (_) {
      final fallback = _offlineFallback(spread, drawnCards);
      state = state.copyWith(
        aiResult: fallback,
        isLoading: false,
        aiUsed: false,
        aiErrorType: AiErrorType.serverError,
        errorMessage: 'Server unavailable — showing offline reading',
      );
    }
  }

  String _messageForError(AiRepositoryException error) {
    switch (error.type) {
      case AiErrorType.missingApiKey:
        return 'AI disabled — API key not included in this build';
      case AiErrorType.unauthorized:
        return 'Unauthorized — check API key';
      case AiErrorType.noInternet:
        return 'No internet — showing offline reading';
      case AiErrorType.timeout:
        return 'Request timed out — showing offline reading';
      case AiErrorType.serverError:
        if (error.statusCode != null) {
          return 'Server unavailable (${error.statusCode}) — showing offline reading';
        }
        return 'Server unavailable — showing offline reading';
    }
  }

  AiResultModel _offlineFallback(
    SpreadModel spread,
    List<DrawnCardModel> drawnCards,
  ) {
    final tldrKeywords = drawnCards.isNotEmpty
        ? drawnCards.first.keywords.join(', ')
        : 'reflection';
    final tldr =
        'For “${state.question}”, the reading centers on $tldrKeywords.';

    final sections = drawnCards.map((drawn) {
      final general = drawn.meaning.general;
      final advice = drawn.meaning.advice;
      final text =
          '${drawn.positionTitle}: $general ${advice.isNotEmpty ? 'Advice: $advice' : ''}';
      return AiSectionModel(
        positionId: drawn.positionId,
        title: drawn.positionTitle,
        text: text.trim(),
      );
    }).toList();

    final why =
        'Each position reflects a facet of your question, and the card themes align with where attention can be placed now.';
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
          ? 'Choose one small, practical step that honors the advice in the cards.'
          : action,
      fullText: fullText,
      requestId: null,
    );
  }

  Future<void> saveReading() async {
    final spread = state.spread;
    final aiResult = state.aiResult;
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
}
