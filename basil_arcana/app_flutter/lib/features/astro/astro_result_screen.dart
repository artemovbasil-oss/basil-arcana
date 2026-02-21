import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_user_profile.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../state/providers.dart';
import '../settings/settings_screen.dart';

class AstroResultScreen extends ConsumerWidget {
  const AstroResultScreen({
    required this.userPrompt,
    required this.title,
    required this.summary,
    required this.highlights,
    required this.action,
    required this.sofiaPrefill,
    this.tarotQuestion,
    this.showBirthChartVisual = false,
    this.birthChartSeed,
    super.key,
  });

  final String userPrompt;
  final String title;
  final String summary;
  final List<String> highlights;
  final String action;
  final String sofiaPrefill;
  final String? tarotQuestion;
  final bool showBirthChartVisual;
  final String? birthChartSeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _AstroResultCopy.resolve(context);
    final l10n = AppLocalizations.of(context);
    final tarotPrompt = tarotQuestion?.trim() ?? '';
    return Scaffold(
      appBar: buildEnergyTopBar(
        context,
        showBack: true,
        onSettings: () {
          Navigator.pushNamed(
            context,
            SettingsScreen.routeName,
            arguments: const AppRouteConfig(showBackButton: true),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  _UserPromptCard(text: userPrompt),
                  if (showBirthChartVisual) ...[
                    const SizedBox(height: 14),
                    _AstroResultBlock(
                      child: _BirthChartVisualCard(
                        title: copy.birthChartTitle,
                        seed: birthChartSeed ??
                            '$userPrompt|$summary|${highlights.join("|")}',
                      ),
                    )
                  ],
                  const SizedBox(height: 14),
                  _AstroResultBlock(
                    child: _AstroSectionCard(
                      heading: l10n.resultSectionArcaneSnapshot,
                      lead: title,
                      body: summary,
                    ),
                  ),
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _AstroResultBlock(
                      child: _AstroSectionCard(
                        heading: l10n.resultSectionWhy,
                        bulletLines: highlights,
                      ),
                    )
                  ],
                  const SizedBox(height: 14),
                  _AstroResultBlock(
                    child: _AstroSectionCard(
                      heading: l10n.resultSectionAction,
                      body: action,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AstroResultBlock(
                    child: SofiaPromoCard(prefilledMessage: sofiaPrefill),
                  ),
                  const SizedBox(height: 14),
                  _AstroResultBlock(
                    child: _ReferralCard(copy: copy),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
            _AstroActionBar(
              newLabel: l10n.resultNewButton,
              tarotLabel: copy.tarotCtaButton,
              onNew: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              onTarot: () {
                if (tarotPrompt.isNotEmpty) {
                  ref
                      .read(readingFlowControllerProvider.notifier)
                      .setQuestion(tarotPrompt);
                }
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AstroSectionCard extends StatelessWidget {
  const _AstroSectionCard({
    required this.heading,
    this.lead,
    this.body,
    this.bulletLines,
  });

  final String heading;
  final String? lead;
  final String? body;
  final List<String>? bulletLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (lead != null && lead!.trim().isNotEmpty) ...[
          Text(
            lead!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
        ],
        if (body != null && body!.trim().isNotEmpty) Text(body!),
        if (bulletLines != null)
          for (final line in bulletLines!) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('• '),
                ),
                Expanded(child: Text(line)),
              ],
            ),
            if (line != bulletLines!.last) const SizedBox(height: 6),
          ],
      ],
    );
  }
}

class _AstroResultBlock extends StatelessWidget {
  const _AstroResultBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surface.withValues(alpha: 0.46),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: child,
    );
  }
}

class _UserPromptCard extends StatelessWidget {
  const _UserPromptCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.95),
              colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _AstroActionBar extends StatelessWidget {
  const _AstroActionBar({
    required this.newLabel,
    required this.onNew,
    required this.tarotLabel,
    required this.onTarot,
  });

  final String newLabel;
  final String tarotLabel;
  final VoidCallback onNew;
  final VoidCallback onTarot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onNew,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AstroActionIcon(
                          kind: _AstroActionIconKind.newReading,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(newLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTarot,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _AstroActionIcon(
                          kind: _AstroActionIconKind.tarot,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(tarotLabel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AstroActionIconKind { newReading, tarot }

class _AstroActionIcon extends StatelessWidget {
  const _AstroActionIcon({
    required this.kind,
    required this.color,
  });

  final _AstroActionIconKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final svg = switch (kind) {
      _AstroActionIconKind.newReading => '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="4.2" y="6.2" width="10.4" height="13.2" rx="2.1" fill="none" stroke="#ffffff" stroke-width="1.8"/>
  <rect x="9.4" y="4.4" width="10.4" height="13.2" rx="2.1" fill="none" stroke="#ffffff" stroke-width="1.8" opacity="0.9"/>
  <path d="M18.2 2.6v3.6M16.4 4.4H20" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''',
      _AstroActionIconKind.tarot => '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 3.4l1.3 3.1 3.1 1.3-3.1 1.3L12 12.2l-1.3-3.1-3.1-1.3 3.1-1.3L12 3.4z" fill="#ffffff"/>
  <path d="M18 11.4l0.8 1.9 1.9 0.8-1.9 0.8-0.8 1.9-0.8-1.9-1.9-0.8 1.9-0.8 0.8-1.9z" fill="#ffffff" opacity="0.92"/>
  <path d="M7.2 14.2l1 2.4 2.4 1-2.4 1-1 2.4-1-2.4-2.4-1 2.4-1 1-2.4z" fill="#ffffff" opacity="0.88"/>
</svg>
''',
    };
    return SvgPicture.string(
      svg,
      width: 18,
      height: 18,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.copy});

  final _AstroResultCopy copy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = readTelegramUserProfile();
    final referralLink = profile == null
        ? 'https://t.me/tarot_arkana_bot/app'
        : buildReferralLinkForUserId(profile.userId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.referralTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(copy.referralBody),
        const SizedBox(height: 12),
        AppGhostButton(
          label: copy.referralButton,
          icon: Icons.ios_share,
          onPressed: () async {
            final textToCopy = '${copy.referralShareMessage}\n$referralLink';
            await Clipboard.setData(ClipboardData(text: textToCopy));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(copy.referralCopied)),
              );
            }
            final shareUri = Uri.parse(
              'https://t.me/share/url?url=${Uri.encodeComponent(referralLink)}'
              '&text=${Uri.encodeComponent(copy.referralShareMessage)}',
            );
            await launchUrl(shareUri, mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }
}

class _AstroResultCopy {
  const _AstroResultCopy({
    required this.highlightsTitle,
    required this.actionTitle,
    required this.newButton,
    required this.referralTitle,
    required this.referralBody,
    required this.referralButton,
    required this.birthChartTitle,
    required this.tarotCtaButton,
    required this.referralCopied,
    required this.referralShareMessage,
  });

  final String highlightsTitle;
  final String actionTitle;
  final String newButton;
  final String referralTitle;
  final String referralBody;
  final String referralButton;
  final String birthChartTitle;
  final String tarotCtaButton;
  final String referralCopied;
  final String referralShareMessage;

  static _AstroResultCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _AstroResultCopy(
        highlightsTitle: 'Ключевые акценты',
        actionTitle: 'Шаг действия',
        newButton: 'Новый запрос',
        referralTitle: 'Бонус за рекомендацию',
        referralBody:
            'Поделись персональной ссылкой с друзьями и получай 20 бесплатных премиум-раскладов на 5 карт, 20 тестов на совместимость и 20 натальных карт за каждого нового пользователя.',
        referralButton: 'Поделиться ссылкой',
        birthChartTitle: 'Твоя карта рождения',
        tarotCtaButton: 'Сделать расклад Таро',
        referralCopied:
            'Реферальная ссылка скопирована. Отправь ее в Telegram.',
        referralShareMessage:
            'Загляни в Basil Arcana: красивые и точные расклады Таро, совместимость и натальные карты прямо в Telegram.',
      );
    }
    if (code == 'kk') {
      return const _AstroResultCopy(
        highlightsTitle: 'Негізгі акценттер',
        actionTitle: 'Әрекет қадамы',
        newButton: 'Жаңа сұрау',
        referralTitle: 'Ұсыныс бонусы',
        referralBody:
            'Жеке сілтемеңді достарыңмен бөліс және әр жаңа қолданушы үшін 5 карталық 20 премиум жайылма, 20 үйлесімділік тесті және 20 наталдық карта ал.',
        referralButton: 'Сілтемемен бөлісу',
        birthChartTitle: 'Туу картаңыз',
        tarotCtaButton: 'Таро расклад жасау',
        referralCopied: 'Реферал сілтеме көшірілді. Оны Telegram-да жібер.',
        referralShareMessage:
            'Basil Arcana-ны байқап көр: Telegram ішіндегі Таро жайылмалары, үйлесімділік және наталдық карталар.',
      );
    }
    return const _AstroResultCopy(
      highlightsTitle: 'Key Highlights',
      actionTitle: 'Action Step',
      newButton: 'New request',
      referralTitle: 'Referral bonus',
      referralBody:
          'Share your personal link with friends and get 20 free premium five-card readings, 20 compatibility tests, and 20 natal charts for every new user who joins.',
      referralButton: 'Share link',
      birthChartTitle: 'Your birth map',
      tarotCtaButton: 'Do a Tarot spread',
      referralCopied: 'Referral link copied. Send it in Telegram.',
      referralShareMessage:
          'Try Basil Arcana: stylish Tarot readings, compatibility checks, and natal charts right in Telegram.',
    );
  }
}

class _BirthChartVisualCard extends StatelessWidget {
  const _BirthChartVisualCard({
    required this.title,
    required this.seed,
  });

  final String title;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: CustomPaint(
                    painter: _BirthChartPainter(
                      seed: seed,
                      primary: colorScheme.primary,
                      accent: colorScheme.secondary,
                      lineColor: colorScheme.onSurface.withValues(alpha: 0.65),
                      progress: progress,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _AspectLegendChip(
                color: const Color(0xFF7BB9FF),
                label: _legendLabel(context, kind: _AspectKind.trine),
              ),
              _AspectLegendChip(
                color: const Color(0xFFFFA38D),
                label: _legendLabel(context, kind: _AspectKind.square),
              ),
              _AspectLegendChip(
                color: const Color(0xFFCF9FFF),
                label: _legendLabel(context, kind: _AspectKind.opposition),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _legendLabel(BuildContext context, {required _AspectKind kind}) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return switch (kind) {
        _AspectKind.trine => 'Тригон',
        _AspectKind.square => 'Квадрат',
        _AspectKind.opposition => 'Оппозиция',
      };
    }
    if (code == 'kk') {
      return switch (kind) {
        _AspectKind.trine => 'Тригон',
        _AspectKind.square => 'Квадрат',
        _AspectKind.opposition => 'Оппозиция',
      };
    }
    return switch (kind) {
      _AspectKind.trine => 'Trine',
      _AspectKind.square => 'Square',
      _AspectKind.opposition => 'Opposition',
    };
  }
}

class _BirthChartPainter extends CustomPainter {
  _BirthChartPainter({
    required this.seed,
    required this.primary,
    required this.accent,
    required this.lineColor,
    required this.progress,
  });

  final String seed;
  final Color primary;
  final Color accent;
  final Color lineColor;
  final double progress;

  static const int _houses = 12;
  static const int _pointsCount = 10;
  static const List<String> _houseLabels = <String>[
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.16 * t),
          accent.withValues(alpha: 0.05 * t),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.7 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 0.92, ringPaint);
    canvas.drawCircle(center, radius * 0.72, ringPaint);
    canvas.drawCircle(center, radius * 0.48, ringPaint);
    canvas.drawCircle(
      center,
      radius * 0.98,
      ringPaint..color = lineColor.withValues(alpha: 0.32),
    );

    final housePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final housesToDraw = math.max(1, (_houses * t).round());
    for (var i = 0; i < housesToDraw; i++) {
      final angle = (2 * math.pi / _houses) * i - math.pi / 2;
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.48);
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.92);
      canvas.drawLine(p1, p2, housePaint);
      final labelPoint =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.95);
      _drawCircleLabel(
        canvas,
        text: _houseLabels[i],
        center: labelPoint,
        color: lineColor.withValues(alpha: 0.72 * t),
        fontSize: 8.4,
        weight: FontWeight.w600,
      );
    }

    final angles = _seededAngles(seed, _pointsCount);
    final positions = <Offset>[];
    for (var i = 0; i < angles.length; i++) {
      final a = angles[i];
      final orbitScale = 0.53 + (i % 3) * 0.12;
      positions.add(
        center + Offset(math.cos(a), math.sin(a)) * (radius * orbitScale),
      );
    }

    _drawAspectLines(
      canvas,
      positions: positions,
      angles: angles,
      progress: t,
    );

    _drawAxisLabels(canvas, center, radius, t);

    final nodePaint = Paint()..style = PaintingStyle.fill;
    final lineBetweenNodes = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    Offset? first;
    Offset? prev;
    final pointsToDraw = math.max(1, (positions.length * t).round());
    for (var i = 0; i < pointsToDraw; i++) {
      final pos = positions[i];
      if (first == null) {
        first = pos;
      }
      if (prev != null && i.isEven) {
        canvas.drawLine(prev, pos, lineBetweenNodes);
      }
      prev = pos;
      nodePaint.color = i.isEven
          ? primary.withValues(alpha: 0.95 * t)
          : accent.withValues(alpha: 0.9 * t);
      canvas.drawCircle(pos, 4.2, nodePaint);
      canvas.drawCircle(
        pos,
        8,
        Paint()
          ..color = nodePaint.color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
    }
    if (first != null && prev != null) {
      canvas.drawLine(
          prev,
          first,
          lineBetweenNodes
            ..color = lineBetweenNodes.color.withValues(alpha: 0.2));
    }
  }

  void _drawAxisLabels(Canvas canvas, Offset center, double radius, double t) {
    final axis = <(String, double)>[
      ('MC', -math.pi / 2),
      ('AC', 0),
      ('IC', math.pi / 2),
      ('DC', math.pi),
    ];
    for (final item in axis) {
      final point = center +
          Offset(math.cos(item.$2), math.sin(item.$2)) * (radius * 0.87);
      _drawCircleLabel(
        canvas,
        text: item.$1,
        center: point,
        color: primary.withValues(alpha: 0.9 * t),
        fontSize: 9.2,
        weight: FontWeight.w700,
      );
    }
  }

  void _drawAspectLines(
    Canvas canvas, {
    required List<Offset> positions,
    required List<double> angles,
    required double progress,
  }) {
    final pointsToDraw = math.max(1, (angles.length * progress).round());
    for (var i = 0; i < pointsToDraw; i++) {
      for (var j = i + 1; j < angles.length; j++) {
        if (j >= pointsToDraw) {
          continue;
        }
        final delta = _angularDistance(angles[i], angles[j]);
        if ((delta - (2 * math.pi / 3)).abs() < 0.16) {
          final paint = Paint()
            ..color = const Color(0xFF7BB9FF).withValues(alpha: 0.34)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawLine(positions[i], positions[j], paint);
          continue;
        }
        if ((delta - (math.pi / 2)).abs() < 0.12) {
          final paint = Paint()
            ..color = const Color(0xFFFFA38D).withValues(alpha: 0.26)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1;
          _drawDashedLine(canvas, positions[i], positions[j], paint);
          continue;
        }
        if ((delta - math.pi).abs() < 0.11) {
          final paint = Paint()
            ..color = const Color(0xFFCF9FFF).withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawLine(positions[i], positions[j], paint);
        }
      }
    }
  }

  double _angularDistance(double a, double b) {
    final diff = (a - b).abs();
    return math.min(diff, (2 * math.pi) - diff);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
  ) {
    const dash = 5.0;
    const gap = 4.0;
    final vector = to - from;
    final length = vector.distance;
    if (length <= 0) {
      return;
    }
    final dir = Offset(vector.dx / length, vector.dy / length);
    var drawn = 0.0;
    while (drawn < length) {
      final start = from + dir * drawn;
      final end = from + dir * math.min(drawn + dash, length);
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  void _drawCircleLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required Color color,
    required double fontSize,
    required FontWeight weight,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  List<double> _seededAngles(String seed, int count) {
    var hash = 2166136261;
    for (final code in seed.codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    final rand = math.Random(hash);
    final values = <double>[];
    for (var i = 0; i < count; i++) {
      values.add((rand.nextDouble() * 2 * math.pi));
    }
    values.sort();
    return values;
  }

  @override
  bool shouldRepaint(covariant _BirthChartPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.progress != progress;
  }
}

enum _AspectKind { trine, square, opposition }

class _AspectLegendChip extends StatelessWidget {
  const _AspectLegendChip({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
