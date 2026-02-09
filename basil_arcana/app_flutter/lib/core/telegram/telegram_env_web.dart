import 'dart:async';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

import 'telegram_web_app_web.dart';

class TelegramEnv {
  TelegramEnv._();

  static final TelegramEnv instance = TelegramEnv._();

  String? _cachedInitData;
  bool _retryInProgress = false;
  bool _loggedInitData = false;
  static const int _maxInitDataRetries = 4;
  static const Duration _retryDelay = Duration(milliseconds: 150);

  bool get isTelegram {
    return _isTelegramEnvironment();
  }

  String get initData {
    if (_cachedInitData != null && _cachedInitData!.trim().isNotEmpty) {
      return _cachedInitData!;
    }
    final initData = _readWebAppInitData();
    if (initData.trim().isNotEmpty) {
      _cachedInitData = initData;
      _logInitData(initData);
    } else {
      _scheduleInitDataRetry();
    }
    return initData;
  }

  bool _isTelegramEnvironment() {
    try {
      if (js_util.hasProperty(js_util.globalThis, '__isTelegram')) {
        final flag = js_util.getProperty(js_util.globalThis, '__isTelegram');
        if (flag == true) {
          return true;
        }
      }
    } catch (_) {}
    if (TelegramWebApp.isTelegramWebView) {
      return true;
    }
    try {
      if (js_util.hasProperty(js_util.globalThis, 'Telegram')) {
        final telegram = js_util.getProperty(js_util.globalThis, 'Telegram');
        return telegram != null && js_util.hasProperty(telegram, 'WebApp');
      }
    } catch (_) {}
    return false;
  }

  void _scheduleInitDataRetry() {
    if (_retryInProgress || !_isTelegramEnvironment()) {
      return;
    }
    _retryInProgress = true;
    var attempts = 0;
    void attempt() {
      attempts += 1;
      final initData = _readWebAppInitData();
      if (initData.trim().isNotEmpty) {
        _cachedInitData = initData;
        _logInitData(initData);
        _retryInProgress = false;
        return;
      }
      if (attempts >= _maxInitDataRetries) {
        _retryInProgress = false;
        return;
      }
      Future.delayed(_retryDelay, attempt);
    }

    Future.delayed(_retryDelay, attempt);
  }

  String _readWebAppInitData() {
    try {
      if (js_util.hasProperty(js_util.globalThis, 'getTelegramInitData')) {
        final value = js_util.callMethod(
          js_util.globalThis,
          'getTelegramInitData',
          const [],
        );
        if (value is String) {
          return value;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, 'tgGetInitData')) {
        final value =
            js_util.callMethod(js_util.globalThis, 'tgGetInitData', const []);
        if (value is String) {
          return value;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, '__tg_initData')) {
        final cached =
            js_util.getProperty(js_util.globalThis, '__tg_initData');
        if (cached is String && cached.trim().isNotEmpty) {
          return cached;
        }
      }
      if (js_util.hasProperty(js_util.globalThis, '__tgInitData')) {
        final value =
            js_util.callMethod(js_util.globalThis, '__tgInitData', const []);
        if (value is String) {
          return value;
        }
      }
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
      if (js_util.hasProperty(webApp, 'initDataUnsafe')) {
        final unsafe = js_util.getProperty(webApp, 'initDataUnsafe');
        if (unsafe != null) {
          final hasUser = js_util.hasProperty(unsafe, 'user');
          final hasHash = js_util.hasProperty(unsafe, 'hash');
          final hasAuthDate = js_util.hasProperty(unsafe, 'auth_date');
          if ((hasUser || hasHash || hasAuthDate) && kDebugMode) {
            debugPrint('[TelegramEnv] initDataUnsafe present');
          }
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  void _logInitData(String initData) {
    if (_loggedInitData || !kDebugMode) {
      return;
    }
    _loggedInitData = true;
    final trimmed = initData.trim();
    if (trimmed.isEmpty) {
      return;
    }
    bool hasUser = false;
    bool hasHash = false;
    try {
      final params = Uri.splitQueryString(trimmed);
      hasUser = params.containsKey('user');
      hasHash = params.containsKey('hash');
    } catch (_) {
      hasUser = trimmed.contains('user=');
      hasHash = trimmed.contains('hash=');
    }
    debugPrint(
      '[TelegramEnv] initData length=${trimmed.length} '
      'has_user=$hasUser has_hash=$hasHash',
    );
  }
}
