import 'dart:js_util' as js_util;

class TelegramEnv {
  TelegramEnv._();

  static final TelegramEnv instance = TelegramEnv._();

  String? _cachedInitData;

  bool get isTelegram {
    return _readWebAppInitData().trim().isNotEmpty;
  }

  String get initData {
    if (_cachedInitData != null && _cachedInitData!.trim().isNotEmpty) {
      return _cachedInitData!;
    }
    final initData = _readWebAppInitData();
    if (initData.trim().isNotEmpty) {
      _cachedInitData = initData;
    }
    return initData;
  }

  String _readWebAppInitData() {
    try {
      if (!js_util.hasProperty(js_util.globalThis, 'Telegram')) {
        return '';
      }
      final telegram = js_util.getProperty(js_util.globalThis, 'Telegram');
      if (telegram == null || !js_util.hasProperty(telegram, 'WebApp')) {
        return '';
      }
      final webApp = js_util.getProperty(telegram, 'WebApp');
      if (webApp == null || !js_util.hasProperty(webApp, 'initData')) {
        return '';
      }
      final initData = js_util.getProperty(webApp, 'initData');
      if (initData is String) {
        return initData;
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}
