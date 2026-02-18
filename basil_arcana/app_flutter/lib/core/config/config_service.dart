import 'dart:async';
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

  static const String _assetsBaseUrlEnv = String.fromEnvironment(
    'ASSETS_BASE_URL',
    defaultValue: '',
  );

  static const String _appVersionEnv = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '',
  );
  static const Duration _configLoadTimeout = Duration(seconds: 4);

  String _apiBaseUrl = _apiBaseUrlEnv;
  String _assetsBaseUrl = _normalizeBaseUrl(
    _assetsBaseUrlEnv,
    fallback: '',
  );
  String _appVersion = _appVersionEnv;
  String? _lastError;

  String? _resolvedBuildToken;
  Future<void>? _loadFuture;

  String get apiBaseUrl => _apiBaseUrl;
  String get appVersion => _appVersion;
  String? get lastError => _lastError;
  bool get isConfigured => _apiBaseUrl.trim().isNotEmpty;

  String get assetsBaseUrl =>
      _normalizeBaseUrl(_assetsBaseUrl, fallback: _defaultAssetsBaseUrl);

  Future<void> load({bool forceRefresh = false}) {
    if (!kIsWeb) {
      return Future.value();
    }

    if (!forceRefresh && _loadFuture != null) {
      return _loadFuture!;
    }

    final token = _resolveBuildToken();
    final uri = Uri.parse('/config.json').replace(
      queryParameters: {'v': token},
    );

    if (kDebugMode) {
      debugPrint('[ConfigService] buildToken=$token');
      debugPrint('[ConfigService] configUrl=${uri.toString()}');
    }

    final future = _fetchConfig(uri);
    _loadFuture = future;
    return future;
  }

  String _resolveBuildToken() {
    if (_resolvedBuildToken != null) {
      return _resolvedBuildToken!;
    }

    final resolved = readWebBuildVersion().trim();
    _resolvedBuildToken = resolved.isNotEmpty ? resolved : 'dev';
    return _resolvedBuildToken!;
  }

  Future<void> _fetchConfig(Uri uri) async {
    try {
      final response = await http.get(
        uri,
        headers: const {
          'Cache-Control': 'no-store',
          'Pragma': 'no-cache',
        },
      ).timeout(_configLoadTimeout);
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
      final runtimeAssetsBaseUrl = payload['assetsBaseUrl'];
      final runtimeAppVersion = payload['appVersion'];

      if (runtimeApiBaseUrl is String && runtimeApiBaseUrl.trim().isNotEmpty) {
        _apiBaseUrl = runtimeApiBaseUrl.trim();
      }
      if (_assetsBaseUrlEnv.trim().isEmpty && runtimeAssetsBaseUrl is String) {
        _assetsBaseUrl = _normalizeBaseUrl(
          runtimeAssetsBaseUrl,
          fallback: _defaultAssetsBaseUrl,
        );
      }
      if (_appVersionEnv.trim().isEmpty &&
          runtimeAppVersion is String &&
          runtimeAppVersion.trim().isNotEmpty) {
        _appVersion = runtimeAppVersion.trim();
      }
    } on TimeoutException catch (_) {
      _lastError = 'Config load failed: timeout after '
          '${_configLoadTimeout.inSeconds}s';
      WebErrorReporter.instance.report(_lastError!);
    } catch (error) {
      _lastError = 'Config load failed: ${error.toString()}';
      WebErrorReporter.instance.report(_lastError!);
    }
  }
}

String _normalizeBaseUrl(String value, {required String fallback}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  final normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
  if (normalized.endsWith('/data')) {
    return normalized.substring(0, normalized.length - '/data'.length);
  }
  return normalized;
}
