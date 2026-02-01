import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/spread_model.dart';
import '../../state/providers.dart';
import '../shuffle/shuffle_screen.dart';

class SpreadScreen extends ConsumerWidget {
  const SpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spreadsAsync = ref.watch(spreadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a spread')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: spreadsAsync.when(
          data: (spreads) => Column(
            children: spreads
                .map((spread) => _SpreadTile(spread: spread))
                .toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
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
    return Card(
      child: ListTile(
        title: Text(spread.name),
        subtitle: Text('${spread.positions.length} card(s)'),
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
