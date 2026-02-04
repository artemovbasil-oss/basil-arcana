class WebEnv {
  const WebEnv();

  // Non-web builds should always treat this as false.
  bool get isTelegramWeb => false;
}

const webEnv = WebEnv();

bool isTelegramWeb() => webEnv.isTelegramWeb;

