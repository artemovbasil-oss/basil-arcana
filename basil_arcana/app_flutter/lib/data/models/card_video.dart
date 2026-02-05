import 'deck_model.dart';

const List<String> _videoFileNames = [
  'Pentacles_queen.MP4',
  'chariot.MP4',
  'cups_king.MP4',
  'cups_knight.MP4',
  'cups_page.MP4',
  'cups_queen.MP4',
  'death.MP4',
  'devil.MP4',
  'emperor.MP4',
  'empress.MP4',
  'fool.MP4',
  'hanged man.MP4',
  'hermit.MP4',
  'hierophant.MP4',
  'high_priestess.MP4',
  'judgement.MP4',
  'justice.MP4',
  'lovers.MP4',
  'magician.MP4',
  'moon.MP4',
  'pentacles_king.MP4',
  'pentacles_knight.MP4',
  'pentacles_page.MP4',
  'star.MP4',
  'strength.MP4',
  'sun.MP4',
  'swords_king.MP4',
  'swords_knight.MP4',
  'swords_page.MP4',
  'swords_queen.MP4',
  'temperance.MP4',
  'tower.MP4',
  'wands_king.MP4',
  'wands_knight.MP4',
  'wands_page.MP4',
  'wands_queen.MP4',
  'wheel_of fortune.MP4',
  'world.MP4',
];

const Map<String, String> _majorVideoKeys = {
  'major_00_fool': 'fool',
  'major_01_magician': 'magician',
  'major_02_high_priestess': 'high_priestess',
  'major_03_empress': 'empress',
  'major_04_emperor': 'emperor',
  'major_05_hierophant': 'hierophant',
  'major_06_lovers': 'lovers',
  'major_07_chariot': 'chariot',
  'major_08_strength': 'strength',
  'major_09_hermit': 'hermit',
  'major_10_wheel': 'wheel_of_fortune',
  'major_11_justice': 'justice',
  'major_12_hanged_man': 'hanged_man',
  'major_13_death': 'death',
  'major_14_temperance': 'temperance',
  'major_15_devil': 'devil',
  'major_16_tower': 'tower',
  'major_17_star': 'star',
  'major_18_moon': 'moon',
  'major_19_sun': 'sun',
  'major_20_judgement': 'judgement',
  'major_21_world': 'world',
};

final Map<String, String> _videoAssetsByKey = {
  for (final file in _videoFileNames)
    _normalizeKey(_stripExtension(file)): 'assets/cards/video/$file',
};

final Map<String, String> _cardVideoAssets = _buildCardVideoAssets();

String? resolveCardVideoAsset(String cardId) {
  return _cardVideoAssets[cardId];
}

Map<String, String> _buildCardVideoAssets() {
  final assets = <String, String>{};
  for (final entry in _majorVideoKeys.entries) {
    final asset = _videoAssetsByKey[_normalizeKey(entry.value)];
    if (asset != null) {
      assets[entry.key] = asset;
    }
  }
  final minorIds = <String>[
    ...wandsCardIds,
    ...swordsCardIds,
    ...pentaclesCardIds,
    ...cupsCardIds,
  ];
  for (final cardId in minorIds) {
    final key = _videoKeyForCardId(cardId);
    if (key == null) {
      continue;
    }
    final asset = _videoAssetsByKey[_normalizeKey(key)];
    if (asset != null) {
      assets[cardId] = asset;
    }
  }
  return assets;
}

String? _videoKeyForCardId(String cardId) {
  if (cardId.startsWith('major_')) {
    return _majorVideoKeys[cardId];
  }
  final parts = cardId.split('_');
  if (parts.length < 3) {
    return null;
  }
  final suit = parts.first;
  final rank = parts.sublist(2).join('_');
  return '${suit}_$rank';
}

String _stripExtension(String filename) {
  return filename.replaceFirst(RegExp(r'\.mp4$', caseSensitive: false), '');
}

String _normalizeKey(String value) {
  var normalized = value.toLowerCase().trim();
  normalized = normalized.replaceAll(RegExp(r'\s+'), '_');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  normalized = normalized.replaceAll(RegExp(r'_+'), '_');
  normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized;
}
