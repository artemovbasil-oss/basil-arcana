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
}
