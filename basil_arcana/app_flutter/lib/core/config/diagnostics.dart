import 'package:flutter/foundation.dart';

const bool kShowDiagnostics = false;
const bool kEnableRuntimeLogs = false;

void logRuntimeDiagnostics({
  required String appVersion,
  required String locale,
  required String cardDataSource,
  required String apiBaseUrl,
  required int schemaVersion,
}) {
  if (!kEnableRuntimeLogs) {
    return;
  }
  debugPrint(
    '[RuntimeDiagnostics] '
    'APP_VERSION=$appVersion '
    'locale=$locale '
    'cardDataSource=$cardDataSource '
    'apiBaseUrl=$apiBaseUrl '
    'schemaVersion=$schemaVersion',
  );
}
