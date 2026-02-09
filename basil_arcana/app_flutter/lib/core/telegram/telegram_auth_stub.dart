class TelegramAuth {
  TelegramAuth._();

  static final TelegramAuth instance = TelegramAuth._();

  bool get isTelegram => false;

  Future<String> getInitData({bool forceRefresh = false}) async {
    return '';
  }
}
