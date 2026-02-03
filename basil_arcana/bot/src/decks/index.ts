import fs from "fs/promises";
import path from "path";
import type { Locale } from "../config";
import type { CardData, Spread } from "../state/types";

export interface DecksData {
  cardsByLocale: Record<Locale, Record<string, CardData>>;
  spreadsByLocale: Record<Locale, Spread[]>;
  allCardIds: string[];
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
      const cardsPath = path.join(dataBasePath, `cards_${locale}.json`);
      const spreadsPath = path.join(dataBasePath, `spreads_${locale}.json`);
      const [cardsRaw, spreadsRaw] = await Promise.all([
        fs.readFile(cardsPath, "utf-8"),
        fs.readFile(spreadsPath, "utf-8"),
      ]);
      cardsByLocale[locale] = JSON.parse(cardsRaw) as Record<string, CardData>;
      spreadsByLocale[locale] = JSON.parse(spreadsRaw) as Spread[];
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
