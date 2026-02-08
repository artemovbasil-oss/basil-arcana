import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/diagnostics.dart';
import '../utils/web_storage.dart';

class CardCacheCleanup {
  CardCacheCleanup._();

  static const List<String> _cardCacheKeyFragments = [
    'cards_',
    'cardsCache',
    'cards-cache',
    'deckCards',
    'cardsRu',
    'cardsKz',
    'cardsEn',
    'cdn_cards_',
    'flutter.cdn_cards_',
    'basil_cards',
  ];

  static Future<void> clearPersistedCardCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final keysToRemove = keys
        .where(
          (key) =>
              _cardCacheKeyFragments.any((fragment) => key.contains(fragment)),
        )
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
    if (kIsWeb) {
      clearWebStorageWithSubstrings(_cardCacheKeyFragments);
    }
    if (kEnableRuntimeLogs) {
      debugPrint(
        '[CardCacheCleanup] removedKeys=${keysToRemove.length}',
      );
    }
  }
}
