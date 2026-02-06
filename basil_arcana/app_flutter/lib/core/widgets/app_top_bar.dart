import 'package:flutter/material.dart';

PreferredSizeWidget buildTopBar(
  BuildContext context, {
  required Widget title,
  bool showBack = false,
  List<Widget>? actions,
}) {
  final canPop = Navigator.canPop(context);
  final shouldShowBack = showBack && canPop;
  return AppBar(
    title: title,
    actions: actions,
    automaticallyImplyLeading: shouldShowBack,
    leading: shouldShowBack ? const BackButton() : null,
  );
}
