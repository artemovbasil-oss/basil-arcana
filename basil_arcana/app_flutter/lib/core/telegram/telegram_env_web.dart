import 'dart:js_util' as js_util;

class TelegramEnv {
  TelegramEnv._();

  static final TelegramEnv instance = TelegramEnv._();

  String? _cachedInitData;

  bool get isTelegram {
    try {
      final value = js_util.getProperty(js_util.globalThis, '__isTelegram');
      if (value is bool) {
        return value;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  String get initData {
    if (_cachedInitData != null && _cachedInitData!.trim().isNotEmpty) {
      return _cachedInitData!;
    }
    final initData = _readInitData();
    if (initData.trim().isNotEmpty) {
      _cachedInitData = initData;
    }
    return initData;
  }

  String _readInitData() {
    try {
      if (!js_util.hasProperty(js_util.globalThis, '__tgInitData')) {
        return '';
      }
      final initDataGetter =
          js_util.getProperty(js_util.globalThis, '__tgInitData');
      if (initDataGetter is Function) {
        final value = js_util.callMethod(
          js_util.globalThis,
          '__tgInitData',
          const [],
        );
        if (value is String) {
          return value;
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}
