import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../telegram/telegram_env.dart';

class TelegramApiClient extends http.BaseClient {
  TelegramApiClient(this._inner, {bool? enableDebugLogs})
      : _enableDebugLogs = enableDebugLogs ?? kDebugMode;

  final http.Client _inner;
  final bool _enableDebugLogs;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final initData = TelegramEnv.instance.initData;
    final isTelegram = TelegramEnv.instance.isTelegram;
    if (isTelegram && initData.trim().isNotEmpty) {
      final lowerKeys = request.headers.keys
          .map((key) => key.toLowerCase())
          .toList();
      final hasTelegramHeader = lowerKeys.contains('x-telegram-initdata') ||
          lowerKeys.contains('x-telegram-init-data') ||
          lowerKeys.contains('x-tg-init-data');
      if (!hasTelegramHeader) {
        request.headers['X-Telegram-InitData'] = initData;
        request.headers['X-Telegram-Init-Data'] = initData;
      }
    } else if (_enableDebugLogs && isTelegram) {
      debugPrint('[TelegramApiClient] Missing initData in Telegram WebApp.');
    }

    if (_enableDebugLogs) {
      debugPrint(
        '[TelegramApiClient] ${request.method} ${request.url} '
        'telegram=${isTelegram ? 'yes' : 'no'}',
      );
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
