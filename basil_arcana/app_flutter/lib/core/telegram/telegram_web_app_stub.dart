class TelegramWebApp {
  static bool get isAvailable => false;
  static bool get canSendData => false;
  static bool get isTelegramWebView => false;
  static String? get platform => null;
  static bool get isTelegramMobile => false;
  static String? get initData => null;
  static void showBackButton() {}
  static void hideBackButton() {}
  static void onBackButtonClicked(void Function() callback) {}
  static void expand() {}
  static void disableVerticalSwipes() {}
  static void close() {}
  static void sendData(String data) {}
}
