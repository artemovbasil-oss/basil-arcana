import 'deck_model.dart';

const List<String> _videoFileNames = [
  'chariot.mp4',
  'cups_king.mp4',
  'cups_knight.mp4',
  'cups_page.mp4',
  'cups_queen.mp4',
  'death.mp4',
  'devil.mp4',
  'emperor.mp4',
  'empress.mp4',
  'fool.mp4',
  'hanged_man.mp4',
  'hermit.mp4',
  'hierophant.mp4',
  'high_priestess.mp4',
  'judgement.mp4',
  'justice.mp4',
  'lovers.mp4',
  'magician.mp4',
  'moon.mp4',
  'pentacles_king.mp4',
  'pentacles_knight.mp4',
  'pentacles_page.mp4',
  'pentacles_queen.mp4',
  'star.mp4',
  'strength.mp4',
  'sun.mp4',
  'swords_king.mp4',
  'swords_knight.mp4',
  'swords_ace.mp4',
  'swords_eight.mp4',
  'swords_five.mp4',
  'swords_four.mp4',
  'swords_nine.mp4',
  'swords_page.mp4',
  'swords_seven.mp4',
  'swords_six.mp4',
  'swords_ten.mp4',
  'swords_three.mp4',
  'swords_two.mp4',
  'swords_queen.mp4',
  'temperance.mp4',
  'tower.mp4',
  'wands_king.mp4',
  'wands_knight.mp4',
  'wands_page.mp4',
  'wands_queen.mp4',
  'wheel_of_fortune.mp4',
  'world.mp4',
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

final Map<String, String> _videoFilesByKey = {
  for (final file in _videoFileNames)
    _normalizeKey(_stripExtension(file)): normalizeVideoFileName(file),
};

final Map<String, String> _cardVideoFiles = _buildCardVideoFiles();

String? resolveCardVideoFileName(
  String cardId, {
  Set<String>? availableFiles,
}) {
  final normalizedId = canonicalCardId(cardId);
  final lenormandVideo = _lenormandVideoFileForCardId(normalizedId);
  if (lenormandVideo != null) {
    if (availableFiles != null && availableFiles.isNotEmpty) {
      final normalized = lenormandVideo.toLowerCase();
      return availableFiles.contains(normalized) ? lenormandVideo : null;
    }
    return lenormandVideo;
  }
  if (availableFiles != null && availableFiles.isNotEmpty) {
    final fileName = _videoFileFromKey(_videoKeyForCardId(normalizedId));
    if (fileName == null) {
      return null;
    }
    final normalized = normalizeVideoFileName(fileName).toLowerCase();
    final matches = availableFiles.contains(normalized);
    return matches ? fileName : null;
  }
  return _cardVideoFiles[normalizedId];
}

String? resolveCardVideoAsset(
  String cardId, {
  Set<String>? availableAssets,
}) {
  Set<String>? availableFiles;
  if (availableAssets != null && availableAssets.isNotEmpty) {
    availableFiles = availableAssets
        .map((assetPath) => assetPath.split('/').last)
        .map(normalizeVideoFileName)
        .map((fileName) => fileName.toLowerCase())
        .toSet();
  }

  final fileName = resolveCardVideoFileName(
    cardId,
    availableFiles: availableFiles,
  );
  if (fileName == null || fileName.isEmpty) {
    return null;
  }

  final assetPath = 'assets/cards/video/$fileName';
  if (availableAssets != null &&
      availableAssets.isNotEmpty &&
      !availableAssets.contains(assetPath)) {
    return null;
  }
  return assetPath;
}

Map<String, String> _buildCardVideoFiles() {
  final assets = <String, String>{};
  for (final entry in _majorVideoKeys.entries) {
    final fileName = _videoFilesByKey[_normalizeKey(entry.value)];
    if (fileName != null) {
      assets[entry.key] = fileName;
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
    final fileName = _videoFilesByKey[_normalizeKey(key)];
    if (fileName != null) {
      assets[cardId] = fileName;
    }
  }
  return assets;
}

String? _videoKeyForCardId(String cardId) {
  final normalizedId = canonicalCardId(cardId);
  if (normalizedId.startsWith('major_')) {
    return _majorVideoKeys[normalizedId];
  }
  final parts = normalizedId.split('_');
  if (parts.length < 3) {
    return null;
  }
  final suit = parts.first;
  final rank = parts.sublist(2).join('_');
  return '${suit}_$rank';
}

String? _videoFileFromKey(String? key) {
  if (key == null) {
    return null;
  }
  return _videoFilesByKey[_normalizeKey(key)];
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

String normalizeVideoFileName(String name) {
  var normalized = name.toLowerCase().trim();
  normalized = normalized.replaceAll(RegExp(r'\s+'), '_');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_\\.]+'), '');
  normalized = normalized.replaceAll(RegExp(r'_+'), '_');
  normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  if (!normalized.endsWith('.mp4')) {
    normalized = _stripExtension(normalized);
    normalized = '$normalized.mp4';
  }
  return normalized;
}

String? _lenormandVideoFileForCardId(String normalizedId) {
  if (!normalizedId.startsWith('lenormand_')) {
    return null;
  }
  final parts = normalizedId.split('_');
  if (parts.length < 3) {
    return null;
  }
  final slug = parts.sublist(2).join('_');
  return 'ln_$slug.mp4';
}
