import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_model.dart';
import '../models/deck_model.dart';

class CardsRepository {
  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckId deckId,
  }) async {
    final filename = switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kk.json',
      _ => 'cards_en.json',
    };
    final raw = await rootBundle.loadString('assets/data/$filename');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (deckId == DeckId.wands) {
      return wandsCardIds
          .where(data.containsKey)
          .map((id) => CardModel.fromLocalizedEntry(
                id,
                data[id] as Map<String, dynamic>,
              ))
          .toList();
    }
    return data.entries
        .where((entry) => entry.key.startsWith('major_'))
        .map((entry) {
          return CardModel.fromLocalizedEntry(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        })
        .toList();
  }
}
