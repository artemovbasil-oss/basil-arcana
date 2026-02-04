import 'dart:html' as html;
import 'dart:js_util' as js_util;

class TelegramWeb {
  const TelegramWeb();

  bool get isTelegram => js_util.hasProperty(html.window, 'Telegram') &&
      js_util.hasProperty(_telegram, 'WebApp');

  String? get colorScheme =>
      js_util.getProperty(_webApp, 'colorScheme') as String?;

  Object? get _telegram => js_util.getProperty(html.window, 'Telegram');

  Object? get _webApp => js_util.getProperty(_telegram, 'WebApp');
}

const telegramWeb = TelegramWeb();
