import '../../data/models/card_video.dart';
import '../../data/models/deck_model.dart';
import '../config/assets_config.dart';

String cardImageUrl(
  String cardId, {
  DeckId deckId = DeckId.major,
}) {
  final normalizedId = canonicalCardId(cardId);
  final base = AssetsConfig.assetsBaseUrl;
  if (deckId == DeckId.wands ||
      (deckId == DeckId.all && normalizedId.startsWith('wands_'))) {
    return '$base/cards/wands/$normalizedId.webp';
  }
  if (deckId == DeckId.swords ||
      (deckId == DeckId.all && normalizedId.startsWith('swords_'))) {
    return '$base/cards/swords/$normalizedId.webp';
  }
  if (deckId == DeckId.pentacles ||
      (deckId == DeckId.all && normalizedId.startsWith('pentacles_'))) {
    return '$base/cards/pentacles/$normalizedId.webp';
  }
  if (deckId == DeckId.cups ||
      (deckId == DeckId.all && normalizedId.startsWith('cups_'))) {
    return '$base/cards/cups/$normalizedId.webp';
  }
  switch (normalizedId) {
    case 'major_10_wheel':
      return '$base/cards/major/major_10_wheel_of_fortune.webp';
    default:
      return '$base/cards/major/$normalizedId.webp';
  }
}

String spreadsUrl(String languageCode) {
  final base = AssetsConfig.assetsBaseUrl;
  final normalized = languageCode.trim().toLowerCase();
  final lang = switch (normalized) {
    'ru' => 'ru',
    'kk' => 'kz',
    'kz' => 'kz',
    _ => 'en',
  };
  return '$base/data/spreads_${lang}.json';
}

String cardsUrl(String languageCode) {
  final base = AssetsConfig.assetsBaseUrl;
  final normalized = languageCode.trim().toLowerCase();
  final lang = switch (normalized) {
    'ru' => 'ru',
    'kk' => 'kz',
    'kz' => 'kz',
    _ => 'en',
  };
  return '$base/data/cards_${lang}.json';
}

String? videoUrlForCard(
  String cardId, {
  Set<String>? availableVideoFiles,
  String? videoFileNameOverride,
}) {
  final fileName = videoFileNameOverride ??
      resolveCardVideoFileName(cardId, availableFiles: availableVideoFiles);
  if (fileName == null) {
    return null;
  }
  final base = AssetsConfig.assetsBaseUrl;
  return '$base/video/${normalizeVideoFileName(fileName)}';
}

String deckCoverAssetPath(DeckId deckId) {
  switch (deckId) {
    case DeckId.wands:
    case DeckId.swords:
    case DeckId.pentacles:
    case DeckId.cups:
    case DeckId.major:
    case DeckId.all:
    default:
      return 'assets/deck/cover.webp';
  }
}
