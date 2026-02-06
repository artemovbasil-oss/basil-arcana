import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../state/providers.dart';

class CdnHealthScreen extends ConsumerStatefulWidget {
  const CdnHealthScreen({super.key});

  @override
  ConsumerState<CdnHealthScreen> createState() => _CdnHealthScreenState();
}

class _CdnHealthScreenState extends ConsumerState<CdnHealthScreen> {
  String _status = '';
  bool _isLoading = false;

  Future<void> _runTest() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final repo = ref.read(cardsRepositoryProvider);
    final spreadsRepo = ref.read(dataRepositoryProvider);
    final locale = ref.read(localeProvider);
    final deckId = ref.read(deckProvider);
    try {
      await repo.fetchCards(locale: locale, deckId: deckId);
      await spreadsRepo.fetchSpreads(locale: locale);
      setState(() {
        _status = 'success';
      });
    } catch (_) {
      setState(() {
        _status = 'failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime? time) {
    if (time == null) {
      return '—';
    }
    return time.toLocal().toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.watch(cardsRepositoryProvider);
    final spreadsRepo = ref.watch(dataRepositoryProvider);
    final locale = ref.watch(localeProvider);
    final cardsFile = repo.cardsFileNameForLocale(locale);
    final spreadsFile = spreadsRepo.spreadsFileNameForLocale(locale);
    final cardsKey = repo.cardsCacheKey(locale);
    final spreadsKey = spreadsRepo.spreadsCacheKey(locale);
    final videoKey = spreadsRepo.videoIndexCacheKey;
    final lastFetch = {
      ...repo.lastFetchTimes,
      ...spreadsRepo.lastFetchTimes,
    };
    final lastCache = {
      ...repo.lastCacheTimes,
      ...spreadsRepo.lastCacheTimes,
    };

    final statusText = switch (_status) {
      'success' => l10n.cdnHealthStatusSuccess,
      'failed' => l10n.cdnHealthStatusFailed,
      _ => l10n.cdnHealthStatusIdle,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cdnHealthTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _InfoTile(
            label: l10n.cdnHealthAssetsBaseLabel,
            value: AssetsConfig.assetsBaseUrl,
          ),
          _InfoTile(
            label: l10n.cdnHealthLocaleLabel,
            value: locale.languageCode,
          ),
          _InfoTile(
            label: l10n.cdnHealthCardsFileLabel,
            value: cardsFile,
          ),
          _InfoTile(
            label: l10n.cdnHealthSpreadsFileLabel,
            value: spreadsFile,
          ),
          _InfoTile(
            label: l10n.cdnHealthVideoIndexLabel,
            value: 'video_index.json',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            label: '${l10n.cdnHealthLastFetchLabel} ($cardsFile)',
            value: _formatTimestamp(lastFetch[cardsKey]),
          ),
          _InfoTile(
            label: '${l10n.cdnHealthLastFetchLabel} ($spreadsFile)',
            value: _formatTimestamp(lastFetch[spreadsKey]),
          ),
          _InfoTile(
            label: '${l10n.cdnHealthLastFetchLabel} (video_index.json)',
            value: _formatTimestamp(lastFetch[videoKey]),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            label: '${l10n.cdnHealthLastCacheLabel} ($cardsFile)',
            value: _formatTimestamp(lastCache[cardsKey]),
          ),
          _InfoTile(
            label: '${l10n.cdnHealthLastCacheLabel} ($spreadsFile)',
            value: _formatTimestamp(lastCache[spreadsKey]),
          ),
          _InfoTile(
            label: '${l10n.cdnHealthLastCacheLabel} (video_index.json)',
            value: _formatTimestamp(lastCache[videoKey]),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            onPressed: _isLoading ? null : _runTest,
            label: l10n.cdnHealthTestFetch,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              statusText,
              style: AppTextStyles.body(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
