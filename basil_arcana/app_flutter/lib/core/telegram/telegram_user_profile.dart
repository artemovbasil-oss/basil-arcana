import 'dart:convert';

import 'telegram_env.dart';

class TelegramUserProfile {
  const TelegramUserProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.photoUrl,
  });

  final int userId;
  final String firstName;
  final String lastName;
  final String username;
  final String photoUrl;

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    if (username.isNotEmpty) {
      final raw = username.startsWith('@') ? username.substring(1) : username;
      return raw.substring(0, raw.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'BA';
  }
}

String encodeReferralCode(int userId) => 'u${userId.toRadixString(36)}';

String buildReferralLinkForUserId(int userId) {
  if (userId <= 0) {
    return 'https://t.me/tarot_arkana_bot/app';
  }
  return 'https://t.me/tarot_arkana_bot/app?startapp=ref_${encodeReferralCode(userId)}';
}

TelegramUserProfile? readTelegramUserProfile() {
  final initData = TelegramEnv.instance.initData.trim();
  if (initData.isEmpty) {
    return null;
  }
  try {
    final params = Uri.splitQueryString(initData);
    final rawUser = params['user'];
    if (rawUser == null || rawUser.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(rawUser);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final userId = (decoded['id'] as num?)?.toInt() ?? 0;
    if (userId <= 0) {
      return null;
    }
    return TelegramUserProfile(
      userId: userId,
      firstName: (decoded['first_name'] as String?)?.trim() ?? '',
      lastName: (decoded['last_name'] as String?)?.trim() ?? '',
      username: (decoded['username'] as String?)?.trim() ?? '',
      photoUrl: (decoded['photo_url'] as String?)?.trim() ?? '',
    );
  } catch (_) {
    return null;
  }
}
