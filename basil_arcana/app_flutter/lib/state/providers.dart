import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ai_repository.dart';
import '../data/repositories/cards_repository.dart';
import '../data/repositories/readings_repository.dart';
import '../data/repositories/spreads_repository.dart';
import 'reading_flow_controller.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepository();
});

final spreadsRepositoryProvider = Provider<SpreadsRepository>((ref) {
  return SpreadsRepository();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

final readingsRepositoryProvider = Provider<ReadingsRepository>((ref) {
  return ReadingsRepository();
});

final readingFlowControllerProvider =
    StateNotifierProvider<ReadingFlowController, ReadingFlowState>((ref) {
  return ReadingFlowController(ref);
});

final cardsProvider = FutureProvider((ref) async {
  final repo = ref.watch(cardsRepositoryProvider);
  return repo.fetchCards();
});

final spreadsProvider = FutureProvider((ref) async {
  final repo = ref.watch(spreadsRepositoryProvider);
  return repo.fetchSpreads();
});
