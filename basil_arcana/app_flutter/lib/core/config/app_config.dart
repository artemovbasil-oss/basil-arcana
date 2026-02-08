import 'config_service.dart';

class AppConfig {
  AppConfig._();

  static ConfigService get _service => ConfigService.instance;

  static String get apiBaseUrl => _service.apiBaseUrl;
  static String get assetsBaseUrl => _service.assetsBaseUrl;
  static String get appVersion => _service.appVersion;
  static String? get lastError => _service.lastError;
  static bool get isConfigured => _service.isConfigured;

  static Future<void> init() => _service.load();
}
