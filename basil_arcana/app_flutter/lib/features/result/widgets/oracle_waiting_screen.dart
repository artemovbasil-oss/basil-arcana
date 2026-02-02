import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

class OracleWaitingScreen extends StatefulWidget {
  const OracleWaitingScreen({
    super.key,
    required this.onCancel,
    this.onRetry,
    this.isTimeout = false,
  }) : assert(isTimeout == false || onRetry != null);

  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final bool isTimeout;

  @override
  State<OracleWaitingScreen> createState() => _OracleWaitingScreenState();
}

class _OracleWaitingScreenState extends State<OracleWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.background;
    final glowColor = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      _controller.stop();
      if (_controller.value != 0.4) {
        _controller.value = 0.4;
      }
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
    final title = widget.isTimeout
        ? l10n.oracleTimeoutTitle
        : l10n.oracleWaitingTitle;
    final subtitle = widget.isTimeout
        ? l10n.oracleTimeoutBody
        : l10n.oracleWaitingSubtitle;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final t = disableAnimations ? 0.4 : _breath.value;
                return _OracleGlowLayer(
                  background: background,
                  glowColor: glowColor,
                  t: t,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onBackground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onBackground.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed:
                            widget.isTimeout ? widget.onRetry : widget.onCancel,
                        child: Text(
                          widget.isTimeout
                              ? l10n.actionTryAgain
                              : l10n.actionCancel,
                        ),
                      ),
                      if (widget.isTimeout) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: widget.onCancel,
                          child: Text(l10n.actionCancel),
                        ),
                      ],
                    ],
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(opacity),
                color.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OracleThinkingGlow extends StatefulWidget {
  const OracleThinkingGlow({
    super.key,
    this.height = 180,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final double height;
  final BorderRadius borderRadius;

  @override
  State<OracleThinkingGlow> createState() => _OracleThinkingGlowState();
}

class _OracleThinkingGlowState extends State<OracleThinkingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.background;
    final glowColor = theme.colorScheme.primary;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      _controller.stop();
      if (_controller.value != 0.4) {
        _controller.value = 0.4;
      }
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) {
            final t = disableAnimations ? 0.4 : _breath.value;
            return _OracleGlowLayer(
              background: background,
              glowColor: glowColor,
              t: t,
            );
          },
        ),
      ),
    );
  }
}

class _OracleGlowLayer extends StatelessWidget {
  const _OracleGlowLayer({
    required this.background,
    required this.glowColor,
    required this.t,
  });

  final Color background;
  final Color glowColor;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: background)),
        _GlowOrb(
          alignment: Alignment.topLeft,
          color: glowColor,
          size: lerpDouble(220, 320, t)!,
          opacity: lerpDouble(0.25, 0.6, t)!,
        ),
        _GlowOrb(
          alignment: Alignment.topRight,
          color: glowColor,
          size: lerpDouble(200, 300, t)!,
          opacity: lerpDouble(0.2, 0.55, t)!,
        ),
        _GlowOrb(
          alignment: Alignment.bottomLeft,
          color: glowColor,
          size: lerpDouble(240, 340, t)!,
          opacity: lerpDouble(0.25, 0.65, t)!,
        ),
        _GlowOrb(
          alignment: Alignment.bottomRight,
          color: glowColor,
          size: lerpDouble(210, 320, t)!,
          opacity: lerpDouble(0.22, 0.6, t)!,
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: lerpDouble(24, 60, t)!,
              sigmaY: lerpDouble(24, 60, t)!,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
