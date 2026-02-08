import 'package:flutter/material.dart';

PreferredSizeWidget buildTopBar(
  BuildContext context, {
  required Widget title,
  bool showBack = false,
  VoidCallback? onBack,
  List<Widget>? actions,
}) {
  final canPop = Navigator.canPop(context);
  final shouldShowBack = showBack && (canPop || onBack != null);
  return AppBar(
    title: title,
    actions: actions,
    automaticallyImplyLeading: shouldShowBack,
    leading: shouldShowBack
        ? BackButton(
            onPressed: () async {
              final didPop = await Navigator.maybePop(context);
              if (!didPop && onBack != null) {
                onBack();
              }
            },
          )
        : null,
  );
}
