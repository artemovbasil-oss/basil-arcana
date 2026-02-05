import 'config_service.dart';

class AppConfig {
  AppConfig._();

  static ConfigService get _service => ConfigService.instance;

  static String get apiBaseUrl => _service.apiBaseUrl;
  static String get apiKey => _service.apiKey;
  static String? get build => _service.build;
  static String? get lastError => _service.lastError;
  static bool get isConfigured => _service.isConfigured;

  static Future<void> init() => _service.load();
}
