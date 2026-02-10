class TelegramEnv {
  TelegramEnv._();

  static final TelegramEnv instance = TelegramEnv._();

  bool get isTelegram => false;

  String get initData => '';

  Future<String> ensureInitData({
    int maxAttempts = 10,
    Duration delay = const Duration(milliseconds: 120),
  }) async {
    return initData;
  }
}
