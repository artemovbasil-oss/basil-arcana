import 'config_service.dart';

class ApiConfig {
  ApiConfig._();

  static String get apiBaseUrl => ConfigService.instance.apiBaseUrl;
}
