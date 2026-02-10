import 'package:flutter/material.dart';

import '../../core/telemetry/runtime_error_buffer.dart';

class RuntimeErrorLogScreen extends StatelessWidget {
  const RuntimeErrorLogScreen({super.key});

  static const routeName = '/debug/runtime-errors';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Runtime errors')),
      body: ValueListenableBuilder<List<RuntimeErrorEntry>>(
        valueListenable: RuntimeErrorBuffer.instance.listenable,
        builder: (context, entries, _) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('No runtime errors captured.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final stackLines = entry.stackTrace
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .take(12)
                  .join('\n');
              return SelectableText(
                '[${entry.timestamp.toIso8601String()}] ${entry.source}\n'
                '${entry.message}\n\n$stackLines',
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemCount: entries.length,
          );
        },
      ),
    );
  }
}
