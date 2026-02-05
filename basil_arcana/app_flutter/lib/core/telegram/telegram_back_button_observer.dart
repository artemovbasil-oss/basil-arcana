import 'package:flutter/material.dart';

import 'telegram_web_app.dart';

class TelegramBackButtonObserver extends NavigatorObserver {
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
    if (navigator?.canPop() ?? false) {
      TelegramWebApp.showBackButton();
    } else {
      TelegramWebApp.hideBackButton();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _syncBackButton();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _syncBackButton();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _syncBackButton();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _syncBackButton();
  }
}
