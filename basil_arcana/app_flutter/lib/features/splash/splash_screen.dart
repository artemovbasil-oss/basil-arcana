import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_web_app.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

const String _deckSplashPosterUrl =
    'https://basilarcana-assets.b-cdn.net/splash/splash.webp';
const String _settingsBoxName = 'settings';
const String _splashOnboardingSeenKey = 'splashOnboardingSeenV1';

class _SplashScreenState extends State<SplashScreen> {
  Timer? _splashTimer;
  Timer? _forceHomeTimer;
  bool _hasShownOnboarding = false;
  bool _showOnboarding = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    final box = Hive.box<String>(_settingsBoxName);
    _hasShownOnboarding = (box.get(_splashOnboardingSeenKey) ?? '').isNotEmpty;
    if (TelegramWebApp.isTelegramWebView) {
      TelegramWebApp.expand();
      TelegramWebApp.disableVerticalSwipes();
    }
    _forceHomeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _didNavigate) {
        return;
      }
      _goHome();
    });
    _splashTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || _didNavigate) {
        return;
      }
      if (_hasShownOnboarding) {
        _goHome();
        return;
      }
      setState(() {
        _showOnboarding = true;
      });
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _forceHomeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _SplashBackdrop(
            imageUrl: _deckSplashPosterUrl,
            blur: _showOnboarding,
          ),
          if (_showOnboarding)
            _SplashOnboardingOverlay(
              onClose: () async {
                final box = Hive.box<String>(_settingsBoxName);
                await box.put(_splashOnboardingSeenKey, 'seen');
                if (!mounted) {
                  return;
                }
                setState(() {
                  _hasShownOnboarding = true;
                  _showOnboarding = false;
                });
                _goHome();
              },
            ),
        ],
      ),
    );
  }

  void _goHome() {
    if (!mounted || _didNavigate) {
      return;
    }
    _didNavigate = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: false),
        builder: (_) => const HomeScreen(),
      ),
      (_) => false,
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop({
    required this.imageUrl,
    required this.blur,
  });

  final String imageUrl;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF141218),
                Color(0xFF0F0F12),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
        if (blur)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: Container(color: Colors.black.withValues(alpha: 0.24)),
            ),
          ),
      ],
    );
  }
}

class _SplashOnboardingOverlay extends StatelessWidget {
  const _SplashOnboardingOverlay({
    required this.onClose,
  });

  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final copy = _SplashOnboardingCopy.resolve(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.42),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                _OnboardingBullet(
                  title: copy.itemLenormand,
                  subtitle: copy.itemLenormandHint,
                ),
                const SizedBox(height: 8),
                _OnboardingBullet(
                  title: copy.itemCompatibility,
                  subtitle: copy.itemCompatibilityHint,
                ),
                const SizedBox(height: 8),
                _OnboardingBullet(
                  title: copy.itemNatal,
                  subtitle: copy.itemNatalHint,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async => onClose(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(copy.closeButton),
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

class _OnboardingBullet extends StatelessWidget {
  const _OnboardingBullet({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text('✨'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplashOnboardingCopy {
  const _SplashOnboardingCopy({
    required this.title,
    required this.itemLenormand,
    required this.itemLenormandHint,
    required this.itemCompatibility,
    required this.itemCompatibilityHint,
    required this.itemNatal,
    required this.itemNatalHint,
    required this.closeButton,
  });

  final String title;
  final String itemLenormand;
  final String itemLenormandHint;
  final String itemCompatibility;
  final String itemCompatibilityHint;
  final String itemNatal;
  final String itemNatalHint;
  final String closeButton;

  static _SplashOnboardingCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _SplashOnboardingCopy(
        title: 'Добро пожаловать в магический вайб. Теперь у нас доступно:',
        itemLenormand: 'Гадание по колоде Ленорман',
        itemLenormandHint: 'Выбери колоду в профиле',
        itemCompatibility: 'Проверка совместимости пары',
        itemCompatibilityHint: 'Попробуй бесплатно',
        itemNatal: 'Чтение натальной карты',
        itemNatalHint: 'Попробуй бесплатно',
        closeButton: 'Отлично',
      );
    }
    if (code == 'kk') {
      return const _SplashOnboardingCopy(
        title: 'Сиқырлы вайбқа қош келдің. Енді мыналар қолжетімді:',
        itemLenormand: 'Ленорман колодасы бойынша болжау',
        itemLenormandHint: 'Колоданы профильден таңда',
        itemCompatibility: 'Жұп үйлесімділігін тексеру',
        itemCompatibilityHint: 'Тегін байқап көр',
        itemNatal: 'Наталдық картаны оқу',
        itemNatalHint: 'Тегін байқап көр',
        closeButton: 'Керемет',
      );
    }
    return const _SplashOnboardingCopy(
      title: 'Welcome to the magic vibe. You now have:',
      itemLenormand: 'Lenormand card reading',
      itemLenormandHint: 'Choose deck in profile',
      itemCompatibility: 'Couple compatibility check',
      itemCompatibilityHint: 'Try it for free',
      itemNatal: 'Natal chart reading',
      itemNatalHint: 'Try it for free',
      closeButton: 'Great',
    );
  }
}
