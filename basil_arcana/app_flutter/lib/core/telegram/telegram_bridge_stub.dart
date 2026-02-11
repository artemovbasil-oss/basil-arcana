class TelegramBridge {
  static bool get isAvailable => false;
  static bool sendData(String data) => false;
  static bool close() => false;
  static bool openTelegramLink(String url) => false;
  static Future<String> openInvoice(String url) async => 'unsupported';
}
