import 'package:flutter/material.dart';

class DataLoadRequestDebugInfo {
  const DataLoadRequestDebugInfo({
    required this.url,
    this.statusCode,
    this.responseSnippet,
  });

  final String url;
  final int? statusCode;
  final String? responseSnippet;
}

class DataLoadDebugInfo {
  const DataLoadDebugInfo({
    required this.assetsBaseUrl,
    required this.requests,
    required this.lastError,
  });

  final String assetsBaseUrl;
  final Map<String, DataLoadRequestDebugInfo> requests;
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
          if (debugInfo != null) ...[
            const SizedBox(height: 16),
            _DebugInfoPanel(info: debugInfo!),
          ],
        ],
      ),
    );
  }
}

class _DebugInfoPanel extends StatelessWidget {
  const _DebugInfoPanel({required this.info});

  final DataLoadDebugInfo info;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diagnostics', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Text('ASSETS_BASE_URL', style: textTheme.labelMedium),
          SelectableText(info.assetsBaseUrl),
          const SizedBox(height: 12),
          ...info.requests.entries.map(
            (entry) => _DebugRequestSection(
              label: entry.key,
              info: entry.value,
            ),
          ),
          const SizedBox(height: 12),
          Text('Exception', style: textTheme.labelMedium),
          SelectableText(info.lastError ?? '—'),
        ],
      ),
    );
  }
}

class _DebugRequestSection extends StatelessWidget {
  const _DebugRequestSection({
    required this.label,
    required this.info,
  });

  final String label;
  final DataLoadRequestDebugInfo info;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          SelectableText(info.url),
          const SizedBox(height: 6),
          Text('HTTP status', style: textTheme.labelSmall),
          SelectableText(info.statusCode?.toString() ?? '—'),
          const SizedBox(height: 6),
          Text('Response snippet', style: textTheme.labelSmall),
          SelectableText(info.responseSnippet?.trim().isNotEmpty == true
              ? info.responseSnippet!
              : '—'),
        ],
      ),
    );
  }
}
