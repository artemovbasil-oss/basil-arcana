import 'package:flutter/material.dart';

class AppTextStyles {
  static TextStyle title(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge ??
        const TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  }

  static TextStyle subtitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  }

  static TextStyle body(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14, height: 1.4);
  }

  static TextStyle caption(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12, height: 1.3);
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall ??
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  }
}
