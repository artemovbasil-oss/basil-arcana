import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/deck_model.dart';
import '../../data/models/reading_model.dart';

class UserEntitlements {
  const UserEntitlements({
    required this.promoCodes,
    required this.hasActiveYearlySubscription,
  });

  final Set<String> promoCodes;
  final bool hasActiveYearlySubscription;

  bool hasPromo(String code) {
    final normalized = code.trim().toUpperCase();
    return promoCodes
        .map((item) => item.trim().toUpperCase())
        .contains(normalized);
  }
}

bool isReportFree(UserEntitlements ent) {
  return ent.hasPromo('LUCY100') || ent.hasActiveYearlySubscription;
}

class SelfAnalysisDataset {
  const SelfAnalysisDataset({
    required this.totalCards,
    required this.suitPercents,
    required this.majorArcanaShare,
    required this.recurringCards,
    required this.dominantSuit,
  });

  final int totalCards;
  final Map<String, int> suitPercents;
  final int majorArcanaShare;
  final List<MapEntry<String, int>> recurringCards;
  final String dominantSuit;

  bool get hasEnoughData => totalCards >= 10;
}

class SelfAnalysisReportMeta {
  const SelfAnalysisReportMeta({
    required this.userId,
    required this.fromDate,
    required this.toDate,
    required this.totalCards,
    required this.majorArcanaShare,
    required this.suitPercents,
    required this.recurringCards,
  });

  final String userId;
  final DateTime fromDate;
  final DateTime toDate;
  final int totalCards;
  final int majorArcanaShare;
  final Map<String, int> suitPercents;
  final List<MapEntry<String, int>> recurringCards;
}

class SelfAnalysisReportResult {
  const SelfAnalysisReportResult({
    required this.pdfBytes,
    required this.summarySnippet,
    required this.reportMeta,
  });

  final Uint8List pdfBytes;
  final String summarySnippet;
  final SelfAnalysisReportMeta reportMeta;
}

class SelfAnalysisReportService {
  static const int minCardsThreshold = 10;

  List<ReportCardSample> extractRecentSamples({
    required List<ReadingModel> readings,
    required DateTime fromDate,
    required DateTime toDate,
    required DeckType selectedDeck,
  }) {
    final samples = <ReportCardSample>[];
    for (final reading in readings) {
      final createdAt = reading.createdAt;
      if (createdAt.isBefore(fromDate) || createdAt.isAfter(toDate)) {
        continue;
      }
      for (final drawn in reading.drawnCards) {
        final cardId = canonicalCardId(drawn.cardId);
        if (!_matchesDeck(cardId, selectedDeck)) {
          continue;
        }
        samples.add(ReportCardSample(
          id: cardId,
          name: drawn.cardName.trim().isEmpty ? cardId : drawn.cardName.trim(),
        ));
      }
    }
    return samples;
  }

  SelfAnalysisDataset buildDataset({
    required List<ReportCardSample> samples,
  }) {
    if (samples.isEmpty) {
      return const SelfAnalysisDataset(
        totalCards: 0,
        suitPercents: {
          'action': 0,
          'emotion': 0,
          'mind': 0,
          'ground': 0,
        },
        majorArcanaShare: 0,
        recurringCards: [],
        dominantSuit: 'action',
      );
    }

    final suitCounts = <String, int>{
      'action': 0,
      'emotion': 0,
      'mind': 0,
      'ground': 0,
    };
    var majorCount = 0;
    final byCardName = <String, int>{};

    for (final sample in samples) {
      final bucket = _bucketForCard(sample.id);
      if (bucket != null) {
        suitCounts[bucket] = (suitCounts[bucket] ?? 0) + 1;
      }
      if (sample.id.startsWith('major_') || sample.id.startsWith('ac_')) {
        majorCount += 1;
      }
      byCardName[sample.name] = (byCardName[sample.name] ?? 0) + 1;
    }

    final total = samples.length;
    final suitPercents = <String, int>{};
    for (final entry in suitCounts.entries) {
      suitPercents[entry.key] = ((entry.value / max(total, 1)) * 100).round();
    }

    final dominantSuit = suitPercents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recurring = byCardName.entries
        .where((entry) => entry.value >= 3)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SelfAnalysisDataset(
      totalCards: total,
      suitPercents: suitPercents,
      majorArcanaShare: ((majorCount / max(total, 1)) * 100).round(),
      recurringCards: recurring,
      dominantSuit: dominantSuit.first.key,
    );
  }

  int countDeckCardsInStats({
    required Map<String, int> allTimeStats,
    required DeckType selectedDeck,
  }) {
    var total = 0;
    for (final entry in allTimeStats.entries) {
      final cardId = canonicalCardId(entry.key);
      if (!_matchesDeck(cardId, selectedDeck)) {
        continue;
      }
      total += max(0, entry.value);
    }
    return total;
  }

  List<ReportCardSample> extractSamplesFromStats({
    required Map<String, int> allTimeStats,
    required DeckType selectedDeck,
    int maxSamples = 400,
  }) {
    final out = <ReportCardSample>[];
    final sorted = allTimeStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sorted) {
      final cardId = canonicalCardId(entry.key);
      if (!_matchesDeck(cardId, selectedDeck)) {
        continue;
      }
      final count = max(0, entry.value);
      for (var i = 0; i < count; i++) {
        out.add(ReportCardSample(id: cardId, name: cardId));
        if (out.length >= maxSamples) {
          return out;
        }
      }
    }
    return out;
  }

  Future<SelfAnalysisReportResult> generateSelfAnalysisReport({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
    required List<ReadingModel> readings,
    Map<String, int>? fallbackAllTimeStats,
    required DeckType selectedDeck,
    required String locale,
  }) async {
    final baseSamples = extractRecentSamples(
      readings: readings,
      fromDate: fromDate,
      toDate: toDate,
      selectedDeck: selectedDeck,
    );
    final samples = <ReportCardSample>[...baseSamples];
    if (samples.length < minCardsThreshold && fallbackAllTimeStats != null) {
      final fallback = extractSamplesFromStats(
        allTimeStats: fallbackAllTimeStats,
        selectedDeck: selectedDeck,
      );
      samples.addAll(fallback);
    }
    final dataset = buildDataset(samples: samples);
    final summary = _buildSummary(dataset, locale);
    final meta = SelfAnalysisReportMeta(
      userId: userId,
      fromDate: fromDate,
      toDate: toDate,
      totalCards: dataset.totalCards,
      majorArcanaShare: dataset.majorArcanaShare,
      suitPercents: dataset.suitPercents,
      recurringCards: dataset.recurringCards,
    );

    final pdf = pw.Document();
    final dateFmt = DateFormat('dd.MM.yyyy');
    final fromText = dateFmt.format(fromDate);
    final toText = dateFmt.format(toDate);

    final strengths = _strengthRecommendations(dataset, locale);
    final frictions = _frictionRecommendations(dataset, locale);
    final journalPrompt = _journalPrompt(locale);
    final imbalanceLines = _imbalanceLines(dataset, locale);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            locale == 'ru'
                ? 'Личный self-analysis отчёт'
                : 'Personal Self-Analysis Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('4C5A70'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            locale == 'ru'
                ? 'Период: $fromText — $toText'
                : 'Period: $fromText — $toText',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
          _sectionTitle(locale == 'ru'
              ? 'A. Твой поведенческий вектор'
              : 'A. Behavioral vector'),
          pw.SizedBox(height: 6),
          _line(
              '${locale == 'ru' ? 'Действие' : 'Action'}: ${dataset.suitPercents['action'] ?? 0}%'),
          _line(
              '${locale == 'ru' ? 'Эмоции' : 'Emotion'}: ${dataset.suitPercents['emotion'] ?? 0}%'),
          _line(
              '${locale == 'ru' ? 'Мышление' : 'Mind'}: ${dataset.suitPercents['mind'] ?? 0}%'),
          _line(
              '${locale == 'ru' ? 'Стабильность' : 'Grounding'}: ${dataset.suitPercents['ground'] ?? 0}%'),
          pw.SizedBox(height: 4),
          _paragraph(_vectorInterpretation(dataset, locale)),
          pw.SizedBox(height: 12),
          _sectionTitle(locale == 'ru'
              ? 'B. Индекс значимости решений'
              : 'B. Decision significance index'),
          _paragraph(
            locale == 'ru'
                ? 'Доля Старших Арканов: ${dataset.majorArcanaShare}%. Это отражает интенсивность переходных тем в твоём текущем периоде.'
                : 'Major Arcana share: ${dataset.majorArcanaShare}%. This reflects the intensity of transition themes in your current phase.',
          ),
          pw.SizedBox(height: 12),
          _sectionTitle(
              locale == 'ru' ? 'C. Повторяющиеся темы' : 'C. Recurring themes'),
          if (dataset.recurringCards.isEmpty)
            _paragraph(locale == 'ru'
                ? 'Явных повторов за период не выявлено.'
                : 'No strong recurring cards in this period.')
          else
            ...dataset.recurringCards
                .take(5)
                .map((entry) => _line('• ${entry.key} — ${entry.value}x'))
                .toList(),
          pw.SizedBox(height: 12),
          _sectionTitle(
              locale == 'ru' ? 'D. Зоны дисбаланса' : 'D. Imbalance zones'),
          if (imbalanceLines.isEmpty)
            _paragraph(locale == 'ru'
                ? 'Распределение выглядит достаточно ровным.'
                : 'Distribution looks balanced overall.')
          else
            ...imbalanceLines.map(_line),
          pw.SizedBox(height: 12),
          _sectionTitle(locale == 'ru'
              ? 'E. Мягкие рекомендации на неделю'
              : 'E. Gentle recommendations for the week'),
          ...strengths.map((item) => _line('• $item')),
          ...frictions.map((item) => _line('• $item')),
          _line('• $journalPrompt'),
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColor.fromHex('C5CBD6')),
          _paragraph(
            locale == 'ru'
                ? 'Отчет — инструмент саморефлексии и не является медицинской или психологической диагностикой.'
                : 'This report is a self-reflection tool and is not a medical or psychological diagnosis.',
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    return SelfAnalysisReportResult(
      pdfBytes: Uint8List.fromList(bytes),
      summarySnippet: summary,
      reportMeta: meta,
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('4C5A70'),
      ),
    );
  }

  static pw.Widget _paragraph(String text) {
    return pw.Text(text,
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3));
  }

  static pw.Widget _line(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
    );
  }

  String _buildSummary(SelfAnalysisDataset dataset, String locale) {
    if (locale == 'ru') {
      final action = dataset.suitPercents['action'] ?? 0;
      final emotion = dataset.suitPercents['emotion'] ?? 0;
      return 'За период ты чаще действуешь через ${_dominantName(dataset.dominantSuit, locale)}. '
          'Баланс действие/эмоции: $action% / $emotion%. '
          'Сейчас полезно держать фокус на мягкой устойчивости и регулярной саморефлексии.';
    }
    return 'Your period is currently led by ${_dominantName(dataset.dominantSuit, locale)}. '
        'Action/emotion balance is ${dataset.suitPercents['action'] ?? 0}% / ${dataset.suitPercents['emotion'] ?? 0}%. '
        'Stay with steady routines and gentle reflection this week.';
  }

  String _dominantName(String suit, String locale) {
    const ru = {
      'action': 'действие',
      'emotion': 'эмоциональную переработку',
      'mind': 'аналитическое мышление',
      'ground': 'практическую устойчивость',
    };
    const en = {
      'action': 'action',
      'emotion': 'emotional processing',
      'mind': 'analytical processing',
      'ground': 'grounded stability',
    };
    return locale == 'ru'
        ? (ru[suit] ?? ru['action']!)
        : (en[suit] ?? en['action']!);
  }

  String _vectorInterpretation(SelfAnalysisDataset dataset, String locale) {
    if (locale == 'ru') {
      return 'Это не оценка "правильно/неправильно", а ориентир. '
          'Твой профиль показывает, каким способом ты чаще отвечаешь на нагрузку и неопределённость.';
    }
    return 'This is not a right-or-wrong label. It is a practical signal of how you currently respond to stress and uncertainty.';
  }

  List<String> _imbalanceLines(SelfAnalysisDataset dataset, String locale) {
    final lines = <String>[];
    dataset.suitPercents.forEach((key, value) {
      if (value < 10) {
        lines.add(locale == 'ru'
            ? '${_dominantName(key, locale)}: всего $value%. Эту зону стоит мягко укрепить в быту.'
            : '${_dominantName(key, locale)} is only $value%. Consider gently reinforcing it this week.');
      } else if (value > 50) {
        lines.add(locale == 'ru'
            ? '${_dominantName(key, locale)}: $value%. Возможен перекос, попробуй добавить баланс через противоположный режим.'
            : '${_dominantName(key, locale)} is $value%. You may benefit from balancing it with an opposite mode.');
      }
    });
    return lines;
  }

  List<String> _strengthRecommendations(
      SelfAnalysisDataset dataset, String locale) {
    if (locale == 'ru') {
      return [
        'Опирайся на свои сильные привычки принятия решений и фиксируй, что уже работает.',
        'Сохраняй темп: 1 небольшой завершённый шаг в день лучше, чем редкие рывки.',
      ];
    }
    return [
      'Lean into your strongest decision habits and keep what is already working.',
      'Keep momentum with one small completed step per day.',
    ];
  }

  List<String> _frictionRecommendations(
      SelfAnalysisDataset dataset, String locale) {
    if (locale == 'ru') {
      return [
        'Снизь внутреннее трение: заранее выбери 1-2 приоритета дня и убери лишние решения.',
        'Перед сном делай короткий разбор дня: где была перегрузка, где был ресурс.',
      ];
    }
    return [
      'Reduce friction by choosing 1-2 priorities early and cutting extra decisions.',
      'Do a brief evening review: where did tension rise and where did energy return.',
    ];
  }

  String _journalPrompt(String locale) {
    if (locale == 'ru') {
      return 'Вопрос в дневник: "Где я действовал(а) из ясности, а где — из напряжения, и что хочу скорректировать завтра?"';
    }
    return 'Journal prompt: "Where did I act from clarity versus tension today, and what will I adjust tomorrow?"';
  }

  String? _bucketForCard(String cardId) {
    if (cardId.startsWith('wands_')) {
      return 'action';
    }
    if (cardId.startsWith('cups_')) {
      return 'emotion';
    }
    if (cardId.startsWith('swords_')) {
      return 'mind';
    }
    if (cardId.startsWith('pentacles_')) {
      return 'ground';
    }
    if (cardId.startsWith('ac_')) {
      final parts = cardId.split('_');
      final number = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (number == null) {
        return 'mind';
      }
      if (number <= 5) {
        return 'action';
      }
      if (number <= 11) {
        return 'emotion';
      }
      if (number <= 17) {
        return 'mind';
      }
      return 'ground';
    }
    if (cardId.startsWith('lenormand_')) {
      final parts = cardId.split('_');
      final number = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (number == null) {
        return 'mind';
      }
      if (number <= 9) {
        return 'action';
      }
      if (number <= 18) {
        return 'emotion';
      }
      if (number <= 27) {
        return 'mind';
      }
      return 'ground';
    }
    return null;
  }

  bool _matchesDeck(String cardId, DeckType selectedDeck) {
    if (selectedDeck == DeckType.lenormand) {
      return cardId.startsWith('lenormand_');
    }
    if (selectedDeck == DeckType.crowley) {
      return cardId.startsWith('ac_');
    }
    return cardId.startsWith('major_') ||
        cardId.startsWith('wands_') ||
        cardId.startsWith('cups_') ||
        cardId.startsWith('swords_') ||
        cardId.startsWith('pentacles_');
  }
}

class ReportCardSample {
  const ReportCardSample({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
