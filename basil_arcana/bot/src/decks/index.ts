import fs from "fs/promises";
import path from "path";
import type { Locale } from "../config";
import type { CardData, Spread } from "../state/types";

export interface DecksData {
  cardsByLocale: Record<Locale, Record<string, CardData>>;
  spreadsByLocale: Record<Locale, Spread[]>;
  allCardIds: string[];
}

async function readJsonFile<T>(filePath: string): Promise<T> {
  try {
    await fs.access(filePath);
  } catch (error) {
    throw new Error(
      `Missing deck data file at ${filePath}. cwd=${process.cwd()}`
    );
  }

  const raw = await fs.readFile(filePath, "utf-8");
  return JSON.parse(raw) as T;
}

export async function loadDecks(dataBasePath: string): Promise<DecksData> {
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

  await Promise.all(
    locales.map(async (locale) => {
      const cardsPath = path.resolve(dataBasePath, `cards_${locale}.json`);
      const spreadsPath = path.resolve(dataBasePath, `spreads_${locale}.json`);
      const [cards, spreads] = await Promise.all([
        readJsonFile<Record<string, CardData>>(cardsPath),
        readJsonFile<Spread[]>(spreadsPath),
      ]);
      cardsByLocale[locale] = cards;
      spreadsByLocale[locale] = spreads;
    })
  );

  const allCardIds = Object.keys(cardsByLocale.en);

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
