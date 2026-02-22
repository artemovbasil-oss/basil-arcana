import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all cards include full detail fields for every locale', () {
    const files = [
      '../cdn/data/cards_en.json',
      '../cdn/data/cards_ru.json',
      '../cdn/data/cards_kz.json',
    ];

    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final data = jsonDecode(contents);
      final entries = _coerceEntries(data);
      final invalid = entries.where((entry) {
        final title =
            ((entry['title'] as String?) ?? (entry['name'] as String?) ?? '')
                .trim();
        final description = (entry['description'] as String? ?? '').trim();
        final detailed = (entry['detailedDescription'] as String? ?? '').trim();
        final fact =
            ((entry['fact'] as String?) ?? (entry['funFact'] as String?) ?? '')
                .trim();
        final keywords = entry['keywords'];
        final stats = entry['stats'];
        final hasKeywords = keywords is List && keywords.isNotEmpty;
        final hasStats = stats is Map &&
            stats['luck'] is num &&
            stats['power'] is num &&
            stats['love'] is num &&
            stats['clarity'] is num;
        return title.isEmpty ||
            description.isEmpty ||
            detailed.isEmpty ||
            fact.isEmpty ||
            !hasKeywords ||
            !hasStats;
      });
      expect(
        invalid,
        isEmpty,
        reason: 'Missing core detail fields in $file.',
      );
    }
  });

  test('all cards include detailedDescription for every locale', () {
    const files = [
      '../cdn/data/cards_en.json',
      '../cdn/data/cards_ru.json',
      '../cdn/data/cards_kz.json',
    ];

    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final data = jsonDecode(contents);
      final entries = _coerceEntries(data);
      final missing = entries.where((entry) {
        final detailed = entry['detailedDescription'] as String?;
        return detailed == null || detailed.trim().isEmpty;
      });
      expect(
        missing,
        isEmpty,
        reason: 'Missing detailedDescription entries in $file.',
      );
    }
  });

  test('cups deck contains 14 cards per locale', () {
    const files = [
      '../cdn/data/cards_en.json',
      '../cdn/data/cards_ru.json',
      '../cdn/data/cards_kz.json',
    ];

    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final data = jsonDecode(contents);
      final entries = _coerceEntries(data);
      final cups = entries.where((entry) {
        final deck = entry['deck'] as String?;
        final id = entry['id'] as String? ?? '';
        return deck == 'cups' || id.startsWith('cups_');
      });
      expect(cups.length, 14, reason: 'Expected 14 cups cards in $file.');
    }
  });

  test('lenormand deck contains 36 cards per locale', () {
    const files = [
      '../cdn/data/cards_en.json',
      '../cdn/data/cards_ru.json',
      '../cdn/data/cards_kz.json',
    ];

    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final data = jsonDecode(contents);
      final entries = _coerceEntries(data);
      final lenormand = entries.where((entry) {
        final deck = entry['deck'] as String?;
        final id = entry['id'] as String? ?? '';
        return deck == 'lenormand' || id.startsWith('lenormand_');
      });
      expect(
        lenormand.length,
        36,
        reason: 'Expected 36 lenormand cards in $file.',
      );
    }
  });

  test('crowley deck contains 78 cards per locale', () {
    const files = [
      '../cdn/data/cards_en.json',
      '../cdn/data/cards_ru.json',
      '../cdn/data/cards_kz.json',
    ];

    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final data = jsonDecode(contents);
      final entries = _coerceEntries(data);
      final crowley = entries.where((entry) {
        final deck = entry['deck'] as String?;
        final id = entry['id'] as String? ?? '';
        return deck == 'crowley' || id.startsWith('ac_');
      });
      expect(
        crowley.length,
        78,
        reason: 'Expected 78 crowley cards in $file.',
      );
    }
  });
}

List<Map<String, dynamic>> _coerceEntries(Object? payload) {
  if (payload is List<dynamic>) {
    return payload.whereType<Map<String, dynamic>>().toList();
  }
  if (payload is Map<String, dynamic>) {
    return payload.entries
        .where((entry) => entry.value is Map<String, dynamic>)
        .map((entry) {
      final value = Map<String, dynamic>.from(
        entry.value as Map<String, dynamic>,
      );
      value['id'] ??= entry.key;
      return value;
    }).toList();
  }
  return [];
}
