enum DeckId { all, major, wands, swords, pentacles, cups }

const Map<String, String> _cardIdAliases = {
  'major_10_wheel_of_fortune': 'major_10_wheel',
  'cups_13_king': 'cups_01_king',
  'cups_12_queen': 'cups_02_queen',
  'cups_11_page': 'cups_03_page',
  'cups_10_knight': 'cups_00_knight',
};

const List<String> majorCardIds = [
  'major_00_fool',
  'major_01_magician',
  'major_02_high_priestess',
  'major_03_empress',
  'major_04_emperor',
  'major_05_hierophant',
  'major_06_lovers',
  'major_07_chariot',
  'major_08_strength',
  'major_09_hermit',
  'major_10_wheel',
  'major_11_justice',
  'major_12_hanged_man',
  'major_13_death',
  'major_14_temperance',
  'major_15_devil',
  'major_16_tower',
  'major_17_star',
  'major_18_moon',
  'major_19_sun',
  'major_20_judgement',
  'major_21_world',
];

const List<String> wandsCardIds = [
  'wands_00_knight',
  'wands_01_king',
  'wands_02_queen',
  'wands_03_page',
  'wands_04_two',
  'wands_05_three',
  'wands_06_four',
  'wands_07_five',
  'wands_08_six',
  'wands_09_seven',
  'wands_10_eight',
  'wands_11_nine',
  'wands_12_ten',
  'wands_13_ace',
];

const List<String> swordsCardIds = [
  'swords_00_knight',
  'swords_01_king',
  'swords_02_queen',
  'swords_03_page',
  'swords_04_two',
  'swords_05_three',
  'swords_06_four',
  'swords_07_five',
  'swords_08_six',
  'swords_09_seven',
  'swords_10_eight',
  'swords_11_nine',
  'swords_12_ten',
  'swords_13_ace',
];

const List<String> pentaclesCardIds = [
  'pentacles_00_knight',
  'pentacles_01_king',
  'pentacles_02_queen',
  'pentacles_03_page',
  'pentacles_04_two',
  'pentacles_05_three',
  'pentacles_06_four',
  'pentacles_07_five',
  'pentacles_08_six',
  'pentacles_09_seven',
  'pentacles_10_eight',
  'pentacles_11_nine',
  'pentacles_12_ten',
  'pentacles_13_ace',
];

const List<String> cupsCardIds = [
  'cups_00_knight',
  'cups_01_king',
  'cups_02_queen',
  'cups_03_page',
  'cups_04_two',
  'cups_05_three',
  'cups_06_four',
  'cups_07_five',
  'cups_08_six',
  'cups_09_seven',
  'cups_10_eight',
  'cups_11_nine',
  'cups_12_ten',
  'cups_13_ace',
];

const Map<DeckId, String> deckStorageValues = {
  DeckId.all: 'all',
  DeckId.major: 'major',
  DeckId.wands: 'wands',
  DeckId.swords: 'swords',
  DeckId.pentacles: 'pentacles',
  DeckId.cups: 'cups',
};

String canonicalCardId(String rawId) {
  var normalized = rawId.toLowerCase().trim();
  normalized = normalized.replaceAll(RegExp(r'\.[a-z0-9]+$'), '');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  normalized = normalized.replaceAll(RegExp(r'_+'), '_');
  normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  return _cardIdAliases[normalized] ?? normalized;
}

DeckId deckIdFromStorage(String? value) {
  for (final entry in deckStorageValues.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  return DeckId.all;
}
