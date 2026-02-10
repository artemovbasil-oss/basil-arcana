import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_version.dart';
import 'core/config/diagnostics.dart';
import 'core/config/web_build_version.dart';
import 'core/theme/app_text_styles.dart';
import 'core/widgets/app_buttons.dart';
import 'core/storage/card_cache_cleanup.dart';
import 'core/storage/hive_storage.dart';
import 'data/models/card_model.dart';
import 'data/models/deck_model.dart';
import 'data/repositories/cards_repository.dart';
import 'data/repositories/spreads_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppConfig.init();
    await HiveStorage.init();
    await CardCacheCleanup.clearPersistedCardCaches();
    final settingsBox = Hive.box<String>('settings');
    final languageCode = settingsBox.get('languageCode') ?? 'en';
    final runtimeBuildVersion = (AppConfig.appVersion.isNotEmpty
            ? AppConfig.appVersion
            : readWebBuildVersion())
        .trim();
    final resolvedAppVersion = runtimeBuildVersion.isNotEmpty
        ? runtimeBuildVersion
        : appVersion;
    debugPrint(
      '[Startup] APP_VERSION=$resolvedAppVersion '
      'locale=$languageCode '
      'cardDataSource=local',
    );
    logRuntimeDiagnostics(
      appVersion:
          resolvedAppVersion.isEmpty ? 'unknown' : resolvedAppVersion,
      locale: languageCode,
      cardDataSource: 'local',
      apiBaseUrl: AppConfig.apiBaseUrl,
      schemaVersion: kCardSchemaVersion,
    );

    await _runLocalDataSelfCheck();
    await _runApiAvailabilitySelfCheck();

    runApp(const ProviderScope(child: BasilArcanaApp()));
  } catch (error, stackTrace) {
    runApp(
      _BootstrapErrorApp(
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Future<void> _runApiAvailabilitySelfCheck() async {
  if (!kDebugMode) {
    return;
  }
  final baseUrl = AppConfig.apiBaseUrl.trim();
  if (baseUrl.isEmpty) {
    debugPrint('[SelfCheck] API base URL missing.');
    return;
  }
  final uri = Uri.parse(baseUrl).replace(path: '/api/reading/availability');
  try {
    final response =
        await http.get(uri).timeout(const Duration(seconds: 6));
    final preview = response.body.length > 200
        ? response.body.substring(0, 200)
        : response.body;
    debugPrint(
      '[SelfCheck] availability status=${response.statusCode} '
      'body="${preview.replaceAll('\n', ' ')}"',
    );
  } catch (error) {
    debugPrint('[SelfCheck] availability failed: $error');
  }
}

Future<void> _runLocalDataSelfCheck() async {
  if (!kDebugMode) {
    return;
  }
  const assetFiles = <String>[
    'assets/data/cards_en.json',
    'assets/data/cards_ru.json',
    'assets/data/cards_kz.json',
    'assets/data/spreads_en.json',
    'assets/data/spreads_ru.json',
    'assets/data/spreads_kz.json',
  ];
  for (final asset in assetFiles) {
    try {
      await rootBundle.loadString(asset);
      debugPrint('[SelfCheck] asset load OK: $asset');
    } catch (error) {
      debugPrint('[SelfCheck] asset load FAILED: $asset error=$error');
    }
  }
  final cardsRepo = CardsRepository();
  final spreadsRepo = SpreadsRepository();
  const locales = <String, String>{
    'en': 'EN',
    'ru': 'RU',
    'kk': 'KZ',
  };
  for (final entry in locales.entries) {
    final locale = Locale(entry.key);
    try {
      final cards = await cardsRepo.fetchCards(
        locale: locale,
        deckId: DeckType.all,
      );
      final spreads = await spreadsRepo.fetchSpreads(locale: locale);
      debugPrint(
        '[SelfCheck] cards_${entry.value}=${cards.length} '
        'spreads_${entry.value}=${spreads.length}',
      );
    } catch (error) {
      debugPrint('[SelfCheck] ${entry.value} failed: $error');
    }
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F12),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unable to start Basil’s Arcana',
                  style: AppTextStyles.title(context)
                      .copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  style: AppTextStyles.body(context)
                      .copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  AppPrimaryButton(
                    onPressed: () async {
                      await HiveStorage.resetAndReload();
                    },
                    label: 'Reset data',
                  ),
                ],
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: AppTextStyles.caption(context).copyWith(
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
