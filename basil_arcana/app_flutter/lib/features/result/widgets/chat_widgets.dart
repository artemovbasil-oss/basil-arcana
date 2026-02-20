import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_buttons.dart';

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.emoji,
    required this.backgroundColor,
    this.borderColor,
  });

  final String emoji;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? Colors.transparent),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: AppTextStyles.subtitle(context),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.isUser,
    required this.child,
    required this.avatarEmoji,
    this.fullWidth = false,
    this.showAvatar = true,
  });

  final bool isUser;
  final Widget child;
  final String avatarEmoji;
  final bool fullWidth;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: isUser
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.95),
                  colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            )
          : BoxDecoration(
              color: fullWidth
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.28)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: fullWidth
                  ? null
                  : Border.all(color: colorScheme.primary.withOpacity(0.3)),
              boxShadow: [
                if (!fullWidth)
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
      child: DefaultTextStyle.merge(
        style: isUser
            ? Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onPrimary)
            : Theme.of(context).textTheme.bodyMedium,
        child: child,
      ),
    );
    final bubble = fullWidth
        ? SizedBox(width: double.infinity, child: bubbleContent)
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: bubbleContent,
          );

    if (!showAvatar) {
      return bubble;
    }

    final avatar = AvatarCircle(
      emoji: avatarEmoji,
      backgroundColor: colorScheme.surfaceVariant,
      borderColor: colorScheme.primary.withOpacity(0.4),
    );

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isUser
          ? [
              Flexible(child: bubble),
              const SizedBox(width: 10),
              avatar,
            ]
          : [
              avatar,
              const SizedBox(width: 10),
              Flexible(child: bubble),
            ],
    );
  }
}

class TypingIndicatorBubble extends StatelessWidget {
  const TypingIndicatorBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatBubble(
      isUser: false,
      avatarEmoji: '🪄',
      fullWidth: true,
      showAvatar: false,
      child: const _TypingDots(),
    );
  }
}

class OracleTypingBubble extends StatelessWidget {
  const OracleTypingBubble({
    super.key,
    required this.label,
    this.cancelLabel,
    this.onCancel,
  });

  final String label;
  final String? cancelLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return ChatBubble(
      isUser: false,
      avatarEmoji: '🪄',
      fullWidth: true,
      showAvatar: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label)),
              const SizedBox(width: 6),
              const _TypingEllipsis(),
            ],
          ),
          if (cancelLabel != null && onCancel != null) ...[
            const SizedBox(height: 6),
            AppSmallButton(
              label: cancelLabel!,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value * 2 * pi;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = value + (index * pi / 2);
            final opacity = 0.3 + (0.7 * ((sin(phase) + 1) / 2));
            return Container(
              margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _TypingEllipsis extends StatefulWidget {
  const _TypingEllipsis();

  @override
  State<_TypingEllipsis> createState() => _TypingEllipsisState();
}

class _TypingEllipsisState extends State<_TypingEllipsis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final index = (_controller.value * 3).floor() % 3;
        final dots = '.' * (index + 1);
        return Text(
          dots,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }
}

class ChatBubbleReveal extends StatefulWidget {
  const ChatBubbleReveal({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ChatBubbleReveal> createState() => _ChatBubbleRevealState();
}

class _ChatBubbleRevealState extends State<ChatBubbleReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
