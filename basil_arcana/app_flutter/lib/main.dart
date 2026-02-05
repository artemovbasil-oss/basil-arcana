import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/models/drawn_card_model.dart';
import 'data/models/ai_result_model.dart';
import 'data/models/reading_model.dart';
import 'data/models/card_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppConfig.init();
    await Hive.initFlutter();
    Hive.registerAdapter(CardMeaningAdapter());
    Hive.registerAdapter(DrawnCardModelAdapter());
    Hive.registerAdapter(AiSectionModelAdapter());
    Hive.registerAdapter(ReadingModelAdapter());
    await Hive.openBox<ReadingModel>('readings');
    await Hive.openBox<String>('settings');
    await Hive.openBox<int>('card_stats');

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
                const Text(
                  'Unable to start Basil’s Arcana',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
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
