import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/models/drawn_card_model.dart';
import 'data/models/ai_result_model.dart';
import 'data/models/reading_model.dart';
import 'data/models/card_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(CardMeaningAdapter());
  Hive.registerAdapter(DrawnCardModelAdapter());
  Hive.registerAdapter(AiSectionModelAdapter());
  Hive.registerAdapter(ReadingModelAdapter());
  await Hive.openBox<ReadingModel>('readings');

  runApp(const ProviderScope(child: BasilArcanaApp()));
}
