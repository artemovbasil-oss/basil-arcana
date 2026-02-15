import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/network/telegram_api_client.dart';
import '../models/card_model.dart';

class HomeStreakStats {
  const HomeStreakStats({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.activeDays,
    required this.awarenessPercent,
    required this.awarenessLocked,
    this.lastActiveAt,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final int activeDays;
  final int awarenessPercent;
  final bool awarenessLocked;
  final DateTime? lastActiveAt;

  static const empty = HomeStreakStats(
    currentStreakDays: 0,
    longestStreakDays: 0,
    activeDays: 0,
    awarenessPercent: 30,
    awarenessLocked: false,
  );
}

class HomeInsightsRepository {
  static const Duration _timeout = Duration(seconds: 15);

  Future<HomeStreakStats> fetchStreakStats() async {
    final uri =
        Uri.parse(ApiConfig.apiBaseUrl).replace(path: '/api/user/streak');
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load streak');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid streak response');
      }
      final rawAwareness = (decoded['awarenessPercent'] as num?)?.toInt() ?? 30;
      return HomeStreakStats(
        currentStreakDays: (decoded['currentStreakDays'] as num?)?.toInt() ?? 0,
        longestStreakDays: (decoded['longestStreakDays'] as num?)?.toInt() ?? 0,
        activeDays: (decoded['activeDays'] as num?)?.toInt() ?? 0,
        awarenessPercent: rawAwareness.clamp(30, 100),
        awarenessLocked: decoded['awarenessLocked'] == true,
        lastActiveAt: decoded['lastActiveAt'] is String
            ? DateTime.tryParse(decoded['lastActiveAt'] as String)?.toLocal()
            : null,
      );
    } finally {
      client.close();
    }
  }

  Future<String> fetchDailyCardInterpretation({
    required CardModel card,
    required String locale,
  }) async {
    final uri =
        Uri.parse(ApiConfig.apiBaseUrl).replace(path: '/api/home/daily-card');
    final client = TelegramApiClient(http.Client());
    try {
      final payload = {
        'locale': locale,
        'card': {
          'id': card.id,
          'name': card.name,
          'keywords': card.keywords,
          'meaning': {
            'general': card.meaning.general,
            'light': card.meaning.light,
            'shadow': card.meaning.shadow,
            'advice': card.meaning.advice,
          },
        },
      };
      final response = await client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load daily card interpretation');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid daily card response');
      }
      final interpretation =
          (decoded['interpretation'] as String?)?.trim() ?? '';
      if (interpretation.isEmpty) {
        throw Exception('Empty daily card interpretation');
      }
      return interpretation;
    } finally {
      client.close();
    }
  }
}
