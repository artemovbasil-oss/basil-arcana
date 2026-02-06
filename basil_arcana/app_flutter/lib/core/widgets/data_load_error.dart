import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DataLoadDebugInfo {
  const DataLoadDebugInfo({
    required this.assetsBaseUrl,
    required this.attemptedUrls,
    required this.lastError,
  });

  final String assetsBaseUrl;
  final Map<String, String> attemptedUrls;
  final String? lastError;
}

class DataLoadError extends StatelessWidget {
  const DataLoadError({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.debugInfo,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final DataLoadDebugInfo? debugInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ),
          ],
          if (kDebugMode && debugInfo != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  _showDebugPanel(context, debugInfo!);
                },
                child: const Text('Debug errors'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDebugPanel(BuildContext context, DataLoadDebugInfo info) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('CDN debug info', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('ASSETS_BASE_URL', style: textTheme.labelLarge),
              SelectableText(info.assetsBaseUrl),
              const SizedBox(height: 12),
              Text('Last attempted URLs', style: textTheme.labelLarge),
              const SizedBox(height: 4),
              ...info.attemptedUrls.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: textTheme.labelMedium),
                      SelectableText(entry.value),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Last error', style: textTheme.labelLarge),
              SelectableText(info.lastError ?? '—'),
            ],
          ),
        );
      },
    );
  }
}
