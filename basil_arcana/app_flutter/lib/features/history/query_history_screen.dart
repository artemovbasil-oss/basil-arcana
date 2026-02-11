import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/repositories/query_history_repository.dart';
import '../../state/providers.dart';
import '../spread/spread_screen.dart';

class QueryHistoryScreen extends ConsumerStatefulWidget {
  const QueryHistoryScreen({super.key});

  static const routeName = '/query-history';

  @override
  ConsumerState<QueryHistoryScreen> createState() => _QueryHistoryScreenState();
}

class _QueryHistoryScreenState extends ConsumerState<QueryHistoryScreen> {
  late Future<List<QueryHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<QueryHistoryItem>> _load() {
    return ref.read(queryHistoryRepositoryProvider).fetchRecent(limit: 40);
  }

  String _formatDate(BuildContext context, DateTime date) {
    final code = Localizations.localeOf(context).languageCode;
    final locale = switch (code) {
      'ru' => 'ru_RU',
      'kk' => 'kk_KZ',
      _ => 'en_US',
    };
    return DateFormat('dd.MM.yyyy HH:mm', locale).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: buildTopBar(
        context,
        title: Text(l10n.queryHistoryTitle),
        showBack: true,
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<QueryHistoryItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.queryHistoryLoadError,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _future = _load();
                          });
                        },
                        child: Text(l10n.queryHistoryRetry),
                      ),
                    ],
                  ),
                ),
              );
            }
            final items = snapshot.data ?? const <QueryHistoryItem>[];
            if (items.isEmpty) {
              return Center(
                child: Text(
                  l10n.queryHistoryEmpty,
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    ref
                        .read(readingFlowControllerProvider.notifier)
                        .setQuestion(item.question);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: appRouteSettings(showBackButton: false),
                        builder: (_) => const SpreadScreen(),
                      ),
                    );
                  },
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.surfaceVariant.withOpacity(0.24),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.question,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(context, item.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
