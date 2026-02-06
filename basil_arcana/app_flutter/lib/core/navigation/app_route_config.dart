import 'package:flutter/material.dart';

class AppRouteConfig {
  const AppRouteConfig({this.showBackButton = false});

  final bool showBackButton;
}

RouteSettings appRouteSettings({
  String? name,
  bool showBackButton = false,
}) {
  return RouteSettings(
    name: name,
    arguments: AppRouteConfig(showBackButton: showBackButton),
  );
}

bool routeShowsBackButton(Route<dynamic>? route) {
  final args = route?.settings.arguments;
  if (args is AppRouteConfig) {
    return args.showBackButton;
  }
  return false;
}
