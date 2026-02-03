import { existsSync, readdirSync } from "fs";
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

let hasLoggedAssetPaths = false;

function resolveFlutterAssetsRoot(): string {
  const cwd = process.cwd();
  const candidates = [
    path.join(cwd, "app_flutter", "assets"),
    path.join(cwd, "basil_arcana", "app_flutter", "assets"),
    path.join(cwd, "..", "app_flutter", "assets"),
    path.join(cwd, "..", "basil_arcana", "app_flutter", "assets"),
  ];

  for (const candidate of candidates) {
    if (existsSync(path.join(candidate, "cards"))) {
      return candidate;
    }
  }

  console.error(`[decks] Unable to locate Flutter assets root. cwd=${cwd}`);
  try {
    const entries = readdirSync(cwd);
    console.error(`[decks] cwd entries: ${entries.join(", ")}`);
  } catch (error) {
    console.error(`[decks] Failed to read cwd entries: ${error}`);
  }

  throw new Error(
    `Unable to locate Flutter assets root. cwd=${cwd} attempted=${candidates.join(
      ", "
    )}`
  );
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

  const flutterAssetsRoot = resolveFlutterAssetsRoot();
  const majorDir = path.join(flutterAssetsRoot, "cards", "major");
  const wandsDir = path.join(flutterAssetsRoot, "cards", "wands");
  const fallbackCover = path.join(flutterAssetsRoot, "deck", "cover.webp");

  if (!hasLoggedAssetPaths) {
    hasLoggedAssetPaths = true;
    console.info(
      `[decks] assetsRoot=${flutterAssetsRoot} majorExists=${existsSync(
        majorDir
      )} wandsExists=${existsSync(wandsDir)} cwd=${process.cwd()}`
    );
  }

  const deckPromises: Array<Promise<DeckCardInfo[]>> = [];
  if (existsSync(majorDir)) {
    deckPromises.push(collectCards(majorDir, "major"));
  } else {
    console.warn(
      `[decks] Major arcana directory missing at ${majorDir}; skipping major deck.`
    );
    deckPromises.push(Promise.resolve([]));
  }
  if (existsSync(wandsDir)) {
    deckPromises.push(collectCards(wandsDir, "wands"));
  } else {
    console.warn(
      `[decks] Wands directory missing at ${wandsDir}; skipping wands deck.`
    );
    deckPromises.push(Promise.resolve([]));
  }

  void fallbackCover;

  const [majorCards, wandsCards] = await Promise.all(deckPromises);
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
