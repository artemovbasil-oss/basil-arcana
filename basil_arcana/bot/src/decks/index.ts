import type { Locale } from "../config";
import type { CardData, Spread } from "../state/types";

export interface DecksData {
  cardsByLocale: Record<Locale, Record<string, CardData>>;
  spreadsByLocale: Record<Locale, Spread[]>;
  allCardIds: string[];
}

interface DeckCardInfo {
  id: string;
  deckId: "major" | "wands";
  displayName: string;
}

const MAJOR_CARD_IDS = [
  "major_00_fool",
  "major_01_magician",
  "major_02_high_priestess",
  "major_03_empress",
  "major_04_emperor",
  "major_05_hierophant",
  "major_06_lovers",
  "major_07_chariot",
  "major_08_strength",
  "major_09_hermit",
  "major_10_wheel_of_fortune",
  "major_11_justice",
  "major_12_hanged_man",
  "major_13_death",
  "major_14_temperance",
  "major_15_devil",
  "major_16_tower",
  "major_17_star",
  "major_18_moon",
  "major_19_sun",
  "major_20_judgement",
  "major_21_world",
];

const WANDS_CARD_IDS = Array.from({ length: 14 }, (_, index) =>
  `wands_${String(index + 1).padStart(2, "0")}`
);

function humanizeCardId(cardId: string, deckId: string): string {
  const withoutPrefix = cardId.startsWith(`${deckId}_`)
    ? cardId.slice(deckId.length + 1)
    : cardId;
  return withoutPrefix
    .split("_")
    .filter(Boolean)
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(" ");
}

function buildDeck(deckId: DeckCardInfo["deckId"], cardIds: string[]): DeckCardInfo[] {
  return cardIds.map((id) => ({
    id,
    deckId,
    displayName: humanizeCardId(id, deckId),
  }));
}

export async function loadDecks(): Promise<DecksData> {
  const locales: Locale[] = ["en", "ru", "kk"];
  const cardsByLocale: DecksData["cardsByLocale"] = {
    en: {},
    ru: {},
    kk: {},
  };
  const spreadsByLocale: DecksData["spreadsByLocale"] = {
    en: [],
    ru: [],
    kk: [],
  };

  const majorCards = buildDeck("major", MAJOR_CARD_IDS);
  const wandsCards = buildDeck("wands", WANDS_CARD_IDS);
  const allCards = [...majorCards, ...wandsCards];
  const cardRecords = allCards.reduce<Record<string, CardData>>(
    (acc, card) => {
      acc[card.id] = {
        title: card.displayName,
        keywords: [],
        meaning: {
          general: "",
          light: "",
          shadow: "",
          advice: "",
        },
      };
      return acc;
    },
    {}
  );

  const spreads: Spread[] = [
    {
      id: "spread_1_focus",
      name: "Focus",
      positions: [{ id: "p1", title: "Focus" }],
    },
    {
      id: "spread_3",
      name: "Three Card",
      positions: [
        { id: "left", title: "Left" },
        { id: "center", title: "Center" },
        { id: "right", title: "Right" },
      ],
    },
  ];

  locales.forEach((locale) => {
    cardsByLocale[locale] = { ...cardRecords };
    spreadsByLocale[locale] = spreads;
  });

  const allCardIds = allCards.map((card) => card.id).sort();

  return { cardsByLocale, spreadsByLocale, allCardIds };
}

export function pickSpread(
  spreads: Spread[],
  spreadId: "one" | "three"
): Spread {
  if (spreadId === "one") {
    return spreads[0];
  }
  return spreads[1] || spreads[0];
}

export function drawCards(cardIds: string[], count: number): string[] {
  const remaining = [...cardIds];
  const selected: string[] = [];
  while (selected.length < count && remaining.length > 0) {
    const index = Math.floor(Math.random() * remaining.length);
    selected.push(remaining.splice(index, 1)[0]);
  }
  return selected;
}
