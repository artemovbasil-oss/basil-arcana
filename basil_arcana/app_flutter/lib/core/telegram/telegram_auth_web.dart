import 'dart:async';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

class TelegramAuth {
  TelegramAuth._();

  static final TelegramAuth instance = TelegramAuth._();

  String? _cachedInitData;
  bool _readyCalled = false;
  bool _expandCalled = false;

  bool get isTelegram {
    return _hasWebApp() || _hasBridgeInitData();
  }

  Future<String> getInitData({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedInitData != null &&
        _cachedInitData!.trim().isNotEmpty) {
      return _cachedInitData!;
    }
    if (_hasWebApp()) {
      _callReadyOnce();
    }
    var value = _readInitData();
    if (value.trim().isNotEmpty) {
      _cachedInitData = value;
      return value;
    }
    if (!_hasWebApp() && !_hasBridgeInitData()) {
      return value;
    }
    const maxAttempts = 10;
    const delay = Duration(milliseconds: 120);
    var attempts = 0;
    while (value.trim().isEmpty && attempts < maxAttempts) {
      attempts += 1;
      await Future.delayed(delay);
      _callReadyOnce();
      value = _readInitData();
    }
    if (value.trim().isNotEmpty) {
      _cachedInitData = value;
    } else if (kDebugMode) {
      debugPrint('[TelegramAuth] initData empty after $attempts attempts');
    }
    return value;
  }

  bool _hasWebApp() {
    try {
      if (!js_util.hasProperty(js_util.globalThis, 'Telegram')) {
        return false;
      }
      final telegram = js_util.getProperty(js_util.globalThis, 'Telegram');
      if (telegram == null) {
        return false;
      }
      return js_util.hasProperty(telegram, 'WebApp');
    } catch (_) {
      return false;
    }
  }

  bool _hasBridgeInitData() {
    try {
      if (js_util.hasProperty(js_util.globalThis, '__tgInitData')) {
        final value = js_util.getProperty(js_util.globalThis, '__tgInitData');
        if (value is String && value.trim().isNotEmpty) {
          return true;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, '__tgInitDataGetter')) {
        final value = js_util.callMethod(
          js_util.globalThis,
          '__tgInitDataGetter',
          const [],
        );
        if (value is String && value.trim().isNotEmpty) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  void _callReadyOnce() {
    if (_readyCalled) {
      return;
    }
    _readyCalled = true;
    try {
      final telegram = js_util.getProperty(js_util.globalThis, 'Telegram');
      if (telegram == null || !js_util.hasProperty(telegram, 'WebApp')) {
        return;
      }
      final webApp = js_util.getProperty(telegram, 'WebApp');
      if (webApp != null && js_util.hasProperty(webApp, 'ready')) {
        js_util.callMethod(webApp, 'ready', const []);
      }
      if (!_expandCalled && webApp != null && js_util.hasProperty(webApp, 'expand')) {
        js_util.callMethod(webApp, 'expand', const []);
        _expandCalled = true;
      }
    } catch (_) {}
  }

  String _readInitData() {
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
        final value = js_util.callMethod(
          js_util.globalThis,
          'tgGetInitData',
          const [],
        );
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, 'Telegram')) {
        final telegram = js_util.getProperty(js_util.globalThis, 'Telegram');
        if (telegram != null && js_util.hasProperty(telegram, 'WebApp')) {
          final webApp = js_util.getProperty(telegram, 'WebApp');
          if (webApp != null && js_util.hasProperty(webApp, 'initData')) {
            final initData = js_util.getProperty(webApp, 'initData');
            if (initData is String && initData.trim().isNotEmpty) {
              return initData;
            }
          }
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
    } catch (_) {
      return '';
    }
    return '';
  }
}
