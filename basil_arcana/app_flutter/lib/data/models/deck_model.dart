enum DeckId { major, wands }

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

const Map<DeckId, String> deckStorageValues = {
  DeckId.major: 'major',
  DeckId.wands: 'wands',
};

DeckId deckIdFromStorage(String? value) {
  for (final entry in deckStorageValues.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  return DeckId.major;
}
