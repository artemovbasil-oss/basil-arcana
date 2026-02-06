import 'package:flutter/material.dart';

import '../navigation/app_route_config.dart';
import 'telegram_web_app.dart';

class TelegramBackButtonObserver extends NavigatorObserver {
  Route<dynamic>? _currentRoute;

  TelegramBackButtonObserver() {
    if (TelegramWebApp.isTelegramWebView && TelegramWebApp.isTelegramMobile) {
      TelegramWebApp.onBackButtonClicked(_handleBackButton);
    }
  }

  void _handleBackButton() {
    navigator?.maybePop();
  }

  void _syncBackButton() {
    if (!TelegramWebApp.isTelegramWebView || !TelegramWebApp.isTelegramMobile) {
      return;
    }
    final canPop = navigator?.canPop() ?? false;
    final allowBack = routeShowsBackButton(_currentRoute);
    if (canPop && allowBack) {
      TelegramWebApp.showBackButton();
    } else {
      TelegramWebApp.hideBackButton();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _currentRoute = route;
    _syncBackButton();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _currentRoute = previousRoute;
    _syncBackButton();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_currentRoute == route) {
      _currentRoute = previousRoute;
    }
    _syncBackButton();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _currentRoute = newRoute;
    _syncBackButton();
  }
}
