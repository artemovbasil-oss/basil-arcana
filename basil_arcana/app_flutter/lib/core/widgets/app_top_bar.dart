import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import 'energy_widgets.dart';
import '../telegram/telegram_user_profile.dart';
import '../../state/providers.dart';

PreferredSizeWidget buildTopBar(
  BuildContext context, {
  required Widget title,
  bool showBack = false,
  VoidCallback? onBack,
  List<Widget>? actions,
}) {
  final canPop = Navigator.canPop(context);
  final shouldShowBack = showBack && (canPop || onBack != null);
  return AppBar(
    title: title,
    actions: actions,
    automaticallyImplyLeading: shouldShowBack,
    leading: shouldShowBack
        ? BackButton(
            onPressed: () async {
              final didPop = await Navigator.maybePop(context);
              if (!didPop && onBack != null) {
                onBack();
              }
            },
          )
        : null,
  );
}

PreferredSizeWidget buildEnergyTopBar(
  BuildContext context, {
  bool showBack = false,
  VoidCallback? onBack,
  bool showSettings = true,
  VoidCallback? onSettings,
  Widget? leadingFallback,
}) {
  final canPop = Navigator.canPop(context);
  final shouldShowBack = showBack && (canPop || onBack != null);
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 66,
    titleSpacing: 12,
    title: Row(
      children: [
        _TopBarActionSlot(
          child: shouldShowBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final didPop = await Navigator.maybePop(context);
                    if (!didPop && onBack != null) {
                      onBack();
                    }
                  },
                )
              : leadingFallback,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _EnergyHeaderPill(),
        ),
        const SizedBox(width: 8),
        _TopBarActionSlot(
          child:
              showSettings ? _TopBarProfileButton(onPressed: onSettings) : null,
        ),
      ],
    ),
  );
}

class _TopBarActionSlot extends StatelessWidget {
  const _TopBarActionSlot({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: child ?? const SizedBox.shrink(),
    );
  }
}

class _TopBarProfileButton extends StatelessWidget {
  const _TopBarProfileButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final profile = readTelegramUserProfile();
    final initials = profile?.initials ?? 'BA';
    final photoUrl = profile?.photoUrl ?? '';
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: AppLocalizations.of(context).settingsTitle,
        onPressed: onPressed,
        icon: photoUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  photoUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _InitialsAvatar(initials: initials);
                  },
                ),
              )
            : _InitialsAvatar(initials: initials),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF8F4BFF),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EnergyHeaderPill extends ConsumerStatefulWidget {
  const _EnergyHeaderPill();

  @override
  ConsumerState<_EnergyHeaderPill> createState() => _EnergyHeaderPillState();
}

class _EnergyHeaderPillState extends ConsumerState<_EnergyHeaderPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
      value: 0.5,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final energy = ref.watch(energyProvider);
    final energyValueText = energy.isUnlimited ? '∞' : '${energy.percent}%';
    final isLow = energy.clampedValue < 15;
    const vividPurple = Color(0xFFA05CFF);
    const darkBurgundy = Color(0xFF4A102A);
    const nearBlack = Color(0xFF08060C);
    final progress = energy.progress.clamp(0, 1);
    final base = progress >= 0.5
        ? Color.lerp(darkBurgundy, vividPurple, (progress - 0.5) * 2)!
        : Color.lerp(nearBlack, darkBurgundy, progress * 2)!;
    final end = Color.lerp(base, nearBlack, 0.48)!;
    final edge = Color.lerp(base, Colors.white, 0.08)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final curveT = Curves.easeInOutSine.transform(_controller.value);
        final pulse =
            isLow ? (0.988 + 0.03 * curveT) : (0.996 + 0.012 * curveT);
        final glow = isLow ? (0.25 + 0.22 * curveT) : (0.1 + 0.1 * curveT);
        return Transform.scale(
          scale: pulse,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () async {
                await showEnergyTopUpSheet(context, ref);
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      base,
                      end,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border.all(color: edge),
                  boxShadow: [
                    BoxShadow(
                      color: base.withOpacity(glow),
                      blurRadius: isLow ? 16 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.energyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      energyValueText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
