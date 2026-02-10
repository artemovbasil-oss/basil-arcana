import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import 'energy_widgets.dart';
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
          child: showSettings
              ? IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: AppLocalizations.of(context).settingsTitle,
                  onPressed: onSettings,
                )
              : null,
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
    );
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
    final primary = theme.colorScheme.primary;
    final isLow = energy.clampedValue < 15;
    if (isLow && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!isLow && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.5;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final curveT = Curves.easeInOutSine.transform(_controller.value);
        final pulse = isLow ? (0.97 + 0.05 * curveT) : 1.0;
        final glow = isLow ? (0.28 + 0.24 * curveT) : 0.18;
        return Transform.scale(
          scale: pulse,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.95),
                  primary.withOpacity(0.68),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(glow),
                  blurRadius: isLow ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: energy.progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          l10n.energyLabelWithPercent(energy.percent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (energy.isNearEmpty)
                      IconButton(
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        tooltip: l10n.energyTopUpButton,
                        onPressed: () async {
                          await showEnergyTopUpSheet(context, ref);
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
