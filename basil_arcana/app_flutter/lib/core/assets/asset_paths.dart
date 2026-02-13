import '../../data/models/card_video.dart';
import '../../data/models/deck_model.dart';
import '../config/app_config.dart';
import '../config/assets_config.dart';

String deckCoverImageUrl([DeckType deckId = DeckType.all]) {
  final base = AssetsConfig.assetsBaseUrl;
  if (deckId == DeckType.lenormand) {
    return '$base/deck/lenormand.webp';
  }
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
  if (deckId == DeckType.lenormand ||
      (deckId == DeckType.all && normalizedId.startsWith('lenormand_'))) {
    final fileName = _lenormandFileStem(normalizedId);
    return '$base/cards/lenormand/$fileName.webp';
  }
  switch (normalizedId) {
    case 'major_10_wheel':
      return '$base/cards/major/major_10_wheel_of_fortune.webp';
    default:
      return '$base/cards/major/$normalizedId.webp';
  }
}

String _lenormandFileStem(String normalizedCardId) {
  if (normalizedCardId.startsWith('ln_')) {
    return normalizedCardId;
  }
  if (!normalizedCardId.startsWith('lenormand_')) {
    return normalizedCardId;
  }
  final parts = normalizedCardId.split('_');
  if (parts.length < 3) {
    return normalizedCardId;
  }
  final slug = parts.sublist(2).join('_');
  return 'ln_$slug';
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
  return _appendCacheBust('$base/data/spreads_${lang}.json');
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
  return _appendCacheBust('$base/data/cards_${lang}.json');
}

String deckPreviewImageUrl(DeckType deckId) {
  final previewId = switch (deckId) {
    DeckType.major => majorCardIds.first,
    DeckType.wands => wandsCardIds.first,
    DeckType.swords => swordsCardIds.first,
    DeckType.pentacles => pentaclesCardIds.first,
    DeckType.cups => cupsCardIds.first,
    DeckType.lenormand => lenormandCardIds.first,
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
    case DeckType.lenormand:
    case DeckType.major:
    case DeckType.all:
    default:
      return deckPreviewImageUrl(deckId);
  }
}

String? videoUrlForCard(String cardId) {
  final base = AssetsConfig.assetsBaseUrl;
  final fileName = resolveCardVideoFileName(cardId);
  if (fileName == null || fileName.isEmpty) {
    return null;
  }
  return '$base/video/$fileName';
}

String _appendCacheBust(String url) {
  final version = AppConfig.appVersion.trim().isNotEmpty
      ? AppConfig.appVersion.trim()
      : 'dev';
  final uri = Uri.parse(url);
  final params = Map<String, String>.from(uri.queryParameters);
  params['v'] = version;
  return uri.replace(queryParameters: params).toString();
}
