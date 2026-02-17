import 'package:basil_arcana/data/models/ai_result_model.dart';
import 'package:basil_arcana/data/models/card_model.dart';
import 'package:basil_arcana/data/models/deck_model.dart';
import 'package:basil_arcana/data/models/drawn_card_model.dart';
import 'package:basil_arcana/data/models/reading_model.dart';
import 'package:basil_arcana/features/home/self_analysis_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelfAnalysisReportService calculations', () {
    final service = SelfAnalysisReportService();

    test('calculates suit distribution, major share and recurring cards', () {
      final now = DateTime(2026, 2, 17);
      final readings = [
        _reading(now.subtract(const Duration(days: 3)), [
          _drawn('wands_13_ace', 'Ace of Wands'),
          _drawn('wands_13_ace', 'Ace of Wands'),
          _drawn('cups_13_ace', 'Ace of Cups'),
          _drawn('major_19_sun', 'The Sun'),
          _drawn('swords_13_ace', 'Ace of Swords'),
        ]),
        _reading(now.subtract(const Duration(days: 9)), [
          _drawn('wands_13_ace', 'Ace of Wands'),
          _drawn('pentacles_13_ace', 'Ace of Pentacles'),
          _drawn('major_01_magician', 'The Magician'),
          _drawn('cups_13_ace', 'Ace of Cups'),
          _drawn('cups_13_ace', 'Ace of Cups'),
        ]),
      ];

      final samples = service.extractRecentSamples(
        readings: readings,
        fromDate: now.subtract(const Duration(days: 30)),
        toDate: now,
        selectedDeck: DeckType.all,
      );
      final dataset = service.buildDataset(samples: samples);

      expect(dataset.totalCards, 10);
      expect(dataset.majorArcanaShare, 20);
      expect(dataset.suitPercents['action'], 30);
      expect(dataset.suitPercents['emotion'], 30);
      expect(dataset.recurringCards.any((entry) => entry.key == 'Ace of Wands'),
          isTrue);
      expect(dataset.recurringCards.any((entry) => entry.key == 'Ace of Cups'),
          isTrue);
    });
  });

  group('Eligibility', () {
    test('free for LUCY100 promo', () {
      final ent = UserEntitlements(
        promoCodes: const {'LUCY100'},
        hasActiveYearlySubscription: false,
      );
      expect(isReportFree(ent), isTrue);
    });

    test('free for yearly subscription', () {
      final ent = UserEntitlements(
        promoCodes: const {},
        hasActiveYearlySubscription: true,
      );
      expect(isReportFree(ent), isTrue);
    });

    test('paid for no entitlements', () {
      final ent = UserEntitlements(
        promoCodes: const {},
        hasActiveYearlySubscription: false,
      );
      expect(isReportFree(ent), isFalse);
    });
  });
}

ReadingModel _reading(DateTime createdAt, List<DrawnCardModel> cards) {
  return ReadingModel(
    readingId: 'r_${createdAt.millisecondsSinceEpoch}',
    createdAt: createdAt,
    question: 'Q',
    spreadId: 's',
    spreadName: 'Spread',
    drawnCards: cards,
    tldr: '',
    sections: const <AiSectionModel>[],
    why: '',
    action: '',
    fullText: '',
    aiUsed: false,
    requestId: null,
  );
}

DrawnCardModel _drawn(String id, String name) {
  return DrawnCardModel(
    positionId: 'p',
    positionTitle: 'Pos',
    cardId: id,
    cardName: name,
    keywords: const [],
    meaning: const CardMeaning(general: '', light: '', shadow: '', advice: ''),
  );
}
