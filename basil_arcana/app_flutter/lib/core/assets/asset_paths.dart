import '../../data/models/deck_model.dart';
import '../config/assets_config.dart';

String deckCoverImageUrl() {
  final base = AssetsConfig.assetsBaseUrl;
  return '$base/deck/new-deck.webp';
}

String deckCoverVideoUrl() {
  final base = AssetsConfig.assetsBaseUrl;
  return '$base/deck/cover-video.webm';
}

String cardImageUrl(
  String cardId, {
  DeckType deckId = DeckType.major,
}) {
  final normalizedId = canonicalCardId(cardId);
  final base = AssetsConfig.assetsBaseUrl;
  if (deckId == DeckType.wands ||
      (deckId == DeckType.all && normalizedId.startsWith('wands_'))) {
    return '$base/cards/wands/$normalizedId.webp';
  }
  if (deckId == DeckType.swords ||
      (deckId == DeckType.all && normalizedId.startsWith('swords_'))) {
    return '$base/cards/swords/$normalizedId.webp';
  }
  if (deckId == DeckType.pentacles ||
      (deckId == DeckType.all && normalizedId.startsWith('pentacles_'))) {
    return '$base/cards/pentacles/$normalizedId.webp';
  }
  if (deckId == DeckType.cups ||
      (deckId == DeckType.all && normalizedId.startsWith('cups_'))) {
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

String deckPreviewImageUrl(DeckType deckId) {
  final previewId = switch (deckId) {
    DeckType.major => majorCardIds.first,
    DeckType.wands => wandsCardIds.first,
    DeckType.swords => swordsCardIds.first,
    DeckType.pentacles => pentaclesCardIds.first,
    DeckType.cups => cupsCardIds.first,
    DeckType.all => majorCardIds.first,
  };
  return cardImageUrl(previewId, deckId: deckId);
}

String deckCoverAssetPath(DeckType deckId) {
  switch (deckId) {
    case DeckType.wands:
    case DeckType.swords:
    case DeckType.pentacles:
    case DeckType.cups:
    case DeckType.major:
    case DeckType.all:
    default:
      return deckPreviewImageUrl(deckId);
  }
}

String? videoUrlForCard(String cardId) {
  final normalizedId = canonicalCardId(cardId);
  final base = AssetsConfig.assetsBaseUrl;
  if (normalizedId.startsWith('major_')) {
    final parts = normalizedId.split('_');
    if (parts.length >= 3) {
      var name = parts.sublist(2).join('_');
      if (normalizedId == 'major_10_wheel') {
        name = 'wheel_of_fortune';
      }
      return '$base/video/$name.mp4';
    }
  }
  final parts = normalizedId.split('_');
  if (parts.length >= 3) {
    final suit = parts.first;
    final rank = parts.sublist(2).join('_');
    if (rank == 'king' ||
        rank == 'queen' ||
        rank == 'knight' ||
        rank == 'page') {
      return '$base/video/${suit}_$rank.mp4';
    }
  }
  return null;
}
