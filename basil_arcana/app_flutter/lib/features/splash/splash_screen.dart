import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_web_app.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

const String _deckSplashPosterUrl =
    'https://basilarcana-assets.b-cdn.net/splash/splash.webp?v=20260216';

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _fallbackTimer;
  bool _didNavigate = false;
  late final AnimationController _zoomController;
  late final Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();
    if (TelegramWebApp.isTelegramWebView) {
      TelegramWebApp.expand();
      TelegramWebApp.disableVerticalSwipes();
    }

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _zoomAnimation = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOut),
    );
    _zoomController.addStatusListener(_handleZoomStatus);
    _zoomController.forward();

    _fallbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _didNavigate) {
        return;
      }
      _goHome();
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _zoomController.removeStatusListener(_handleZoomStatus);
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
          AnimatedBuilder(
            animation: _zoomAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _zoomAnimation.value,
                child: child,
              );
            },
            child: Image.network(
              _deckSplashPosterUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.expand(),
            ),
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: false),
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  void _handleZoomStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goHome();
    }
  }
}
