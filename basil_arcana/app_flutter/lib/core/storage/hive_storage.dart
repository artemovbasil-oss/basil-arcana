import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../config/web_build_version.dart';
import '../utils/web_page.dart';
import '../utils/web_storage.dart';
import '../../data/models/ai_result_model.dart';
import '../../data/models/card_model.dart';
import '../../data/models/drawn_card_model.dart';
import '../../data/models/reading_model.dart';

class HiveStorage {
  HiveStorage._();

  static const String readingsBox = 'readings';
  static const String settingsBox = 'settings';
  static const String cardStatsBox = 'card_stats';

  static const String _buildIdKey = 'basil_arcana_build_id';
  static const List<String> _cachePrefixesToClear = [
    'cdn_cards_',
    'cdn_spreads_',
    'cdn_video_index',
    'flutter.cdn_cards_',
    'flutter.cdn_spreads_',
    'flutter.cdn_video_index',
  ];

  static Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();
    await _applyBuildIdSafeguard();
    await _openBoxesWithRecovery();
  }

  static Future<void> resetAndReload() async {
    await resetStorage(clearWebStorage: true);
    reloadWebPage();
  }

  static Future<void> resetStorage({required bool clearWebStorage}) async {
    await _closeHive();
    await _deleteBoxes();
    if (kIsWeb && clearWebStorage) {
      clearWebStorageWithPrefixes(['Hive', 'hive']);
      removeWebStorage(_buildIdKey);
    }
  }

  static void _registerAdapters() {
    _registerAdapterIfNeeded(CardMeaningAdapter());
    _registerAdapterIfNeeded(DrawnCardModelAdapter());
    _registerAdapterIfNeeded(AiSectionModelAdapter());
    _registerAdapterIfNeeded(ReadingModelAdapter());
  }

  static void _registerAdapterIfNeeded(TypeAdapter<dynamic> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  static Future<void> _openBoxesWithRecovery() async {
    try {
      await _openBoxes();
    } catch (error) {
      if (!kIsWeb || !_isRecoverableHiveError(error)) {
        rethrow;
      }
      await resetStorage(clearWebStorage: true);
      await _openBoxes();
    }
  }

  static Future<void> _openBoxes() async {
    await Hive.openBox<ReadingModel>(readingsBox);
    await Hive.openBox<String>(settingsBox);
    await Hive.openBox<int>(cardStatsBox);
  }

  static Future<void> _applyBuildIdSafeguard() async {
    if (!kIsWeb) {
      return;
    }
    final buildId =
        (AppConfig.appVersion.isNotEmpty
                ? AppConfig.appVersion
                : readWebBuildVersion())
            .trim();
    if (buildId.isEmpty) {
      return;
    }
    final previousBuildId = readWebStorage(_buildIdKey);
    if (previousBuildId != null && previousBuildId != buildId) {
      await resetStorage(clearWebStorage: false);
      _clearCachedJsonData();
    }
    writeWebStorage(_buildIdKey, buildId);
  }

  static void _clearCachedJsonData() {
    if (!kIsWeb) {
      return;
    }
    clearWebStorageWithPrefixes(_cachePrefixesToClear);
  }

  static bool _isRecoverableHiveError(Object error) {
    if (error is HiveError) {
      final message = error.toString().toLowerCase();
      return message.contains('unknown typeid') ||
          message.contains('unknown typeld') ||
          message.contains('cannot read');
    }
    return false;
  }

  static Future<void> _closeHive() async {
    try {
      await Hive.close();
    } catch (_) {}
  }

  static Future<void> _deleteBoxes() async {
    await _deleteBox(readingsBox);
    await _deleteBox(settingsBox);
    await _deleteBox(cardStatsBox);
  }

  static Future<void> _deleteBox(String boxName) async {
    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {}
  }
}
