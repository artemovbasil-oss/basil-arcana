import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../data/models/spread_model.dart';
import '../../state/providers.dart';
import '../shuffle/shuffle_screen.dart';

class SpreadScreen extends ConsumerWidget {
  const SpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spreadsAsync = ref.watch(spreadsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.spreadTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: spreadsAsync.when(
          data: (spreads) => Column(
            children: spreads
                .map((spread) => _SpreadTile(spread: spread))
                .toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text(l10n.spreadLoadError(error.toString()))),
        ),
      ),
    );
  }
}

class _SpreadTile extends ConsumerWidget {
  const _SpreadTile({required this.spread});

  final SpreadModel spread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        title: Text(spread.name),
        subtitle: Text(
          l10n.spreadCardCount(spread.positions.length),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(readingFlowControllerProvider.notifier).selectSpread(spread);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShuffleScreen()),
          );
        },
      ),
    );
  }
}
