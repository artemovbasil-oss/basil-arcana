import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
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
  static Future<_PdfTheme>? _pdfThemeFuture;

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

    final pdfTheme = await _loadPdfTheme();
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd.MM.yyyy');
    final fromText = dateFmt.format(fromDate);
    final toText = dateFmt.format(toDate);

    final suitOrder = <String>['action', 'emotion', 'mind', 'ground'];
    final suitCounts = <String, int>{
      'action': 0,
      'emotion': 0,
      'mind': 0,
      'ground': 0,
    };
    for (final sample in samples) {
      final bucket = _bucketForCard(sample.id);
      if (bucket != null) {
        suitCounts[bucket] = (suitCounts[bucket] ?? 0) + 1;
      }
    }
    final sortedRecurring = dataset.recurringCards.take(12).toList();
    final strengths = _strengthRecommendations(dataset, locale);
    final frictions = _frictionRecommendations(dataset, locale);
    final imbalanceLines = _imbalanceLines(dataset, locale);
    final journalPrompt = _journalPrompt(locale);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            locale == 'ru'
                ? 'Страница ${context.pageNumber}/${context.pagesCount}'
                : 'Page ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(
              font: pdfTheme.regular,
              fontSize: 9,
              color: PdfColor.fromHex('7A8293'),
            ),
          ),
        ),
        build: (_) => [
          _reportHeader(
            theme: pdfTheme,
            title: locale == 'ru'
                ? 'Личный аналитический отчёт'
                : 'Personal Analytical Report',
            subtitle: locale == 'ru'
                ? 'Период: $fromText — $toText'
                : 'Period: $fromText — $toText',
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _metricCard(
                theme: pdfTheme,
                label: locale == 'ru' ? 'Карт в выборке' : 'Cards in sample',
                value: '${dataset.totalCards}',
              ),
              pw.SizedBox(width: 10),
              _metricCard(
                theme: pdfTheme,
                label: locale == 'ru' ? 'Старшие Арканы' : 'Major Arcana share',
                value: '${dataset.majorArcanaShare}%',
              ),
              pw.SizedBox(width: 10),
              _metricCard(
                theme: pdfTheme,
                label: locale == 'ru' ? 'Доминирующий вектор' : 'Dominant mode',
                value: _dominantName(dataset.dominantSuit, locale),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru' ? '1. Краткий вывод' : '1. Executive summary',
            body: [
              _p(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Этот отчёт описывает устойчивые паттерны твоих раскладов за 30 дней: стиль решений, эмоциональную динамику, уровень перегрузки и зоны роста.'
                    : 'This report maps stable patterns from your last 30 days: decision style, emotional dynamics, load level, and growth zones.',
              ),
              _p(theme: pdfTheme, text: summary),
            ],
          ),
          pw.SizedBox(height: 12),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '2. Баланс мастей и поведенческий профиль'
                : '2. Suit balance and behavioral profile',
            body: [
              ...suitOrder.map((key) {
                final percent = dataset.suitPercents[key] ?? 0;
                final absolute = suitCounts[key] ?? 0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _rowLabelValue(
                        pdfTheme,
                        _dominantName(key, locale),
                        '$percent%  (${absolute.toString()})',
                      ),
                      pw.SizedBox(height: 4),
                      _progressBar(
                        percent: percent,
                        color: _suitColor(key),
                      ),
                    ],
                  ),
                );
              }),
              _p(
                theme: pdfTheme,
                text: _vectorInterpretation(dataset, locale),
              ),
            ],
          ),
          pw.NewPage(),
          _reportHeader(
            theme: pdfTheme,
            title: locale == 'ru'
                ? 'Глубокий разбор динамики'
                : 'Deep dynamics breakdown',
            subtitle: locale == 'ru'
                ? 'Паттерны, причины, сигналы для коррекции'
                : 'Patterns, causes, and adjustment signals',
          ),
          pw.SizedBox(height: 12),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '3. Индекс значимости периода'
                : '3. Period significance index',
            body: [
              _p(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Доля Старших Арканов: ${dataset.majorArcanaShare}%. Чем выше этот показатель, тем больше в периоде развилок и долгосрочных последствий решений.'
                    : 'Major Arcana share: ${dataset.majorArcanaShare}%. Higher values typically indicate more turning points and long-term consequences.',
              ),
              _p(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? _majorArcanaInterpretationRu(dataset.majorArcanaShare)
                    : _majorArcanaInterpretationEn(dataset.majorArcanaShare),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '4. Зоны перегруза и компенсации'
                : '4. Overload and compensation zones',
            body: [
              if (imbalanceLines.isEmpty)
                _p(
                  theme: pdfTheme,
                  text: locale == 'ru'
                      ? 'Распределение выглядит относительно ровным: явных перекосов не обнаружено.'
                      : 'Distribution appears fairly balanced with no strong skew.',
                )
              else
                ...imbalanceLines
                    .map((line) => _bullet(theme: pdfTheme, text: line)),
              _p(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Практика: фиксируй вечером 1 сигнал перегруза и 1 действие, которое вернуло устойчивость.'
                    : 'Practice: each evening note one overload signal and one action that restored stability.',
              ),
            ],
          ),
          pw.NewPage(),
          _reportHeader(
            theme: pdfTheme,
            title: locale == 'ru'
                ? 'Карточные повторы и темы'
                : 'Recurring cards and themes',
            subtitle: locale == 'ru'
                ? 'Повторяющиеся сигналы в твоих раскладах'
                : 'Repeated signals from your spreads',
          ),
          pw.SizedBox(height: 12),
          _sectionBlock(
            theme: pdfTheme,
            title:
                locale == 'ru' ? '5. Топ повторов' : '5. Top recurring cards',
            body: [
              if (sortedRecurring.isEmpty)
                _p(
                  theme: pdfTheme,
                  text: locale == 'ru'
                      ? 'Выраженных повторов не обнаружено. Это обычно означает высокую вариативность запросов.'
                      : 'No strong recurring cards detected, which often indicates high query diversity.',
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('D4D9E3'),
                    width: 0.6,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(5),
                    1: pw.FlexColumnWidth(1.5),
                    2: pw.FlexColumnWidth(5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EEF1F7'),
                      ),
                      children: [
                        _tableCell(
                          theme: pdfTheme,
                          text: locale == 'ru' ? 'Карта' : 'Card',
                          bold: true,
                        ),
                        _tableCell(
                          theme: pdfTheme,
                          text: locale == 'ru' ? 'Частота' : 'Count',
                          bold: true,
                        ),
                        _tableCell(
                          theme: pdfTheme,
                          text: locale == 'ru' ? 'Комментарий' : 'Comment',
                          bold: true,
                        ),
                      ],
                    ),
                    ...sortedRecurring.map((entry) {
                      final name = _humanizeCardName(entry.key);
                      final comment = locale == 'ru'
                          ? 'Повтор темы: "$name". Проверь, какие решения ты откладываешь в похожих ситуациях.'
                          : 'Recurring theme "$name". Check which decisions are postponed in similar contexts.';
                      return pw.TableRow(
                        children: [
                          _tableCell(theme: pdfTheme, text: name),
                          _tableCell(theme: pdfTheme, text: '${entry.value}x'),
                          _tableCell(theme: pdfTheme, text: comment),
                        ],
                      );
                    }),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 10),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '6. Вопросы для самоанализа'
                : '6. Reflection questions',
            body: [
              _bullet(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Какая повторяющаяся тема забирала больше всего энергии на этой неделе?'
                    : 'Which recurring theme consumed most of your energy this week?',
              ),
              _bullet(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Что из текущих решений можно закрыть одним конкретным шагом в ближайшие 24 часа?'
                    : 'Which current decision can be closed with one concrete step in the next 24 hours?',
              ),
              _bullet(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Где ты действуешь из тревоги, а где из ясности?'
                    : 'Where do you act from anxiety versus clarity?',
              ),
            ],
          ),
          pw.NewPage(),
          _reportHeader(
            theme: pdfTheme,
            title: locale == 'ru'
                ? 'Практические рекомендации'
                : 'Practical recommendations',
            subtitle: locale == 'ru'
                ? 'План на 7 и 30 дней'
                : '7-day and 30-day plan',
          ),
          pw.SizedBox(height: 12),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '7. Что усилить уже сейчас'
                : '7. What to reinforce now',
            body: strengths
                .map((e) => _bullet(theme: pdfTheme, text: e))
                .toList(),
          ),
          pw.SizedBox(height: 10),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '8. Что снизить, чтобы не выгорать'
                : '8. What to reduce to avoid burnout',
            body: frictions
                .map((e) => _bullet(theme: pdfTheme, text: e))
                .toList(),
          ),
          pw.SizedBox(height: 10),
          _sectionBlock(
            theme: pdfTheme,
            title:
                locale == 'ru' ? '9. Роадмап на 30 дней' : '9. 30-day roadmap',
            body: [
              _roadmapTable(theme: pdfTheme, locale: locale),
              pw.SizedBox(height: 8),
              _bullet(theme: pdfTheme, text: journalPrompt),
            ],
          ),
          pw.NewPage(),
          _reportHeader(
            theme: pdfTheme,
            title: locale == 'ru'
                ? 'Итог и рабочий шаблон'
                : 'Final synthesis and template',
            subtitle:
                locale == 'ru' ? 'Закрепление результатов' : 'Consolidation',
          ),
          pw.SizedBox(height: 12),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru'
                ? '10. Короткий weekly-review'
                : '10. Weekly review template',
            body: [
              _bullet(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Главный фокус недели: __________________________'
                    : 'Primary focus of the week: __________________________',
              ),
              _bullet(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? '3 результата, которые хочу получить:'
                    : '3 outcomes I want to deliver:',
              ),
              _lineInput(theme: pdfTheme),
              _lineInput(theme: pdfTheme),
              _lineInput(theme: pdfTheme),
              _bullet(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Что убираю из расписания для снижения перегруза:'
                    : 'What I remove from schedule to reduce overload:',
              ),
              _lineInput(theme: pdfTheme),
              _lineInput(theme: pdfTheme),
            ],
          ),
          pw.SizedBox(height: 14),
          _sectionBlock(
            theme: pdfTheme,
            title: locale == 'ru' ? 'Важно' : 'Important',
            body: [
              _p(
                theme: pdfTheme,
                text: locale == 'ru'
                    ? 'Отчёт является инструментом саморефлексии и поддержки принятия решений. Он не заменяет медицинскую, психотерапевтическую или юридическую консультацию.'
                    : 'This report is a self-reflection and decision-support tool. It does not replace medical, psychotherapeutic, or legal advice.',
              ),
            ],
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

  static Future<_PdfTheme> _loadPdfTheme() {
    return _pdfThemeFuture ??= (() async {
      final regularData =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      return _PdfTheme(
        regular: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      );
    })();
  }

  static pw.Widget _reportHeader({
    required _PdfTheme theme,
    required String title,
    required String subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        color: PdfColor.fromHex('EEF1F7'),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: theme.bold,
              fontSize: 20,
              color: PdfColor.fromHex('2B3140'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              font: theme.regular,
              fontSize: 11,
              color: PdfColor.fromHex('5C6478'),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metricCard({
    required _PdfTheme theme,
    required String label,
    required String value,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColor.fromHex('D4D9E3'), width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: theme.regular,
                fontSize: 10,
                color: PdfColor.fromHex('667086'),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: theme.bold,
                fontSize: 14,
                color: PdfColor.fromHex('2D3446'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionBlock({
    required _PdfTheme theme,
    required String title,
    required List<pw.Widget> body,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        color: PdfColor.fromHex('F8F9FC'),
        border: pw.Border.all(color: PdfColor.fromHex('E1E6EF'), width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: theme.bold,
              fontSize: 13,
              color: PdfColor.fromHex('394158'),
            ),
          ),
          pw.SizedBox(height: 7),
          ...body,
        ],
      ),
    );
  }

  static pw.Widget _p({
    required _PdfTheme theme,
    required String text,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: theme.regular,
          fontSize: 10.8,
          lineSpacing: 1.35,
          color: PdfColor.fromHex('343B4C'),
        ),
      ),
    );
  }

  static pw.Widget _bullet({
    required _PdfTheme theme,
    required String text,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            '- ',
            style: pw.TextStyle(
              font: theme.bold,
              fontSize: 10.8,
              color: PdfColor.fromHex('343B4C'),
            ),
          ),
        ),
        pw.Expanded(child: _p(theme: theme, text: text)),
      ],
    );
  }

  static pw.Widget _rowLabelValue(
    _PdfTheme theme,
    String label,
    String value,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: theme.regular, fontSize: 10.5),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: theme.bold, fontSize: 10.5),
        ),
      ],
    );
  }

  static pw.Widget _progressBar({
    required int percent,
    required PdfColor color,
  }) {
    final clamped = percent.clamp(0, 100);
    return pw.Container(
      height: 8,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(99),
        color: PdfColor.fromHex('E5E9F1'),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: clamped * 2.4,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(99),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _suitColor(String suit) {
    switch (suit) {
      case 'action':
        return PdfColor.fromHex('FF8F5A');
      case 'emotion':
        return PdfColor.fromHex('5FB5FF');
      case 'mind':
        return PdfColor.fromHex('8E96AD');
      case 'ground':
        return PdfColor.fromHex('E7C867');
      default:
        return PdfColor.fromHex('95A0B8');
    }
  }

  static pw.Widget _tableCell({
    required _PdfTheme theme,
    required String text,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? theme.bold : theme.regular,
          fontSize: 9.8,
          lineSpacing: 1.2,
        ),
      ),
    );
  }

  static pw.Widget _lineInput({required _PdfTheme theme}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      height: 16,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
        ),
      ),
      child: pw.Text(
        '',
        style: pw.TextStyle(font: theme.regular, fontSize: 10),
      ),
    );
  }

  static pw.Widget _roadmapTable({
    required _PdfTheme theme,
    required String locale,
  }) {
    final rows = locale == 'ru'
        ? const <List<String>>[
            ['Неделя 1', 'Стабилизация', '2 ключевых приоритета в день'],
            ['Неделя 2', 'Фокус', 'Ревизия незавершённых задач'],
            ['Неделя 3', 'Углубление', '1 сложный разговор / решение'],
            ['Неделя 4', 'Интеграция', 'Подведение итогов и корректировки'],
          ]
        : const <List<String>>[
            ['Week 1', 'Stabilize', '2 key priorities per day'],
            ['Week 2', 'Focus', 'Review unfinished tasks'],
            ['Week 3', 'Deepen', '1 difficult conversation/decision'],
            ['Week 4', 'Integrate', 'Review outcomes and adjust'],
          ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('D4D9E3'), width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(4),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('EEF1F7')),
          children: [
            _tableCell(
              theme: theme,
              text: locale == 'ru' ? 'Период' : 'Period',
              bold: true,
            ),
            _tableCell(
              theme: theme,
              text: locale == 'ru' ? 'Фокус' : 'Focus',
              bold: true,
            ),
            _tableCell(
              theme: theme,
              text: locale == 'ru' ? 'Действие' : 'Action',
              bold: true,
            ),
          ],
        ),
        ...rows.map((row) {
          return pw.TableRow(
            children: [
              _tableCell(theme: theme, text: row[0]),
              _tableCell(theme: theme, text: row[1]),
              _tableCell(theme: theme, text: row[2]),
            ],
          );
        }),
      ],
    );
  }

  String _humanizeCardName(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return raw;
    }
    if (normalized.contains('_')) {
      final pretty = normalized
          .replaceAll('major_', '')
          .replaceAll('wands_', '')
          .replaceAll('cups_', '')
          .replaceAll('swords_', '')
          .replaceAll('pentacles_', '')
          .replaceAll('lenormand_', '')
          .replaceAll('ac_', '')
          .replaceAll('_', ' ')
          .trim();
      if (pretty.isNotEmpty) {
        return pretty;
      }
    }
    return normalized;
  }

  String _majorArcanaInterpretationRu(int share) {
    if (share >= 45) {
      return 'Период высокой трансформации. Решения, которые ты принимаешь сейчас, с высокой вероятностью повлияют на несколько последующих месяцев.';
    }
    if (share >= 25) {
      return 'Период умеренной трансформации. Важные развилки сочетаются с рабочей рутиной, поэтому лучше опираться на чёткие приоритеты.';
    }
    return 'Период операционного фокуса. Больше эффекта дадут регулярные практические шаги, чем резкие развороты.';
  }

  String _majorArcanaInterpretationEn(int share) {
    if (share >= 45) {
      return 'High-transformation phase. Decisions made now are likely to shape the next several months.';
    }
    if (share >= 25) {
      return 'Moderate-transformation phase. Key turning points coexist with routine work, so explicit priorities help most.';
    }
    return 'Operational-focus phase. Consistent practical steps may outperform sharp pivots.';
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

class _PdfTheme {
  const _PdfTheme({
    required this.regular,
    required this.bold,
  });

  final pw.Font regular;
  final pw.Font bold;
}
