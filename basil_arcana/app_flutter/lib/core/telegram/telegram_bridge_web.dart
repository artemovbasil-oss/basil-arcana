import 'dart:js_util' as js_util;

class TelegramBridge {
  static bool get isAvailable {
    try {
      final global = js_util.globalThis;
      if (!js_util.hasProperty(global, 'tgIsAvailable')) {
        return false;
      }
      final result = js_util.callMethod(global, 'tgIsAvailable', []);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static bool sendData(String data) {
    try {
      final global = js_util.globalThis;
      if (!js_util.hasProperty(global, 'tgSendData')) {
        return false;
      }
      final result = js_util.callMethod(global, 'tgSendData', [data]);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static bool close() {
    try {
      final global = js_util.globalThis;
      if (!js_util.hasProperty(global, 'tgClose')) {
        return false;
      }
      final result = js_util.callMethod(global, 'tgClose', []);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static bool openTelegramLink(String url) {
    try {
      final global = js_util.globalThis;
      if (!js_util.hasProperty(global, 'tgOpenTelegramLink')) {
        return false;
      }
      final result = js_util.callMethod(global, 'tgOpenTelegramLink', [url]);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> openInvoice(String url) async {
    try {
      final global = js_util.globalThis;
      if (!js_util.hasProperty(global, 'tgOpenInvoice')) {
        return 'unsupported';
      }
      final result = js_util.callMethod(global, 'tgOpenInvoice', [url]);
      if (result is String) {
        return result;
      }
      if (result != null && js_util.hasProperty(result, 'then')) {
        final awaited = await js_util.promiseToFuture<Object?>(result);
        if (awaited is String && awaited.trim().isNotEmpty) {
          return awaited;
        }
      }
      return 'unknown';
    } catch (_) {
      return 'failed';
    }
  }
}
