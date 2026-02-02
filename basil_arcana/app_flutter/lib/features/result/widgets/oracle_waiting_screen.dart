import 'dart:async';

import 'package:flutter/material.dart';

class OracleWaitingScreen extends StatefulWidget {
  const OracleWaitingScreen({
    super.key,
    required this.onCancel,
  });

  final VoidCallback onCancel;

  @override
  State<OracleWaitingScreen> createState() => _OracleWaitingScreenState();
}

class _OracleWaitingScreenState extends State<OracleWaitingScreen> {
  static const _pulseDuration = Duration(milliseconds: 3600);
  Timer? _pulseTimer;
  bool _glowVisible = true;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer.periodic(_pulseDuration, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _glowVisible = !_glowVisible;
      });
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.background;
    final glowColor = theme.colorScheme.primary.withOpacity(0.35);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _glowVisible ? 0.9 : 0.45,
              duration: _pulseDuration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(
                    color: glowColor.withOpacity(0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 120,
                      spreadRadius: 35,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The Oracle is listening…',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onBackground,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
