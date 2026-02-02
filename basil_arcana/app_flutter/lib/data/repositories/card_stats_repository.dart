import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class CardStatsRepository {
  static const boxName = 'card_stats';

  Box<int> get _box => Hive.box<int>(boxName);

  Future<void> increment(String cardId) async {
    final current = _box.get(cardId, defaultValue: 0) ?? 0;
    await _box.put(cardId, current + 1);
  }

  int getCount(String cardId) {
    return _box.get(cardId, defaultValue: 0) ?? 0;
  }

  Map<String, int> getAllCounts() {
    return _box.toMap().map((key, value) => MapEntry(key as String, value));
  }

  ValueListenable<Box<int>> listenable() => _box.listenable();
}
