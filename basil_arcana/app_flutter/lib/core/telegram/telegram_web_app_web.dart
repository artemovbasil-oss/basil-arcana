import 'dart:js_util' as js_util;
class TelegramWebApp {
  static Object? get _telegram => js_util.getProperty(
        js_util.globalThis,
        'Telegram',
      );

  static Object? get _webApp {
    final telegram = _telegram;
    if (telegram == null) {
      return null;
    }
    if (!js_util.hasProperty(telegram, 'WebApp')) {
      return null;
    }
    return js_util.getProperty(telegram, 'WebApp');
  }

  static bool get isAvailable => _webApp != null;

  static bool get isTelegramWebView {
    if (isAvailable) {
      return true;
    }
    final navigator = js_util.getProperty(js_util.globalThis, 'navigator');
    if (navigator == null) {
      return false;
    }
    final userAgent = js_util.getProperty(navigator, 'userAgent');
    if (userAgent is! String) {
      return false;
    }
    return userAgent.toLowerCase().contains('telegram');
  }

  static String? get platform {
    final webApp = _webApp;
    if (webApp == null) {
      return null;
    }
    final platform = js_util.getProperty(webApp, 'platform');
    if (platform is String && platform.trim().isNotEmpty) {
      return platform;
    }
    return null;
  }

  static bool get isTelegramMobile {
    final currentPlatform = platform;
    return currentPlatform == 'ios' || currentPlatform == 'android';
  }

  static String? get initData {
    final webApp = _webApp;
    if (webApp == null) {
      return null;
    }
    final initData = js_util.getProperty(webApp, 'initData');
    if (initData is String && initData.trim().isNotEmpty) {
      return initData;
    }
    return null;
  }

  static Object? get _backButton {
    final webApp = _webApp;
    if (webApp == null) {
      return null;
    }
    if (!js_util.hasProperty(webApp, 'BackButton')) {
      return null;
    }
    return js_util.getProperty(webApp, 'BackButton');
  }

  static void showBackButton() {
    final backButton = _backButton;
    if (backButton == null) {
      return;
    }
    if (js_util.hasProperty(backButton, 'show')) {
      js_util.callMethod(backButton, 'show', []);
    }
  }

  static void hideBackButton() {
    final backButton = _backButton;
    if (backButton == null) {
      return;
    }
    if (js_util.hasProperty(backButton, 'hide')) {
      js_util.callMethod(backButton, 'hide', []);
    }
  }

  static void onBackButtonClicked(void Function() callback) {
    final backButton = _backButton;
    if (backButton == null) {
      return;
    }
    if (js_util.hasProperty(backButton, 'onClick')) {
      js_util.callMethod(backButton, 'onClick', [callback]);
    }
  }
}
