import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/card_model.dart';

class CardsRepository {
  Future<List<CardModel>> fetchCards() async {
    final raw = await rootBundle.loadString('assets/data/cards_major_en.json');
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => CardModel.fromJson(item)).toList();
  }
}
