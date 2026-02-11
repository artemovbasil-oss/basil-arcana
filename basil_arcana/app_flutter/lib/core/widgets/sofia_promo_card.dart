import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_buttons.dart';

const String kSofiaProfileUrl = 'https://t.me/SofiaKnoxx';

class SofiaPromoParts {
  const SofiaPromoParts({
    required this.content,
    required this.promoText,
  });

  final String content;
  final String promoText;

  bool get hasPromo => promoText.isNotEmpty;
}

SofiaPromoParts splitSofiaPromo(String text) {
  final source = text.trim();
  if (source.isEmpty) {
    return const SofiaPromoParts(content: '', promoText: '');
  }
  final index = source.indexOf(kSofiaProfileUrl);
  if (index < 0) {
    return SofiaPromoParts(content: source, promoText: '');
  }
  final promoStart = source.lastIndexOf('\n\n', index);
  if (promoStart < 0) {
    if (!_looksLikeSofiaPromo(source)) {
      return SofiaPromoParts(content: source, promoText: '');
    }
    return SofiaPromoParts(content: '', promoText: source);
  }
  return SofiaPromoParts(
    content: source.substring(0, promoStart).trimRight(),
    promoText: source.substring(promoStart + 2).trim(),
  );
}

bool containsSofiaPromo(String text) => splitSofiaPromo(text).hasPromo;

String stripSofiaPromo(String text) => splitSofiaPromo(text).content;

bool _looksLikeSofiaPromo(String source) {
  return source.contains('Софии Нокс') ||
      source.contains('София Нокс') ||
      source.contains('Sofia Knox');
}

class SofiaPromoCard extends StatelessWidget {
  const SofiaPromoCard({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final localeCode = Localizations.localeOf(context).languageCode;
    final title = _title(localeCode);
    final subtitle = _subtitle(localeCode);
    final buttonLabel = _buttonLabel(localeCode);
    final tip = _tip(localeCode);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colorScheme.surface.withValues(alpha: 0.96),
            colorScheme.primary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.6)),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      const SizedBox(height: 4),
                      Text(subtitle, style: bodyStyle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppGhostButton(
              label: buttonLabel,
              icon: Icons.open_in_new,
              onPressed: () async {
                await launchUrl(
                  Uri.parse(kSofiaProfileUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(String localeCode) {
    if (localeCode == 'ru') {
      return 'Глубокая личная консультация';
    }
    if (localeCode == 'kk') {
      return 'Терең жеке консультация';
    }
    return 'Deep Personal Consultation';
  }

  String _subtitle(String localeCode) {
    if (localeCode == 'ru') {
      return 'Профессиональный таролог и астролог София Нокс поможет разобрать твой запрос глубже и точнее.';
    }
    if (localeCode == 'kk') {
      return 'Кәсіби таролог және астролог София Нокс сұрағыңды тереңірек әрі нақтырақ талдауға көмектеседі.';
    }
    return 'Professional tarot reader and astrologer Sofia Knox can unpack your question with deeper precision.';
  }

  String _buttonLabel(String localeCode) {
    if (localeCode == 'ru') {
      return 'Открыть профиль Софии';
    }
    if (localeCode == 'kk') {
      return 'София профилін ашу';
    }
    return 'Open Sofia profile';
  }

  String _tip(String localeCode) {
    if (localeCode == 'ru') {
      return 'Подключи подписку в нашем Telegram-боте, чтобы оформить персональную консультацию.';
    }
    if (localeCode == 'kk') {
      return 'Жеке консультация алу үшін Telegram-боттағы жазылымды қос.';
    }
    return 'Activate a subscription in our Telegram bot to book a personal consultation.';
  }
}
