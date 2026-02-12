import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/reading_model.dart';
import '../../state/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const routeName = '/history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(readingsRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildTopBar(
        context,
        title: Text(l10n.historyTitle),
        showBack: true,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: repository.listenable(),
          builder: (context, box, _) {
            final readings = repository.getReadings();
            return Column(
              children: [
                Expanded(
                  child: readings.isEmpty
                      ? Center(child: Text(l10n.historyEmpty))
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemBuilder: (context, index) {
                            final reading = readings[index];
                            return _HistoryTile(reading: reading);
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemCount: readings.length,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: AppPrimaryButton(
                    label: l10n.historyClearButton,
                    onPressed: readings.isEmpty
                        ? null
                        : () async {
                            await repository.clearReadings();
                          },
                  ),
                ),
              ],
            );
          },
        ),
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
        title: Text(
          reading.question,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final ref = ProviderScope.containerOf(context, listen: false);
          ref
              .read(readingFlowControllerProvider.notifier)
              .setQuestion(reading.question);
          Navigator.pop(context);
        },
      ),
    );
  }
}
