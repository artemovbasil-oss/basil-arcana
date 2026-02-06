import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../telemetry/web_error_reporter.dart';
import 'web_build_version.dart';

class ConfigService {
  ConfigService._();

  static final ConfigService instance = ConfigService._();

  static const String _defaultAssetsBaseUrl = 'https://cdn.basilarcana.com';

  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _apiKeyEnv = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static const String _assetsBaseUrlEnv = String.fromEnvironment(
    'ASSETS_BASE_URL',
    defaultValue: _defaultAssetsBaseUrl,
  );

  String _apiBaseUrl = _apiBaseUrlEnv;
  String _apiKey = _apiKeyEnv;
  String _assetsBaseUrl = _normalizeBaseUrl(_assetsBaseUrlEnv);
  String? _build;
  String? _lastError;

  String get apiBaseUrl => _apiBaseUrl;
  String? get build => _build;
  String? get lastError => _lastError;
  bool get isConfigured => _apiBaseUrl.trim().isNotEmpty;

  String get apiKey => kIsWeb ? _apiKey : _apiKeyEnv;
  String get assetsBaseUrl => _assetsBaseUrl;

  Future<void> load() async {
    if (!kIsWeb) {
      return;
    }
    final cacheBust = readWebBuildVersion();
    final uri = Uri.parse('/config.json').replace(
      queryParameters: {'v': cacheBust.isEmpty ? 'dev' : cacheBust},
    );
    try {
      final response = await http.get(
        uri,
        headers: {'Cache-Control': 'no-cache'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = 'Config load failed (${response.statusCode})';
        WebErrorReporter.instance.report(_lastError!);
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        _lastError = 'Config load failed (invalid JSON payload)';
        WebErrorReporter.instance.report(_lastError!);
        return;
      }
      final runtimeApiBaseUrl = payload['apiBaseUrl'];
      final runtimeBuild = payload['build'];
      final runtimeApiKey = payload['apiKey'];
      final runtimeAssetsBaseUrl = payload['assetsBaseUrl'];
      if (runtimeApiBaseUrl is String && runtimeApiBaseUrl.trim().isNotEmpty) {
        _apiBaseUrl = runtimeApiBaseUrl.trim();
      }
      if (runtimeApiKey is String) {
        _apiKey = runtimeApiKey.trim();
      }
      if (runtimeAssetsBaseUrl is String &&
          runtimeAssetsBaseUrl.trim().isNotEmpty) {
        _assetsBaseUrl = _normalizeBaseUrl(runtimeAssetsBaseUrl);
      }
      if (runtimeBuild is String && runtimeBuild.trim().isNotEmpty) {
        _build = runtimeBuild.trim();
      }
    } catch (error) {
      _lastError = 'Config load failed: ${error.toString()}';
      WebErrorReporter.instance.report(_lastError!);
    }
  }
}

String _normalizeBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return trimmed.replaceAll(RegExp(r'/+$'), '');
}
