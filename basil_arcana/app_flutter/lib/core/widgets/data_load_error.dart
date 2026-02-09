import 'package:flutter/material.dart';

import '../config/diagnostics.dart';
import '../theme/app_text_styles.dart';
import 'app_buttons.dart';

class DataLoadRequestDebugInfo {
  const DataLoadRequestDebugInfo({
    required this.url,
    this.statusCode,
    this.contentType,
    this.contentLength,
    this.responseSnippetStart,
    this.responseSnippetEnd,
    this.responseLength,
    this.bytesLength,
    this.rootType,
  });

  final String url;
  final int? statusCode;
  final String? contentType;
  final String? contentLength;
  final String? responseSnippetStart;
  final String? responseSnippetEnd;
  final int? responseLength;
  final int? bytesLength;
  final String? rootType;
}

class DataLoadDebugInfo {
  const DataLoadDebugInfo({
    required this.assetsBaseUrl,
    required this.requests,
    this.failedStage,
    this.exceptionSummary,
  });

  final String assetsBaseUrl;
  final Map<String, DataLoadRequestDebugInfo> requests;
  final String? failedStage;
  final String? exceptionSummary;
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
            style: AppTextStyles.title(context),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            onPressed: onRetry,
            label: retryLabel,
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            AppGhostButton(
              onPressed: onSecondary,
              label: secondaryLabel!,
            ),
          ],
          if (kEnableDevDiagnostics && debugInfo != null) ...[
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
          Text('FAILED_STAGE', style: textTheme.labelMedium),
          SelectableText(info.failedStage ?? '—'),
          const SizedBox(height: 12),
          Text('Exception (sanitized)', style: textTheme.labelMedium),
          SelectableText(info.exceptionSummary ?? '—'),
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
          Text('Content-Type', style: textTheme.labelSmall),
          SelectableText(info.contentType ?? '—'),
          const SizedBox(height: 6),
          Text('Content-Length', style: textTheme.labelSmall),
          SelectableText(info.contentLength ?? '—'),
          const SizedBox(height: 6),
          Text('Response length', style: textTheme.labelSmall),
          SelectableText(
            info.responseLength != null ? '${info.responseLength} chars' : '—',
          ),
          const SizedBox(height: 6),
          Text('Bytes length', style: textTheme.labelSmall),
          SelectableText(
            info.bytesLength != null ? '${info.bytesLength} bytes' : '—',
          ),
          const SizedBox(height: 6),
          Text('Root type', style: textTheme.labelSmall),
          SelectableText(info.rootType ?? '—'),
          const SizedBox(height: 6),
          Text('Response snippet (start)', style: textTheme.labelSmall),
          SelectableText(
            info.responseSnippetStart?.trim().isNotEmpty == true
                ? info.responseSnippetStart!
                : '—',
          ),
          const SizedBox(height: 6),
          Text('Response snippet (end)', style: textTheme.labelSmall),
          SelectableText(
            info.responseSnippetEnd?.trim().isNotEmpty == true
                ? info.responseSnippetEnd!
                : '—',
          ),
        ],
      ),
    );
  }
}
