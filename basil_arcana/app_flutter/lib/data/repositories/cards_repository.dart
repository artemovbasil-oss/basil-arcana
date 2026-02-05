import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_model.dart';
import '../models/deck_model.dart';

class CardsRepository {
  Future<List<CardModel>> fetchCards({
    required Locale locale,
    required DeckId deckId,
  }) async {
    if (kDebugMode) {
      await _debugValidateLocalizedData();
    }
    final filename = switch (locale.languageCode) {
      'ru' => 'cards_ru.json',
      'kk' => 'cards_kk.json',
      _ => 'cards_en.json',
    };
    final raw = await rootBundle.loadString('assets/data/$filename');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final canonicalData = _canonicalizeCardData(data);
    final majorCards = canonicalData.entries
        .where((entry) => entry.key.startsWith('major_'))
        .map((entry) {
          return CardModel.fromLocalizedEntry(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        })
        .toList();
    final wandsCards = wandsCardIds
        .where(canonicalData.containsKey)
        .map((id) => CardModel.fromLocalizedEntry(
              id,
              canonicalData[id] as Map<String, dynamic>,
            ))
        .toList();
    final swordsCards = swordsCardIds
        .where(canonicalData.containsKey)
        .map((id) => CardModel.fromLocalizedEntry(
              id,
              canonicalData[id] as Map<String, dynamic>,
            ))
        .toList();
    final pentaclesCards = pentaclesCardIds
        .where(canonicalData.containsKey)
        .map((id) => CardModel.fromLocalizedEntry(
              id,
              canonicalData[id] as Map<String, dynamic>,
            ))
        .toList();
    final cupsCards = cupsCardIds
        .where(canonicalData.containsKey)
        .map((id) => CardModel.fromLocalizedEntry(
              id,
              canonicalData[id] as Map<String, dynamic>,
            ))
        .toList();
    final deckRegistry = <DeckId, List<CardModel>>{
      DeckId.major: majorCards,
      DeckId.wands: wandsCards,
      DeckId.swords: swordsCards,
      DeckId.pentacles: pentaclesCards,
      DeckId.cups: cupsCards,
    };
    assert(() {
      final missing = deckRegistry.values
          .expand((cards) => cards)
          .where(
            (card) =>
                card.detailedDescription == null ||
                card.detailedDescription!.trim().isEmpty,
          )
          .map((card) => card.id)
          .toList();
      if (missing.isNotEmpty) {
        debugPrint('Missing detailedDescription for: ${missing.join(', ')}');
      }
      return missing.isEmpty;
    }());
    return getActiveDeckCards(deckId, deckRegistry);
  }
}

const List<String> _cardLocaleFiles = [
  'cards_en.json',
  'cards_ru.json',
  'cards_kk.json',
];

bool _didValidateLocalizedData = false;

Future<void> _debugValidateLocalizedData() async {
  if (_didValidateLocalizedData) {
    return;
  }
  _didValidateLocalizedData = true;
  final manifestRaw = await rootBundle.loadString('AssetManifest.json');
  final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
  final deckAssetIds = <String, Set<String>>{
    'major': <String>{},
    'wands': <String>{},
    'swords': <String>{},
    'pentacles': <String>{},
    'cups': <String>{},
  };
  for (final path in manifest.keys) {
    final match = RegExp(
      r'^assets/cards/(major|wands|swords|pentacles|cups)/(.+)$',
    ).firstMatch(path);
    if (match == null) {
      continue;
    }
    final deck = match.group(1)!;
    final filename = match.group(2)!;
    final id = canonicalCardId(filename);
    deckAssetIds[deck]?.add(id);
  }

  final localeData = <String, Map<String, Map<String, dynamic>>>{};
  for (final file in _cardLocaleFiles) {
    final raw = await rootBundle.loadString('assets/data/$file');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    localeData[file] = _canonicalizeCardData(data);
  }

  for (final entry in deckAssetIds.entries) {
    final deckName = entry.key;
    final ids = entry.value;
    for (final localeEntry in localeData.entries) {
      final file = localeEntry.key;
      final data = localeEntry.value;
      final missing = ids.where((id) => !data.containsKey(id)).toList();
      if (missing.isNotEmpty) {
        debugPrint(
          'Missing localized entries for deck=$deckName in $file: ${missing.join(', ')}',
        );
      }
      final incomplete = <String>[];
      for (final id in ids) {
        final entryData = data[id];
        if (entryData == null) {
          continue;
        }
        final detailed = (entryData['detailedDescription'] as String?)?.trim();
        final funFact = (entryData['funFact'] as String?)?.trim();
        final stats = entryData['stats'];
        if (detailed == null ||
            detailed.isEmpty ||
            funFact == null ||
            funFact.isEmpty ||
            stats == null) {
          incomplete.add(id);
        }
      }
      if (incomplete.isNotEmpty) {
        debugPrint(
          'Missing details for deck=$deckName in $file: ${incomplete.join(', ')}',
        );
      }
    }
  }
}

Map<String, Map<String, dynamic>> _canonicalizeCardData(
  Map<String, dynamic> data,
) {
  final canonical = <String, Map<String, dynamic>>{};
  for (final entry in data.entries) {
    final key = canonicalCardId(entry.key);
    canonical[key] = entry.value as Map<String, dynamic>;
  }
  return canonical;
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
