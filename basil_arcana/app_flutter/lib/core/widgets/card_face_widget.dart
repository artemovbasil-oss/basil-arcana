import 'package:flutter/material.dart';

class CardFaceWidget extends StatelessWidget {
  final String cardName;
  final List<String> keywords;

  const CardFaceWidget({
    super.key,
    required this.cardName,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.primary.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cardName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords
                .map(
                  (keyword) => Chip(
                    label: Text(keyword),
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: colorScheme.outlineVariant),
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
