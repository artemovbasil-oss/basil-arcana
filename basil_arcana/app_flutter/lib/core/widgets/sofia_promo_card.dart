import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../config/assets_config.dart';
import 'app_buttons.dart';
import 'tarot_asset_widgets.dart';

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
    this.prefilledMessage,
  });

  final bool compact;
  final String? prefilledMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
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
    final assetsBaseUrl = AssetsConfig.assetsBaseUrl;
    final mediaAspectRatio = compact ? 3 / 4 : 3 / 4;

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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: colorScheme.surface.withValues(alpha: 0.45),
                child: AspectRatio(
                  aspectRatio: mediaAspectRatio,
                  child: CardMedia(
                    cardId: 'sofia_promo',
                    imageUrl: '$assetsBaseUrl/sofia/sofia.webp',
                    videoUrl: '$assetsBaseUrl/sofia/sofia.webm',
                    fit: BoxFit.contain,
                    showGlow: false,
                    enableVideo: true,
                    autoPlayOnce: true,
                    playLabel: l10n.videoTapToPlay,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 4),
                Text(subtitle, style: bodyStyle),
              ],
            ),
            const SizedBox(height: 12),
            AppGhostButton(
              label: buttonLabel,
              onPressed: () async {
                final message = _buildMessage(prefilledMessage, localeCode);
                if (message.isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_copiedHint(localeCode)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
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

  String _buildMessage(String? raw, String localeCode) {
    final summary = _trimForMessage((raw ?? '').trim(), maxChars: 1200);
    if (summary.isEmpty) {
      return '';
    }
    if (localeCode == 'ru') {
      return 'Привет, София! Хочу личную консультацию.\n\nКратко о моем раскладе:\n$summary';
    }
    if (localeCode == 'kk') {
      return 'Сәлем, София! Жеке консультация алғым келеді.\n\nМенің қысқаша нәтижем:\n$summary';
    }
    return 'Hi Sofia! I would like a personal consultation.\n\nShort summary of my reading:\n$summary';
  }

  String _trimForMessage(String source, {required int maxChars}) {
    if (source.length <= maxChars) {
      return source;
    }
    return '${source.substring(0, maxChars).trimRight()}...';
  }

  String _copiedHint(String localeCode) {
    if (localeCode == 'ru') {
      return 'Краткое саммари скопировано. Вставь его в сообщение Софии.';
    }
    if (localeCode == 'kk') {
      return 'Қысқаша нәтиже көшірілді. Оны Софияға хабарламаға қой.';
    }
    return 'Summary copied. Paste it into your message to Sofia.';
  }
}
