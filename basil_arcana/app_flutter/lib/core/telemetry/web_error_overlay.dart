import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_error_reporter.dart';

class WebErrorOverlay extends StatelessWidget {
  const WebErrorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<String?>(
      valueListenable: WebErrorReporter.instance.listenable,
      builder: (context, message, _) {
        if (message == null || message.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      onPressed: WebErrorReporter.instance.clear,
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
