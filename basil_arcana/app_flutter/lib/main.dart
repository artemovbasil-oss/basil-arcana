import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/diagnostics.dart';
import 'core/config/web_build_version.dart';
import 'core/theme/app_text_styles.dart';
import 'core/widgets/app_buttons.dart';
import 'core/storage/card_cache_cleanup.dart';
import 'core/storage/hive_storage.dart';
import 'data/models/card_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppConfig.init();
    await HiveStorage.init();
    await CardCacheCleanup.clearPersistedCardCaches();
    final settingsBox = Hive.box<String>('settings');
    final languageCode = settingsBox.get('languageCode') ?? 'en';
    final appVersion = (AppConfig.build ?? readWebBuildVersion()).trim();
    logRuntimeDiagnostics(
      appVersion: appVersion.isEmpty ? 'unknown' : appVersion,
      locale: languageCode,
      cardDataSource: 'embedded',
      apiBaseUrl: AppConfig.apiBaseUrl,
      schemaVersion: kCardSchemaVersion,
    );

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
