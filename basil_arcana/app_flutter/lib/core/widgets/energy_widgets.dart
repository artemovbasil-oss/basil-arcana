import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../state/energy_controller.dart';
import '../../state/providers.dart';
import 'app_buttons.dart';

Future<bool> trySpendEnergyForAction(
  BuildContext context,
  WidgetRef ref,
  EnergyAction action,
) async {
  final ok = await ref.read(energyProvider.notifier).spend(action);
  if (ok) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
        content: Text(l10n.energyInsufficientForAction(action.cost.round()))),
  );
  await showEnergyTopUpSheet(context, ref);
  return false;
}

Future<void> showEnergyTopUpSheet(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.energyTopUpTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.energyTopUpDescription,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: l10n.energyPackSmall,
                onPressed: () async {
                  await ref.read(energyProvider.notifier).addEnergy(25);
                  if (!sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.energyTopUpSuccess(25)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              AppPrimaryButton(
                label: l10n.energyPackMedium,
                onPressed: () async {
                  await ref.read(energyProvider.notifier).addEnergy(50);
                  if (!sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.energyTopUpSuccess(50)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              AppGhostButton(
                label: l10n.energyPackFull,
                icon: Icons.flash_on,
                onPressed: () async {
                  await ref.read(energyProvider.notifier).fillToMax();
                  if (!sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.energyTopUpSuccess(100))),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class EnergyStatusCard extends ConsumerWidget {
  const EnergyStatusCard({
    super.key,
    this.actionCost,
    this.onTopUpPressed,
  });

  final double? actionCost;
  final VoidCallback? onTopUpPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final energy = ref.watch(energyProvider);
    final duration = energy.timeToFull;
    final minutesLeft = duration.inMinutes;
    final recoveryText = duration == Duration.zero
        ? l10n.energyRecoveryReady
        : (minutesLeft < 1
            ? l10n.energyRecoveryLessThanMinute
            : l10n.energyRecoveryInMinutes(minutesLeft));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surface.withOpacity(0.9),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.energyLabelWithPercent(energy.percent),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (energy.isNearEmpty && onTopUpPressed != null)
                AppSmallButton(
                  label: l10n.energyTopUpButton,
                  onPressed: onTopUpPressed,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 6,
            value: energy.progress,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: colorScheme.surfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            recoveryText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.72),
                ),
          ),
          if (actionCost != null) ...[
            const SizedBox(height: 2),
            Text(
              l10n.energyActionCost(actionCost!.round()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.72),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
