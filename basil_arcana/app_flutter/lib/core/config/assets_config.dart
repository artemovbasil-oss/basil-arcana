import 'config_service.dart';

class AssetsConfig {
  AssetsConfig._();

  static String get assetsBaseUrl =>
      ConfigService.instance.assetsBaseUrl;
}
