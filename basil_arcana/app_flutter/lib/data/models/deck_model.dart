enum DeckType { all, major, wands, swords, pentacles, cups, lenormand }

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

const List<String> lenormandCardIds = [
  'lenormand_01_rider',
  'lenormand_02_clover',
  'lenormand_03_ship',
  'lenormand_04_house',
  'lenormand_05_tree',
  'lenormand_06_clouds',
  'lenormand_07_snake',
  'lenormand_08_coffin',
  'lenormand_09_bouquet',
  'lenormand_10_scythe',
  'lenormand_11_whip',
  'lenormand_12_birds',
  'lenormand_13_child',
  'lenormand_14_fox',
  'lenormand_15_bear',
  'lenormand_16_stars',
  'lenormand_17_stork',
  'lenormand_18_dog',
  'lenormand_19_tower',
  'lenormand_20_garden',
  'lenormand_21_mountain',
  'lenormand_22_crossroads',
  'lenormand_23_mice',
  'lenormand_24_heart',
  'lenormand_25_ring',
  'lenormand_26_book',
  'lenormand_27_letter',
  'lenormand_28_man',
  'lenormand_29_woman',
  'lenormand_30_lily',
  'lenormand_31_sun',
  'lenormand_32_moon',
  'lenormand_33_key',
  'lenormand_34_fish',
  'lenormand_35_anchor',
  'lenormand_36_cross',
];

const Map<DeckType, String> deckStorageValues = {
  DeckType.all: 'all',
  DeckType.major: 'major',
  DeckType.wands: 'wands',
  DeckType.swords: 'swords',
  DeckType.pentacles: 'pentacles',
  DeckType.cups: 'cups',
  DeckType.lenormand: 'lenormand',
};

String canonicalCardId(String rawId) {
  var normalized = rawId.toLowerCase().trim();
  normalized = normalized.replaceAll(RegExp(r'\.[a-z0-9]+$'), '');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  normalized = normalized.replaceAll(RegExp(r'_+'), '_');
  normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  return _cardIdAliases[normalized] ?? normalized;
}

DeckType deckIdFromStorage(String? value) {
  for (final entry in deckStorageValues.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  return DeckType.all;
}

DeckType? deckIdFromString(String? value) {
  if (value == null) {
    return null;
  }
  switch (value.trim().toLowerCase()) {
    case 'major':
      return DeckType.major;
    case 'wands':
      return DeckType.wands;
    case 'swords':
      return DeckType.swords;
    case 'pentacles':
      return DeckType.pentacles;
    case 'cups':
      return DeckType.cups;
    case 'all':
      return DeckType.all;
    case 'lenormand':
      return DeckType.lenormand;
  }
  return null;
}

DeckType normalizePrimaryDeckSelection(DeckType deckType) {
  if (deckType == DeckType.lenormand) {
    return DeckType.lenormand;
  }
  return DeckType.all;
}
