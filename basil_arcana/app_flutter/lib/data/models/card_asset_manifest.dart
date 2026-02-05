import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'deck_model.dart';

class CardAssetManifest {
  const CardAssetManifest({
    required this.assetsById,
    required this.assetsByRankKey,
    required this.deckAssetIds,
  });

  final Map<String, String> assetsById;
  final Map<String, String> assetsByRankKey;
  final Map<String, Set<String>> deckAssetIds;

  String? resolveAssetPath(String cardId) {
    final normalized = canonicalCardId(cardId);
    final direct = assetsById[normalized];
    if (direct != null) {
      return direct;
    }
    final rankKey = _rankKeyForId(normalized);
    if (rankKey == null) {
      return null;
    }
    return assetsByRankKey[rankKey];
  }
}

CardAssetManifest? _cardAssetManifestCache;
Future<CardAssetManifest>? _cardAssetManifestFuture;

Future<CardAssetManifest> loadCardAssetManifest() {
  final cached = _cardAssetManifestCache;
  if (cached != null) {
    return Future.value(cached);
  }
  final future = _cardAssetManifestFuture;
  if (future != null) {
    return future;
  }
  _cardAssetManifestFuture = rootBundle.loadString('AssetManifest.json').then(
    (raw) {
      final manifest = jsonDecode(raw) as Map<String, dynamic>;
      final assetsById = <String, String>{};
      final assetsByRankKey = <String, String>{};
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
        assetsById[id] = path;
        deckAssetIds[deck]?.add(id);
        final rankKey = _rankKeyForId(id);
        if (rankKey != null) {
          assetsByRankKey.putIfAbsent(rankKey, () => path);
        }
      }
      final result = CardAssetManifest(
        assetsById: assetsById,
        assetsByRankKey: assetsByRankKey,
        deckAssetIds: deckAssetIds,
      );
      _cardAssetManifestCache = result;
      return result;
    },
  );
  return _cardAssetManifestFuture!;
}

Future<void> debugValidateDeckAssets() async {
  final manifest = await loadCardAssetManifest();
  final expectedDecks = <String, List<String>>{
    'wands': wandsCardIds,
    'swords': swordsCardIds,
    'pentacles': pentaclesCardIds,
    'cups': cupsCardIds,
  };
  for (final entry in expectedDecks.entries) {
    final deck = entry.key;
    final expected = entry.value.map(canonicalCardId).toSet();
    final actual = manifest.deckAssetIds[deck] ?? <String>{};
    final missing = expected.difference(actual);
    if (missing.isNotEmpty || actual.length != expected.length) {
      debugPrint(
        'Deck asset mismatch for $deck: expected ${expected.length}, found ${actual.length}.',
      );
      if (missing.isNotEmpty) {
        debugPrint('Missing assets for $deck: ${missing.join(', ')}');
      }
    }
  }
}

String? _rankKeyForId(String normalizedId) {
  final match = RegExp(
    r'^(major|wands|swords|pentacles|cups)_\d+_(.+)$',
  ).firstMatch(normalizedId);
  if (match == null) {
    return null;
  }
  return '${match.group(1)}_${match.group(2)}';
}
