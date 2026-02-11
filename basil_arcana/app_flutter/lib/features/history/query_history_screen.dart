import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/repositories/query_history_repository.dart';
import '../../state/providers.dart';

class QueryHistoryScreen extends ConsumerStatefulWidget {
  const QueryHistoryScreen({super.key});

  static const routeName = '/query-history';

  @override
  ConsumerState<QueryHistoryScreen> createState() => _QueryHistoryScreenState();
}

class _QueryHistoryScreenState extends ConsumerState<QueryHistoryScreen> {
  late Future<List<QueryHistoryItem>> _future;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<QueryHistoryItem>> _load() {
    return ref.read(queryHistoryRepositoryProvider).fetchRecent(limit: 40);
  }

  Future<void> _clearHistory() async {
    if (_clearing) {
      return;
    }
    setState(() {
      _clearing = true;
    });
    try {
      await ref.read(queryHistoryRepositoryProvider).clearAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _load();
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _clearing = false;
      });
    }
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () {
                    ref
                        .read(readingFlowControllerProvider.notifier)
                        .setQuestion(item.question);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.question,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(context, item.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: FutureBuilder<List<QueryHistoryItem>>(
          future: _future,
          builder: (context, snapshot) {
            final canClear = !_clearing && (snapshot.data?.isNotEmpty ?? false);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: AppPrimaryButton(
                label: l10n.historyClearButton,
                onPressed: canClear ? _clearHistory : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
