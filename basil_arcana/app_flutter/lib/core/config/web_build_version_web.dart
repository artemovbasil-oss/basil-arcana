import 'dart:js_util' as js_util;

String readWebBuildVersion() {
  try {
    final version = js_util.getProperty(js_util.globalThis, '__buildVersion');
    if (version is String && version.trim().isNotEmpty) {
      return version.trim();
    }
  } catch (_) {
    // Keep fallback for environments where JS interop is unavailable.
  }

  return 'dev';
}
