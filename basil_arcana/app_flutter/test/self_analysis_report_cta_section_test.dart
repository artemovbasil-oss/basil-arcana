import 'package:basil_arcana/features/home/widgets/self_analysis_report_cta_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    );
  }

  testWidgets('shows paid label when not free', (tester) async {
    await tester.pumpWidget(
      wrap(
        SelfAnalysisReportCtaSection(
          title: 'Личный отчет',
          body: 'Body',
          paidLabel: 'Получить отчет (PDF) — 200 ⭐',
          freeLabel: 'Получить отчет (PDF) — бесплатно',
          helper: 'На основе истории раскладов за 30 дней',
          isFree: false,
          isLoading: false,
          isEnabled: true,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Получить отчет (PDF) — 200 ⭐'), findsOneWidget);
  });

  testWidgets('shows free label when eligible', (tester) async {
    await tester.pumpWidget(
      wrap(
        SelfAnalysisReportCtaSection(
          title: 'Личный отчет',
          body: 'Body',
          paidLabel: 'Получить отчет (PDF) — 200 ⭐',
          freeLabel: 'Получить отчет (PDF) — бесплатно',
          helper: 'На основе истории раскладов за 30 дней',
          isFree: true,
          isLoading: false,
          isEnabled: true,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Получить отчет (PDF) — бесплатно'), findsOneWidget);
  });

  testWidgets('disabled when isEnabled is false', (tester) async {
    await tester.pumpWidget(
      wrap(
        SelfAnalysisReportCtaSection(
          title: 'Личный отчет',
          body: 'Body',
          paidLabel: 'Получить отчет (PDF) — 200 ⭐',
          freeLabel: 'Получить отчет (PDF) — бесплатно',
          helper: 'На основе истории раскладов за 30 дней',
          isFree: false,
          isLoading: false,
          isEnabled: false,
          onPressed: () {},
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
