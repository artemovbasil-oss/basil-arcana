import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

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
              : null,
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
      duration: const Duration(milliseconds: 1800),
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
    final primary = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                primary.withOpacity(0.95 - 0.1 * t),
                primary.withOpacity(0.6 + 0.15 * t),
              ],
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 - 2 * t, 1),
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.25 + 0.15 * t),
                blurRadius: 14 + 6 * t,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                l10n.energyLabelWithPercent(energy.percent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
