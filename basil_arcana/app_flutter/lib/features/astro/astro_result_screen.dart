import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_user_profile.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../state/providers.dart';
import '../result/widgets/chat_widgets.dart';
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
                  ChatBubble(
                    isUser: true,
                    avatarEmoji: '🙂',
                    child: Text(userPrompt),
                  ),
                  const SizedBox(height: 14),
                  ChatBubble(
                    isUser: false,
                    avatarEmoji: '🪄',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(summary),
                      ],
                    ),
                  ),
                  if (showBirthChartVisual) ...[
                    const SizedBox(height: 14),
                    ChatBubble(
                      isUser: false,
                      avatarEmoji: '🪄',
                      child: _BirthChartVisualCard(
                        title: copy.birthChartTitle,
                        seed: birthChartSeed ??
                            '$userPrompt|$summary|${highlights.join("|")}',
                      ),
                    ),
                  ],
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ChatBubble(
                      isUser: false,
                      avatarEmoji: '🪄',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.highlightsTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final line in highlights) ...[
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
                            if (line != highlights.last)
                              const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ChatBubble(
                    isUser: false,
                    avatarEmoji: '🪄',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.actionTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(action),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ChatBubble(
                    isUser: false,
                    avatarEmoji: '🪄',
                    child: SofiaPromoCard(prefilledMessage: sofiaPrefill),
                  ),
                  const SizedBox(height: 14),
                  ChatBubble(
                    isUser: false,
                    avatarEmoji: '🪄',
                    child: _ReferralCard(copy: copy),
                  ),
                  if (tarotQuestion != null &&
                      tarotQuestion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ChatBubble(
                      isUser: false,
                      avatarEmoji: '🪄',
                      child: SizedBox(
                        width: double.infinity,
                        child: AppPrimaryButton(
                          label: copy.tarotCtaButton,
                          icon: Icons.auto_awesome,
                          onPressed: () {
                            ref
                                .read(readingFlowControllerProvider.notifier)
                                .setQuestion(tarotQuestion!.trim());
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: AppGhostButton(
                    label: copy.newButton,
                    icon: Icons.auto_awesome,
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.primary.withValues(alpha: 0.06),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
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
      ),
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
        birthChartTitle: 'Ваша карта рождения',
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _BirthChartPainter(
                seed: seed,
                primary: colorScheme.primary,
                accent: colorScheme.secondary,
                lineColor: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthChartPainter extends CustomPainter {
  _BirthChartPainter({
    required this.seed,
    required this.primary,
    required this.accent,
    required this.lineColor,
  });

  final String seed;
  final Color primary;
  final Color accent;
  final Color lineColor;

  static const int _houses = 12;
  static const int _pointsCount = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.16),
          accent.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 0.92, ringPaint);
    canvas.drawCircle(center, radius * 0.72, ringPaint);
    canvas.drawCircle(center, radius * 0.48, ringPaint);

    final housePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 0; i < _houses; i++) {
      final angle = (2 * math.pi / _houses) * i - math.pi / 2;
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.48);
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.92);
      canvas.drawLine(p1, p2, housePaint);
    }

    final angles = _seededAngles(seed, _pointsCount);
    final nodePaint = Paint()..style = PaintingStyle.fill;
    final lineBetweenNodes = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    Offset? first;
    Offset? prev;
    for (var i = 0; i < angles.length; i++) {
      final a = angles[i];
      final orbitScale = 0.53 + (i % 3) * 0.12;
      final pos =
          center + Offset(math.cos(a), math.sin(a)) * (radius * orbitScale);
      if (first == null) {
        first = pos;
      }
      if (prev != null && i.isEven) {
        canvas.drawLine(prev, pos, lineBetweenNodes);
      }
      prev = pos;
      nodePaint.color = i.isEven
          ? primary.withValues(alpha: 0.95)
          : accent.withValues(alpha: 0.9);
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
        oldDelegate.lineColor != lineColor;
  }
}
