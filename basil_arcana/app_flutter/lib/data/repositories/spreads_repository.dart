import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/spread_model.dart';

class SpreadsRepository {
  Future<List<SpreadModel>> fetchSpreads({required Locale locale}) async {
    final languageCode = locale.languageCode;
    final fileName = switch (languageCode) {
      'ru' => 'spreads_ru.json',
      'kk' => 'spreads_kk.json',
      _ => 'spreads_en.json',
    };
    final raw = await rootBundle.loadString('assets/data/$fileName');
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => SpreadModel.fromJson(item)).toList();
  }
}
