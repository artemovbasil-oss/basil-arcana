import 'package:flutter/foundation.dart';

const bool kShowDiagnostics = false;
const bool kEnableRuntimeLogs = false;

bool get kEnableDevDiagnostics => kDebugMode || kShowDiagnostics;

enum FailedStage {
  cardsLocalLoad,
  spreadsLocalLoad,
  openaiCall,
  telegramInitdata,
  mediaLoad,
}

class DevFailureInfo {
  const DevFailureInfo({
    required this.failedStage,
    required this.exceptionType,
    required this.exceptionMessage,
  });

  final String failedStage;
  final String exceptionType;
  final String exceptionMessage;

  String get summary => '$exceptionType: $exceptionMessage';
}

DevFailureInfo buildDevFailureInfo(FailedStage stage, Object error) {
  final exceptionType = error.runtimeType.toString();
  final message = sanitizeExceptionMessage(error.toString());
  return DevFailureInfo(
    failedStage: failedStageLabel(stage),
    exceptionType: exceptionType,
    exceptionMessage: message,
  );
}

void logDevFailure(DevFailureInfo info) {
  if (!kEnableDevDiagnostics) {
    return;
  }
  debugPrint(
    '[Diagnostics] FAILED_STAGE=${info.failedStage} '
    'exception=${info.exceptionType} message="${info.exceptionMessage}"',
  );
}

String failedStageLabel(FailedStage stage) {
  return switch (stage) {
    FailedStage.cardsLocalLoad => 'cards_local_load',
    FailedStage.spreadsLocalLoad => 'spreads_local_load',
    FailedStage.openaiCall => 'openai_call',
    FailedStage.telegramInitdata => 'telegram_initdata',
    FailedStage.mediaLoad => 'media_load',
  };
}

String sanitizeExceptionMessage(String message) {
  var sanitized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (sanitized.length > 200) {
    sanitized = '${sanitized.substring(0, 200)}…';
  }
  return sanitized.isEmpty ? 'unknown error' : sanitized;
}

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
