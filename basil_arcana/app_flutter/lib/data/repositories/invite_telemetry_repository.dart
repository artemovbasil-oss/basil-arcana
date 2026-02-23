import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/network/telegram_api_client.dart';

class InviteTelemetryRepository {
  Future<void> track({
    required String eventName,
    required String source,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final name = eventName.trim();
    final eventSource = source.trim();
    if (name.isEmpty || name.length > 80 || eventSource.isEmpty) {
      return;
    }
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/telemetry/event',
    );
    final client = TelegramApiClient(http.Client());
    try {
      await client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'eventName': name,
          'source': eventSource,
          'metadata': metadata,
        }),
      );
    } finally {
      client.close();
    }
  }
}
