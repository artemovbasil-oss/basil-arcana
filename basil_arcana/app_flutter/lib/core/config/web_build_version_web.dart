import 'dart:js_util' as js_util;

String readWebBuildVersion() {
  final buildId = js_util.getProperty(js_util.globalThis, '__BUILD_ID__');
  if (buildId is String && buildId.trim().isNotEmpty) {
    return buildId.trim();
  }

  final version = js_util.getProperty(
    js_util.globalThis,
    '__buildVersion',
  );
  if (version is String && version.trim().isNotEmpty) {
    return version.trim();
  }
  return '';
}
