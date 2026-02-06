import 'dart:convert';
import 'dart:io';

class SpreadDefinition {
  SpreadDefinition({
    required this.id,
    required this.names,
    required this.descriptions,
    required this.positions,
  });

  final String id;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  final List<PositionDefinition> positions;
}

class PositionDefinition {
  PositionDefinition({
    required this.id,
    required this.titles,
  });

  final String id;
  final Map<String, String> titles;
}

final List<SpreadDefinition> canonicalSpreads = [
  SpreadDefinition(
    id: 'spread_1_focus',
    names: const {
      'en': 'Focus / Advice',
      'ru': 'Фокус / Совет',
      'kk': 'Назар / Кеңес',
    },
    descriptions: const {
      'en': 'A single card spotlights the core theme and the most helpful advice.',
      'ru': 'Одна карта показывает главный фокус и самый полезный совет.',
      'kk': 'Бір карта негізгі назарды және ең пайдалы кеңесті көрсетеді.',
    },
    positions: [
      PositionDefinition(
        id: 'p1',
        titles: const {
          'en': 'Focus / Advice',
          'ru': 'Фокус / Совет',
          'kk': 'Назар / Кеңес',
        },
      ),
    ],
  ),
  SpreadDefinition(
    id: 'spread_3_situation_challenge_step',
    names: const {
      'en': 'Situation / Challenge / Next Step',
      'ru': 'Ситуация / Вызов / Следующий шаг',
      'kk': 'Жағдай / Қиындық / Келесі қадам',
    },
    descriptions: const {
      'en': 'Three cards map what is happening, what complicates it, and the best next move.',
      'ru': 'Три карты показывают ситуацию, основную трудность и лучший следующий шаг.',
      'kk': 'Үш карта жағдайды, негізгі қиындықты және ең жақсы келесі қадамды көрсетеді.',
    },
    positions: [
      PositionDefinition(
        id: 'p1',
        titles: const {
          'en': 'Situation',
          'ru': 'Ситуация',
          'kk': 'Жағдай',
        },
      ),
      PositionDefinition(
        id: 'p2',
        titles: const {
          'en': 'Challenge',
          'ru': 'Вызов',
          'kk': 'Қиындық',
        },
      ),
      PositionDefinition(
        id: 'p3',
        titles: const {
          'en': 'Next Step',
          'ru': 'Следующий шаг',
          'kk': 'Келесі қадам',
        },
      ),
    ],
  ),
];

void main(List<String> args) async {
  final locales = ['en', 'ru', 'kk'];
  final outputDirs = _resolveOutputDirs();

  for (final locale in locales) {
    final spreads = _buildLocalizedSpreads(locale);
    _validateSpreads(spreads, locale);
    final jsonString = const JsonEncoder.withIndent('  ').convert(spreads);
    for (final dir in outputDirs) {
      final file = File('${dir.path}/spreads_$locale.json');
      await file.writeAsString(jsonString, encoding: utf8);
      stdout.writeln(
        'Wrote ${spreads.length} spreads to ${file.path}',
      );
    }
  }
}

List<Directory> _resolveOutputDirs() {
  final candidates = [
    Directory('app_flutter/assets/data'),
    Directory('app_flutter/web/assets/data'),
    Directory('app_flutter/build/web/assets/data'),
  ];
  final output = <Directory>[];
  for (final dir in candidates) {
    if (dir.existsSync()) {
      output.add(dir);
    }
  }
  if (output.isEmpty) {
    throw StateError('No assets/data directories found.');
  }
  return output;
}

List<Map<String, Object?>> _buildLocalizedSpreads(String locale) {
  return canonicalSpreads
      .map(
        (spread) => <String, Object?>{
          'id': spread.id,
          'name': spread.names[locale] ?? '',
          'description': spread.descriptions[locale] ?? '',
          'positions': spread.positions
              .map(
                (position) => <String, Object?>{
                  'id': position.id,
                  'title': position.titles[locale] ?? '',
                },
              )
              .toList(),
        },
      )
      .toList();
}

void _validateSpreads(List<Map<String, Object?>> spreads, String locale) {
  if (spreads.isEmpty) {
    throw StateError('No spreads defined for locale $locale.');
  }
  final ids = <String>{};
  for (final spread in spreads) {
    final id = spread['id'];
    final name = spread['name'];
    final description = spread['description'];
    final positions = spread['positions'];
    if (id is! String || id.trim().isEmpty) {
      throw StateError('Spread id missing for locale $locale.');
    }
    if (!ids.add(id)) {
      throw StateError('Duplicate spread id "$id" for locale $locale.');
    }
    if (name is! String || name.trim().isEmpty) {
      throw StateError('Spread "$id" name missing for locale $locale.');
    }
    if (description is! String || description.trim().isEmpty) {
      throw StateError('Spread "$id" description missing for locale $locale.');
    }
    if (positions is! List || positions.isEmpty) {
      throw StateError('Spread "$id" positions missing for locale $locale.');
    }
    final positionIds = <String>{};
    for (final entry in positions) {
      if (entry is! Map<String, Object?>) {
        throw StateError('Spread "$id" has invalid position for locale $locale.');
      }
      final positionId = entry['id'];
      final title = entry['title'];
      if (positionId is! String || positionId.trim().isEmpty) {
        throw StateError('Spread "$id" has position without id for $locale.');
      }
      if (!positionIds.add(positionId)) {
        throw StateError('Spread "$id" has duplicate position id "$positionId".');
      }
      if (title is! String || title.trim().isEmpty) {
        throw StateError('Spread "$id" position "$positionId" title missing.');
      }
    }
  }
}
