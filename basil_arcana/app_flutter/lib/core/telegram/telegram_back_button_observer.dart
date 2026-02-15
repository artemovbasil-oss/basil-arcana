import 'package:flutter/material.dart';

import '../navigation/app_route_config.dart';
import 'telegram_web_app.dart';

class TelegramBackButtonObserver extends NavigatorObserver {
  Route<dynamic>? _currentRoute;
  bool _backListenerBound = false;

  TelegramBackButtonObserver();

  void _handleBackButton() {
    final nav = navigator;
    if (nav == null) {
      return;
    }
    nav.maybePop();
  }

  void _ensureBackListenerBound() {
    if (_backListenerBound || !TelegramWebApp.isTelegramWebView) {
      return;
    }
    TelegramWebApp.onBackButtonClicked(_handleBackButton);
    _backListenerBound = true;
  }

  void _syncBackButton() {
    if (!TelegramWebApp.isTelegramWebView) {
      return;
    }
    _ensureBackListenerBound();
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
