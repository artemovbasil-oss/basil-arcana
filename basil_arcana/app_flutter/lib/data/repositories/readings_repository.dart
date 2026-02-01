import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reading_model.dart';

class ReadingsRepository {
  Box<ReadingModel> get _box => Hive.box<ReadingModel>('readings');

  Future<void> saveReading(ReadingModel reading) async {
    await _box.put(reading.readingId, reading);
  }

  List<ReadingModel> getReadings() {
    final readings = _box.values.toList();
    readings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return readings;
  }

  ValueListenable<Box<ReadingModel>> listenable() => _box.listenable();

  ReadingModel? getReading(String readingId) => _box.get(readingId);
}
