import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/telegram/telegram_web_app.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final bool _canNavigate;

  @override
  void initState() {
    super.initState();
    _canNavigate = AppConfig.isConfigured;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scale = Tween<double>(begin: 1.12, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward().whenComplete(() async {
      if (!_canNavigate) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
      body: SafeArea(
        top: useTelegramSafeArea,
        child: _canNavigate
            ? Center(
                child: FadeTransition(
                  opacity: _opacity,
                  child: ScaleTransition(
                    scale: _scale,
                    child: SizedBox.expand(
                      child: Image.asset(
                        'assets/deck/cover.webp',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              )
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onBackground,
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
