import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/app_config.dart';
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
const String _deckSplashVideoUrl =
    'https://basilarcana-assets.b-cdn.net/splash/splash.mp4';
const String _settingsBoxName = 'settings';
const String _splashOnboardingSeenKey = 'splashOnboardingSeenV1';

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;
  Timer? _hardTimeoutTimer;
  Timer? _onboardingTimeoutTimer;
  late final bool _canNavigate;
  late final bool _enableSplashVideo;
  bool _hasShownOnboarding = false;
  bool _showOnboarding = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _canNavigate = AppConfig.isConfigured;
    _enableSplashVideo = !(kIsWeb &&
        TelegramWebApp.isTelegramWebView &&
        TelegramWebApp.isTelegramMobile);
    final box = Hive.box<String>(_settingsBoxName);
    _hasShownOnboarding = (box.get(_splashOnboardingSeenKey) ?? '') == '1';
    if (TelegramWebApp.isTelegramWebView) {
      TelegramWebApp.expand();
      TelegramWebApp.disableVerticalSwipes();
    }
    _hardTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _didNavigate) {
        return;
      }
      _goHome();
    });
    _navigationTimer = Timer(const Duration(seconds: 3), () {
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
      _onboardingTimeoutTimer?.cancel();
      _onboardingTimeoutTimer = Timer(const Duration(seconds: 8), () {
        if (!mounted || _didNavigate) {
          return;
        }
        _goHome();
      });
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _hardTimeoutTimer?.cancel();
    _onboardingTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final useTelegramSafeArea =
        TelegramWebApp.isTelegramWebView && TelegramWebApp.isTelegramMobile;
    final errorMessage = AppConfig.lastError?.trim().isNotEmpty == true
        ? AppConfig.lastError!.trim()
        : 'Missing configuration: API_BASE_URL';
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DeckSplashMedia(
            posterUrl: _deckSplashPosterUrl,
            videoUrl: _deckSplashVideoUrl,
            enableVideo: _enableSplashVideo,
          ),
          SafeArea(
            top: useTelegramSafeArea,
            child: !_canNavigate
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onBackground,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_showOnboarding)
            _SplashOnboardingOverlay(
              onClose: () async {
                final box = Hive.box<String>(_settingsBoxName);
                await box.put(_splashOnboardingSeenKey, '1');
                if (!mounted) {
                  return;
                }
                setState(() {
                  _hasShownOnboarding = true;
                  _showOnboarding = false;
                });
                _onboardingTimeoutTimer?.cancel();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: appRouteSettings(showBackButton: false),
          builder: (_) => const HomeScreen(),
        ),
      );
    });
  }
}

class DeckSplashMedia extends StatefulWidget {
  const DeckSplashMedia({
    super.key,
    required this.posterUrl,
    required this.videoUrl,
    required this.enableVideo,
  });

  final String posterUrl;
  final String videoUrl;
  final bool enableVideo;

  @override
  State<DeckSplashMedia> createState() => _DeckSplashMediaState();
}

class _DeckSplashMediaState extends State<DeckSplashMedia> {
  VideoPlayerController? _controller;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enableVideo) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
    });
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize().timeout(const Duration(seconds: 3));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.play();
      controller.addListener(_handleVideoStatus);
      setState(() {
        _controller = controller;
        _isVideoReady = controller.value.isInitialized;
      });
    } catch (_) {
      await controller.dispose();
    }
  }

  void _handleVideoStatus() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.value.hasError && _isVideoReady) {
      setState(() {
        _isVideoReady = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleVideoStatus);
    _controller?.dispose();
    super.dispose();
  }

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
          widget.posterUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
        AnimatedOpacity(
          opacity: _isVideoReady ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: _VideoCover(controller: _controller),
        ),
      ],
    );
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final size = controller.value.size;
    if (size.isEmpty) {
      return const SizedBox.expand();
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
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
