import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/network/telegram_api_client.dart';

class UserDashboardProfile {
  const UserDashboardProfile({
    required this.telegramUserId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.photoUrl,
  });

  final int telegramUserId;
  final String firstName;
  final String lastName;
  final String username;
  final String photoUrl;
}

class UserDashboardService {
  const UserDashboardService({
    required this.id,
    required this.type,
    required this.status,
    this.expiresAt,
  });

  final String id;
  final String type;
  final String status;
  final DateTime? expiresAt;
}

class UserDashboardData {
  const UserDashboardData({
    required this.profile,
    required this.referralLink,
    required this.freeFiveCardsCredits,
    required this.totalInvited,
    required this.services,
  });

  final UserDashboardProfile profile;
  final String referralLink;
  final int freeFiveCardsCredits;
  final int totalInvited;
  final List<UserDashboardService> services;
}

class UserDashboardRepositoryException implements Exception {
  const UserDashboardRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (status: $statusCode)';
}

class ConsumeFiveCardsCreditResult {
  const ConsumeFiveCardsCreditResult({
    required this.consumed,
    required this.remaining,
  });

  final bool consumed;
  final int remaining;
}

class UserDashboardRepository {
  Future<UserDashboardData> fetchDashboard() async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/user/dashboard',
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UserDashboardRepositoryException(
          'Failed to load dashboard',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const UserDashboardRepositoryException(
            'Invalid dashboard response');
      }

      final profileRaw = decoded['profile'];
      final referralRaw = decoded['referral'];
      final perksRaw = decoded['perks'];
      final referralsRaw = decoded['referrals'];
      final servicesRaw = decoded['services'];

      if (profileRaw is! Map<String, dynamic>) {
        throw const UserDashboardRepositoryException('Missing profile payload');
      }

      final profile = UserDashboardProfile(
        telegramUserId: (profileRaw['telegramUserId'] as num?)?.toInt() ?? 0,
        firstName: (profileRaw['firstName'] as String?)?.trim() ?? '',
        lastName: (profileRaw['lastName'] as String?)?.trim() ?? '',
        username: (profileRaw['username'] as String?)?.trim() ?? '',
        photoUrl: (profileRaw['photoUrl'] as String?)?.trim() ?? '',
      );

      final services = <UserDashboardService>[];
      if (servicesRaw is List) {
        for (final item in servicesRaw) {
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final expiresAtRaw = item['expiresAt'];
          services.add(
            UserDashboardService(
              id: (item['id'] as String?)?.trim() ?? '',
              type: (item['type'] as String?)?.trim() ?? '',
              status: (item['status'] as String?)?.trim() ?? '',
              expiresAt: expiresAtRaw is String
                  ? DateTime.tryParse(expiresAtRaw)?.toLocal()
                  : null,
            ),
          );
        }
      }

      return UserDashboardData(
        profile: profile,
        referralLink: referralRaw is Map<String, dynamic>
            ? ((referralRaw['link'] as String?)?.trim() ?? '')
            : '',
        freeFiveCardsCredits: perksRaw is Map<String, dynamic>
            ? (perksRaw['freeFiveCardsCredits'] as num?)?.toInt() ?? 0
            : 0,
        totalInvited: referralsRaw is Map<String, dynamic>
            ? (referralsRaw['totalInvited'] as num?)?.toInt() ?? 0
            : 0,
        services: services,
      );
    } finally {
      client.close();
    }
  }

  Future<ConsumeFiveCardsCreditResult> consumeFreeFiveCardsCredit() async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/premium/five-cards/consume',
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UserDashboardRepositoryException(
          'Failed to consume premium credit',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const UserDashboardRepositoryException(
          'Invalid premium credit response',
        );
      }
      return ConsumeFiveCardsCreditResult(
        consumed: decoded['consumed'] == true,
        remaining: (decoded['remaining'] as num?)?.toInt() ?? 0,
      );
    } finally {
      client.close();
    }
  }
}
