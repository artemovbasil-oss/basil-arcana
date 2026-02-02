import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_model.dart';

class CardsRepository {
  Future<List<CardModel>> fetchCards({required Locale locale}) async {
    final filename = switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kk.json',
      _ => 'cards_en.json',
    };
    final raw = await rootBundle.loadString('assets/data/$filename');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return data.entries
        .map((entry) {
          return CardModel.fromLocalizedEntry(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        })
        .toList();
  }
}
