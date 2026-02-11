import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/network/telegram_api_client.dart';

enum SofiaConsentDecision { accepted, rejected }

extension SofiaConsentDecisionValue on SofiaConsentDecision {
  String get value {
    return switch (this) {
      SofiaConsentDecision.accepted => 'accepted',
      SofiaConsentDecision.rejected => 'rejected',
    };
  }
}

class SofiaConsentRepository {
  static const Duration _timeout = Duration(seconds: 12);

  Future<void> submitDecision(SofiaConsentDecision decision) async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/sofia/consent',
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'decision': decision.value,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to submit consent decision');
      }
    } finally {
      client.close();
    }
  }
}
