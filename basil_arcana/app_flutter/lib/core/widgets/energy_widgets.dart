import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_bridge.dart';
import '../../data/repositories/energy_topup_repository.dart';
import '../../state/energy_controller.dart';
import '../../state/providers.dart';
import 'app_buttons.dart';

const Map<EnergyPackId, int> _displayStarsByPack = {
  EnergyPackId.small: 25,
  EnergyPackId.medium: 45,
  EnergyPackId.full: 75,
  EnergyPackId.yearUnlimited: 6990,
};

const Map<EnergyPackId, int> _energyGainByPack = {
  EnergyPackId.small: 25,
  EnergyPackId.medium: 50,
  EnergyPackId.full: 100,
  EnergyPackId.yearUnlimited: 0,
};

String _packTitle(AppLocalizations l10n, EnergyPackId packId) {
  switch (packId) {
    case EnergyPackId.small:
      return l10n.energyPackSmall;
    case EnergyPackId.medium:
      return l10n.energyPackMedium;
    case EnergyPackId.full:
      return l10n.energyPackFull;
    case EnergyPackId.yearUnlimited:
      final normalized = l10n.energyPackYearUnlimited
          .replaceAll(RegExp(r'\s*[—-]\s*\d+\s*⭐\s*$', unicode: true), '')
          .trim();
      return normalized.isEmpty ? l10n.energyPackYearUnlimited : normalized;
  }
}

bool _shouldShowPack(EnergyState energy, EnergyPackId packId) {
  if (packId == EnergyPackId.yearUnlimited) {
    return true;
  }
  final gain = _energyGainByPack[packId] ?? 0;
  if (gain <= 0) {
    return false;
  }
  final missing = (100 - energy.clampedValue).clamp(0, 100).toDouble();
  return missing > 0 && gain <= missing;
}

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
  final energy = ref.read(energyProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      EnergyPackId? processingPack;
      return StatefulBuilder(
        builder: (statefulContext, setState) {
          return SafeArea(
            child: SingleChildScrollView(
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
                    const SizedBox(height: 8),
                    Text(
                      l10n.energyTopUpDescriptionCompact,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    const _NextFreeAttemptCard(),
                    const SizedBox(height: 12),
                    const _EnergyCostsTable(),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.5),
                    ),
                    const SizedBox(height: 14),
                    if (processingPack != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          l10n.energyTopUpProcessing,
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                      ),
                    _PackActionButton(
                      title: _packTitle(l10n, EnergyPackId.yearUnlimited),
                      stars: _displayStarsByPack[EnergyPackId.yearUnlimited]!,
                      primary: true,
                      enabled: processingPack == null,
                      onPressed: processingPack != null
                          ? null
                          : () async {
                              setState(() =>
                                  processingPack = EnergyPackId.yearUnlimited);
                              await _purchaseEnergyPack(
                                context: context,
                                sheetContext: statefulContext,
                                ref: ref,
                                l10n: l10n,
                                packId: EnergyPackId.yearUnlimited,
                              );
                              if (statefulContext.mounted) {
                                setState(() => processingPack = null);
                              }
                            },
                    ),
                    for (final packId in [
                      EnergyPackId.small,
                      EnergyPackId.medium,
                      EnergyPackId.full,
                    ])
                      if (_shouldShowPack(energy, packId)) ...[
                        const SizedBox(height: 10),
                        _PackActionButton(
                          title: _packTitle(l10n, packId),
                          stars: _displayStarsByPack[packId]!,
                          enabled: processingPack == null,
                          onPressed: processingPack != null
                              ? null
                              : () async {
                                  if (!_shouldShowPack(
                                    ref.read(energyProvider),
                                    packId,
                                  )) {
                                    return;
                                  }
                                  setState(() => processingPack = packId);
                                  await _purchaseEnergyPack(
                                    context: context,
                                    sheetContext: statefulContext,
                                    ref: ref,
                                    l10n: l10n,
                                    packId: packId,
                                  );
                                  if (statefulContext.mounted) {
                                    setState(() => processingPack = null);
                                  }
                                },
                        ),
                      ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _EnergyCostsTable extends StatelessWidget {
  const _EnergyCostsTable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget row(String action, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(action, style: textTheme.bodySmall),
            ),
            Text(value, style: textTheme.bodySmall),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface.withOpacity(0.55),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.energyCostsTitle,
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          row(l10n.energyCostReading, '${EnergyAction.reading.cost.round()}%'),
          row(l10n.energyCostDeepDetails,
              '${EnergyAction.deepDetails.cost.round()}%'),
          row(l10n.energyCostNatalChart,
              '${EnergyAction.natalChart.cost.round()}%'),
        ],
      ),
    );
  }
}

class _PackActionButton extends StatelessWidget {
  const _PackActionButton({
    required this.title,
    required this.stars,
    required this.onPressed,
    this.primary = false,
    this.enabled = true,
  });

  final String title;
  final int stars;
  final VoidCallback? onPressed;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final starsText = '$stars ⭐';
    final content = Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (primary ? textTheme.titleMedium : textTheme.labelLarge)
                ?.copyWith(
              color: primary
                  ? colorScheme.onPrimary
                  : colorScheme.primary.withValues(alpha: 0.96),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          starsText,
          maxLines: 1,
          style: (primary ? textTheme.titleMedium : textTheme.labelLarge)
              ?.copyWith(
            color: primary
                ? colorScheme.onPrimary
                : colorScheme.primary.withValues(alpha: 0.96),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    if (primary) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          child: content,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.8)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: content,
      ),
    );
  }
}

class _NextFreeAttemptCard extends ConsumerWidget {
  const _NextFreeAttemptCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final energy = ref.watch(energyProvider);
    final missing =
        (EnergyAction.reading.cost - energy.clampedValue).clamp(0, 100);
    final seconds = energy.isUnlimited
        ? 0
        : (missing / EnergyController.recoveryPerSecond).ceil();
    final waitText = seconds <= 0
        ? l10n.energyNextFreeReady
        : l10n
            .energyNextFreeIn(_formatShortDuration(Duration(seconds: seconds)));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface.withOpacity(0.55),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              waitText,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatShortDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours}ч ${minutes}м';
  }
  if (minutes > 0) {
    return '${minutes}м ${seconds}с';
  }
  return '${seconds}с';
}

Future<void> _purchaseEnergyPack({
  required BuildContext context,
  required BuildContext sheetContext,
  required WidgetRef ref,
  required AppLocalizations l10n,
  required EnergyPackId packId,
}) async {
  if (!TelegramBridge.isAvailable) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.energyTopUpOnlyInTelegram)),
    );
    return;
  }

  if (packId != EnergyPackId.yearUnlimited &&
      !_shouldShowPack(ref.read(energyProvider), packId)) {
    return;
  }

  try {
    final topUpRepo = ref.read(energyTopUpRepositoryProvider);
    final invoice = await topUpRepo.createInvoice(packId);
    final status = await TelegramBridge.openInvoice(invoice.invoiceLink);
    try {
      await topUpRepo.confirmInvoiceResult(
        payload: invoice.payload,
        status: status,
      );
    } catch (_) {}

    if (!context.mounted) {
      return;
    }

    switch (status) {
      case 'paid':
        if (packId == EnergyPackId.yearUnlimited) {
          await ref.read(energyProvider.notifier).activateUnlimitedForYear();
        } else {
          await ref
              .read(energyProvider.notifier)
              .addEnergy(invoice.energyAmount.toDouble());
        }
        if (sheetContext.mounted) {
          Navigator.of(sheetContext).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              packId == EnergyPackId.yearUnlimited
                  ? l10n.energyUnlimitedActivated
                  : l10n.energyTopUpSuccess(invoice.energyAmount),
            ),
          ),
        );
        return;
      case 'cancelled':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpPaymentCancelled)),
        );
        return;
      case 'pending':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpPaymentPending)),
        );
        return;
      case 'failed':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpPaymentFailed)),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
        );
        return;
    }
  } on EnergyTopUpRepositoryException {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
    );
  }
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
