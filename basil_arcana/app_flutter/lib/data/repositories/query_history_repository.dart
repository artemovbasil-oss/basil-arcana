import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/network/telegram_api_client.dart';

class QueryHistoryItem {
  const QueryHistoryItem({
    required this.queryType,
    required this.question,
    required this.createdAt,
    this.locale,
  });

  final String queryType;
  final String question;
  final DateTime createdAt;
  final String? locale;
}

class QueryHistoryRepository {
  static const Duration _timeout = Duration(seconds: 12);

  Future<List<QueryHistoryItem>> fetchRecent({int limit = 30}) async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/history/queries',
      queryParameters: {
        'limit': '${limit.clamp(1, 100)}',
      },
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load query history');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid query history response');
      }
      final itemsRaw = decoded['items'];
      if (itemsRaw is! List) {
        return const [];
      }
      final items = <QueryHistoryItem>[];
      for (final item in itemsRaw) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final question = item['question'];
        final queryType = item['queryType'];
        final createdAtRaw = item['createdAt'];
        if (question is! String ||
            question.trim().isEmpty ||
            queryType is! String ||
            createdAtRaw is! String) {
          continue;
        }
        final normalizedQueryType = queryType.trim().toLowerCase();
        if (!normalizedQueryType.startsWith('reading_') ||
            normalizedQueryType == 'reading_details') {
          continue;
        }
        final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
        if (createdAt == null) {
          continue;
        }
        final locale = item['locale'];
        items.add(
          QueryHistoryItem(
            queryType: normalizedQueryType,
            question: question.trim(),
            createdAt: createdAt,
            locale:
                locale is String && locale.trim().isNotEmpty ? locale : null,
          ),
        );
      }
      return items;
    } finally {
      client.close();
    }
  }

  Future<void> clearAll() async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/history/queries',
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client.delete(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to clear query history');
      }
    } finally {
      client.close();
    }
  }
}
