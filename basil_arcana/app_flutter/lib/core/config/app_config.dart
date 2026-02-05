import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppConfig {
  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _apiKeyEnv = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static String _apiBaseUrl = _apiBaseUrlEnv;
  static String _apiKey = _apiKeyEnv;

  static String get apiBaseUrl => _apiBaseUrl;
  static String get apiKey => _apiKey;

  static Future<void> init() async {
    if (!kIsWeb) {
      return;
    }
    if (_apiBaseUrl.trim().isNotEmpty && _apiKey.trim().isNotEmpty) {
      return;
    }
    try {
      final response = await http.get(Uri.parse('config.json'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final runtimeApiBaseUrl = payload['apiBaseUrl'];
      final runtimeApiKey = payload['apiKey'];
      if (_apiBaseUrl.trim().isEmpty && runtimeApiBaseUrl is String) {
        _apiBaseUrl = runtimeApiBaseUrl.trim();
      }
      if (_apiKey.trim().isEmpty && runtimeApiKey is String) {
        _apiKey = runtimeApiKey.trim();
      }
    } catch (_) {
      // Ignore runtime config errors; fall back to build-time config.
    }
  }
}
