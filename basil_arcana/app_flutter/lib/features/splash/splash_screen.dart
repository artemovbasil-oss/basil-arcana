import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/app_config.dart';
import '../../core/telegram/telegram_web_app.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

const _deckSplashPosterUrl =
    'https://basilarcana-assets.b-cdn.net/deck/new-deck.webp';
const _deckSplashVideoUrl =
    'https://basilarcana-assets.b-cdn.net/deck/cover-video.webm';

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;
  late final bool _canNavigate;

  @override
  void initState() {
    super.initState();
    _canNavigate = AppConfig.isConfigured;
    if (TelegramWebApp.isTelegramWebView) {
      TelegramWebApp.expand();
      TelegramWebApp.disableVerticalSwipes();
    }
    if (_canNavigate) {
      _navigationTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      });
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
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
          const DeckSplashMedia(
            posterUrl: _deckSplashPosterUrl,
            videoUrl: _deckSplashVideoUrl,
          ),
          SafeArea(
            top: useTelegramSafeArea,
            child: _canNavigate
                ? const SizedBox.shrink()
                : Padding(
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
                  ),
          ),
        ],
      ),
    );
  }
}

class DeckSplashMedia extends StatefulWidget {
  const DeckSplashMedia({
    super.key,
    required this.posterUrl,
    required this.videoUrl,
  });

  final String posterUrl;
  final String videoUrl;

  @override
  State<DeckSplashMedia> createState() => _DeckSplashMediaState();
}

class _DeckSplashMediaState extends State<DeckSplashMedia> {
  VideoPlayerController? _controller;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
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
      await controller.setLooping(true);
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
        Image.network(
          widget.posterUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
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
        fit: BoxFit.cover,
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
