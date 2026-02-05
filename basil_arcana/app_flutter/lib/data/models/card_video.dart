import 'dart:convert';

import 'package:flutter/services.dart';

import 'deck_model.dart';

const List<String> _videoFileNames = [
  'pentacles_queen.mp4',
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
  'star.mp4',
  'strength.mp4',
  'sun.mp4',
  'swords_king.mp4',
  'swords_knight.mp4',
  'swords_page.mp4',
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

final Map<String, String> _videoAssetsByKey = {
  for (final file in _videoFileNames)
    _normalizeKey(_stripExtension(file)): 'assets/cards/video/${normalizeVideoFileName(file)}',
};

final Map<String, String> _cardVideoAssets = _buildCardVideoAssets();
Set<String>? _videoAssetManifestCache;
Future<Set<String>>? _videoAssetManifestFuture;

String? resolveCardVideoAsset(
  String cardId, {
  Set<String>? availableAssets,
}) {
  final normalizedId = canonicalCardId(cardId);
  if (availableAssets != null && availableAssets.isNotEmpty) {
    final asset = normalizeVideoAssetPath(
      _videoAssetFromKey(_videoKeyForCardId(normalizedId)),
    );
    if (asset == null) {
      return null;
    }
    final assetLower = asset.toLowerCase();
    final matches = availableAssets.any(
      (value) => value.toLowerCase() == assetLower,
    );
    return matches ? asset : null;
  }
  return _cardVideoAssets[normalizedId];
}

String? normalizeVideoAssetPath(String? path) {
  if (path == null || path.trim().isEmpty) {
    return null;
  }
  final normalized = path.trim();
  if (!normalized.contains('/')) {
    return 'assets/cards/video/${normalizeVideoFileName(normalized)}';
  }
  final parts = normalized.split('/');
  final fileName = parts.removeLast();
  parts.add(normalizeVideoFileName(fileName));
  return parts.join('/');
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

String? _videoAssetFromKey(String? key) {
  if (key == null) {
    return null;
  }
  final fileName = normalizeVideoFileName(key);
  return 'assets/cards/video/$fileName';
}

Future<Set<String>> loadVideoAssetManifest() {
  final cached = _videoAssetManifestCache;
  if (cached != null) {
    return Future.value(cached);
  }
  final future = _videoAssetManifestFuture;
  if (future != null) {
    return future;
  }
  _videoAssetManifestFuture = rootBundle.loadString('AssetManifest.json').then(
    (raw) {
      final manifest = jsonDecode(raw) as Map<String, dynamic>;
      final assets = manifest.keys
          .where((path) => path.contains('assets/cards/video/'))
          .map((path) => normalizeVideoAssetPath(path))
          .whereType<String>()
          .toSet();
      _videoAssetManifestCache = assets;
      return assets;
    },
  );
  return _videoAssetManifestFuture!;
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
