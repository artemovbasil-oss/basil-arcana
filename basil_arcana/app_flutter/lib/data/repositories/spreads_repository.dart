import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/spread_model.dart';

class SpreadsRepository {
  Future<List<SpreadModel>> fetchSpreads() async {
    final raw = await rootBundle.loadString('assets/data/spreads_en.json');
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => SpreadModel.fromJson(item)).toList();
  }
}
