import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../data/models/reading_model.dart';
import '../../state/providers.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const routeName = '/history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(readingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reading history')),
      body: ValueListenableBuilder(
        valueListenable: repository.listenable(),
        builder: (context, box, _) {
          final readings = repository.getReadings();
          if (readings.isEmpty) {
            return const Center(child: Text('No saved readings yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final reading = readings[index];
              return _HistoryTile(reading: reading);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: readings.length,
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.reading});

  final ReadingModel reading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(reading.spreadName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(formatDateTime(reading.createdAt)),
            const SizedBox(height: 4),
            Text(
              reading.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailScreen(reading: reading),
            ),
          );
        },
      ),
    );
  }
}
