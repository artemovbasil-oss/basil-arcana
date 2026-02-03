import { existsSync } from "fs";
import fs from "fs/promises";
import path from "path";
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
  imagePath: string;
  displayName: string;
}

function resolveRepoRoot(): string {
  const cwd = process.cwd();
  if (existsSync(path.join(cwd, "app_flutter"))) {
    return cwd;
  }
  return path.resolve(cwd, "..");
}

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

async function collectCards(
  directory: string,
  deckId: DeckCardInfo["deckId"]
): Promise<DeckCardInfo[]> {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".webp"))
    .map((entry) => {
      const id = path.basename(entry.name, ".webp");
      return {
        id,
        deckId,
        imagePath: path.join(directory, entry.name),
        displayName: humanizeCardId(id, deckId),
      };
    });
}

export async function loadDecks(_dataBasePath: string): Promise<DecksData> {
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

  const repoRoot = resolveRepoRoot();
  const cardsRoot = path.join(repoRoot, "app_flutter", "assets", "cards");
  const [majorCards, wandsCards] = await Promise.all([
    collectCards(path.join(cardsRoot, "major"), "major"),
    collectCards(path.join(cardsRoot, "wands"), "wands"),
  ]);
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
