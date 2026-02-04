enum DeckId { all, major, wands, cups }

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
  DeckId.cups: 'cups',
};

DeckId deckIdFromStorage(String? value) {
  for (final entry in deckStorageValues.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  return DeckId.all;
}
