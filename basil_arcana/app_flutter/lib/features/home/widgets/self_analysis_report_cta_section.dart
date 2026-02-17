import 'package:flutter/material.dart';

import '../../../core/widgets/app_buttons.dart';

class SelfAnalysisReportCtaSection extends StatelessWidget {
  const SelfAnalysisReportCtaSection({
    super.key,
    required this.title,
    required this.body,
    required this.paidLabel,
    required this.freeLabel,
    required this.helper,
    required this.isFree,
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String paidLabel;
  final String freeLabel;
  final String helper;
  final bool isFree;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasHelper = helper.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.36),
        ),
        color: colorScheme.surfaceVariant.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 10),
          AppPrimaryButton(
            label: isLoading ? '...' : (isFree ? freeLabel : paidLabel),
            onPressed: (isEnabled && !isLoading) ? onPressed : null,
          ),
          if (isLoading && hasHelper) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  helper,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.74),
                      ),
                ),
              ],
            ),
          ] else if (hasHelper) ...[
            const SizedBox(height: 8),
            Text(
              helper,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.74),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
