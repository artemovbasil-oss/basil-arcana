import 'dart:js_util' as js_util;

class TelegramWebApp {
  static Object? get _telegram {
    try {
      return js_util.getProperty(
        js_util.globalThis,
        'Telegram',
      );
    } catch (_) {
      return null;
    }
  }

  static Object? get _webApp {
    try {
      final telegram = _telegram;
      if (telegram == null) {
        return null;
      }
      if (!js_util.hasProperty(telegram, 'WebApp')) {
        return null;
      }
      return js_util.getProperty(telegram, 'WebApp');
    } catch (_) {
      return null;
    }
  }

  static bool get isAvailable => _webApp != null;

  static bool get canSendData {
    final webApp = _webApp;
    if (webApp == null) {
      return false;
    }
    return js_util.hasProperty(webApp, 'sendData');
  }

  static bool get isTelegramWebView {
    if (isAvailable) {
      return true;
    }
    try {
      final navigator = js_util.getProperty(js_util.globalThis, 'navigator');
      if (navigator == null) {
        return false;
      }
      final userAgent = js_util.getProperty(navigator, 'userAgent');
      if (userAgent is! String) {
        return false;
      }
      return userAgent.toLowerCase().contains('telegram');
    } catch (_) {
      return false;
    }
  }

  static String? get platform {
    try {
      final webApp = _webApp;
      if (webApp == null) {
        return null;
      }
      final platform = js_util.getProperty(webApp, 'platform');
      if (platform is String && platform.trim().isNotEmpty) {
        return platform;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool get isTelegramMobile {
    final currentPlatform = platform;
    return currentPlatform == 'ios' || currentPlatform == 'android';
  }

  static String? get initData {
    try {
      if (js_util.hasProperty(js_util.globalThis, 'getTelegramInitData')) {
        final value = js_util.callMethod(
          js_util.globalThis,
          'getTelegramInitData',
          const [],
        );
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, 'tgGetInitData')) {
        final value =
            js_util.callMethod(js_util.globalThis, 'tgGetInitData', const []);
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, '__tgInitData')) {
        final cached = js_util.getProperty(js_util.globalThis, '__tgInitData');
        if (cached is String && cached.trim().isNotEmpty) {
          return cached;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, '__tgInitDataGetter')) {
        final value = js_util.callMethod(
          js_util.globalThis,
          '__tgInitDataGetter',
          const [],
        );
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
      final webApp = _webApp;
      if (webApp == null) {
        return null;
      }
      final initData = js_util.getProperty(webApp, 'initData');
      if (initData is String && initData.trim().isNotEmpty) {
        return initData;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Object? get _backButton {
    try {
      final webApp = _webApp;
      if (webApp == null) {
        return null;
      }
      if (!js_util.hasProperty(webApp, 'BackButton')) {
        return null;
      }
      return js_util.getProperty(webApp, 'BackButton');
    } catch (_) {
      return null;
    }
  }

  static void showBackButton() {
    final backButton = _backButton;
    if (backButton == null) {
      return;
    }
    if (js_util.hasProperty(backButton, 'show')) {
      try {
        js_util.callMethod(backButton, 'show', []);
      } catch (_) {}
    }
  }

  static void hideBackButton() {
    final backButton = _backButton;
    if (backButton == null) {
      return;
    }
    if (js_util.hasProperty(backButton, 'hide')) {
      try {
        js_util.callMethod(backButton, 'hide', []);
      } catch (_) {}
    }
  }

  static void onBackButtonClicked(void Function() callback) {
    final backButton = _backButton;
    if (backButton == null) {
      return;
    }
    if (js_util.hasProperty(backButton, 'onClick')) {
      try {
        js_util.callMethod(backButton, 'onClick', [callback]);
      } catch (_) {}
    }
  }

  static void expand() {
    final webApp = _webApp;
    if (webApp == null) {
      return;
    }
    if (js_util.hasProperty(webApp, 'expand')) {
      try {
        js_util.callMethod(webApp, 'expand', []);
      } catch (_) {}
    }
  }

  static void ready() {
    final webApp = _webApp;
    if (webApp == null) {
      return;
    }
    if (js_util.hasProperty(webApp, 'ready')) {
      try {
        js_util.callMethod(webApp, 'ready', []);
      } catch (_) {}
    }
  }

  static void disableVerticalSwipes() {
    final webApp = _webApp;
    if (webApp == null) {
      return;
    }
    if (js_util.hasProperty(webApp, 'disableVerticalSwipes')) {
      try {
        js_util.callMethod(webApp, 'disableVerticalSwipes', []);
      } catch (_) {}
    }
  }

  static void close() {
    final webApp = _webApp;
    if (webApp == null) {
      return;
    }
    if (js_util.hasProperty(webApp, 'close')) {
      try {
        js_util.callMethod(webApp, 'close', []);
      } catch (_) {}
    }
  }

  static void sendData(String data) {
    final webApp = _webApp;
    if (webApp == null) {
      return;
    }
    if (js_util.hasProperty(webApp, 'sendData')) {
      try {
        js_util.callMethod(webApp, 'sendData', [data]);
      } catch (_) {}
    }
  }
}
