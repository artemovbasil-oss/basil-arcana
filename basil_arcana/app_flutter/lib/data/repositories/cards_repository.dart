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
    final majorCards = data.entries
        .where((entry) => entry.key.startsWith('major_'))
        .map((entry) {
          return CardModel.fromLocalizedEntry(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        })
        .toList();
    final wandsCards = wandsCardIds
        .where(data.containsKey)
        .map((id) => CardModel.fromLocalizedEntry(
              id,
              data[id] as Map<String, dynamic>,
            ))
        .toList();
    final deckRegistry = <DeckId, List<CardModel>>{
      DeckId.major: majorCards,
      DeckId.wands: wandsCards,
    };
    return getActiveDeckCards(deckId, deckRegistry);
  }
}

List<CardModel> getActiveDeckCards(
  DeckId? selectedDeckId,
  Map<DeckId, List<CardModel>> deckRegistry,
) {
  if (selectedDeckId == null || selectedDeckId == DeckId.all) {
    return deckRegistry.values.expand((cards) => cards).toList();
  }
  return deckRegistry[selectedDeckId] ?? const [];
}
