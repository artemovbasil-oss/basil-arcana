import 'dart:js_util' as js_util;

String readWebBuildVersion() {
  final version = js_util.getProperty(js_util.globalThis, '__buildVersion');
  if (version is String && version.trim().isNotEmpty) {
    return version.trim();
  }

  return 'dev';
}
