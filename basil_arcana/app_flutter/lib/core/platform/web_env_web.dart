import 'dart:html' as html;
import 'dart:js_util' as js_util;

class WebEnv {
  const WebEnv();

  // Read the Telegram flag injected by web/index.html.
  bool get isTelegramWeb =>
      js_util.getProperty(html.window, '__IS_TELEGRAM__') == true;
}

const webEnv = WebEnv();

bool isTelegramWeb() => webEnv.isTelegramWeb;

