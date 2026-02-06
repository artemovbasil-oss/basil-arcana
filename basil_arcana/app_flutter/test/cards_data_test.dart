import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all cards include detailedDescription for every locale', () {
    const files = [
      '../cdn/data/cards_en.json',
      '../cdn/data/cards_ru.json',
      '../cdn/data/cards_kz.json',
    ];

    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      final missing = data.entries.where((entry) {
        final value = entry.value as Map<String, dynamic>;
        final detailed = value['detailedDescription'] as String?;
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
      final data = jsonDecode(contents) as Map<String, dynamic>;
      final cups = data.keys.where((key) => key.startsWith('cups_')).toList();
      expect(cups.length, 14, reason: 'Expected 14 cups cards in $file.');
    }
  });
}
