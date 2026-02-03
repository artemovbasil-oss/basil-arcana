import fs from "fs";
import path from "path";

type CardImageResolverInput = {
  deckId?: string;
  cardId?: string;
  imagePath?: string;
  filename?: string;
  locale?: string;
};

const cardImageMapCache = new Map<string, Map<string, string>>();

const SUPPORTED_DECKS = ["major", "wands"] as const;

type SupportedDeck = (typeof SUPPORTED_DECKS)[number];

export function resolveBotAssetsRoot(): string {
  const envRoot =
    process.env.BOT_ASSETS_ROOT?.trim() ||
    process.env.ASSETS_BASE_PATH?.trim();
  if (envRoot) {
    return path.resolve(envRoot);
  }
  return path.resolve(__dirname, "..", "assets");
}

export function localAssetsAvailable(assetsBasePath: string): boolean {
  return fs.existsSync(path.join(assetsBasePath, "cards"));
}

export function logAssetsSummary(assetsBasePath: string): void {
  const deckFolders = listDeckFolders(assetsBasePath);
  const display = deckFolders.length > 0 ? deckFolders.join(", ") : "none";
  console.log(
    `Assets root resolved to ${assetsBasePath}. Deck folders found: ${display}.`
  );
}

function listDeckFolders(assetsBasePath: string): string[] {
  const cardRoot = path.join(assetsBasePath, "cards");
  return SUPPORTED_DECKS.filter((deck) =>
    fs.existsSync(path.join(cardRoot, deck))
  );
}

function buildCardImageMap(assetsBasePath: string): Map<string, string> {
  const map = new Map<string, string>();
  const cardRoot = path.join(assetsBasePath, "cards");

  for (const deck of SUPPORTED_DECKS) {
    const deckDir = path.join(cardRoot, deck);
    if (!fs.existsSync(deckDir)) {
      continue;
    }
    const entries = fs.readdirSync(deckDir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isFile()) {
        continue;
      }
      const ext = path.extname(entry.name);
      if (ext !== ".webp") {
        continue;
      }
      const baseName = path.basename(entry.name, ext);
      map.set(baseName, path.join(deckDir, entry.name));
    }
  }

  return map;
}

function getCardImageMap(assetsBasePath: string): Map<string, string> {
  const existing = cardImageMapCache.get(assetsBasePath);
  if (existing) {
    return existing;
  }
  const built = buildCardImageMap(assetsBasePath);
  cardImageMapCache.set(assetsBasePath, built);
  return built;
}

function stripExtension(value: string): string {
  return path.basename(value, path.extname(value));
}

function inferDeckId(value: string): SupportedDeck | undefined {
  if (value.startsWith("major_")) {
    return "major";
  }
  if (value.startsWith("wands_")) {
    return "wands";
  }
  return undefined;
}

export function resolveCardImagePath(
  input: CardImageResolverInput,
  assetsBasePath: string
): string | null {
  const map = getCardImageMap(assetsBasePath);

  if (input.imagePath) {
    const resolved = path.isAbsolute(input.imagePath)
      ? input.imagePath
      : path.resolve(assetsBasePath, input.imagePath);
    if (fs.existsSync(resolved)) {
      return resolved;
    }
  }

  const baseName = input.cardId
    ? stripExtension(input.cardId)
    : input.filename
    ? stripExtension(input.filename)
    : input.imagePath
    ? stripExtension(input.imagePath)
    : undefined;

  if (!baseName) {
    return null;
  }

  const exact = map.get(baseName);
  if (exact) {
    return exact;
  }

  const inferredDeck = input.deckId || inferDeckId(baseName);
  if (inferredDeck && !baseName.startsWith(`${inferredDeck}_`)) {
    const prefixed = map.get(`${inferredDeck}_${baseName}`);
    if (prefixed) {
      return prefixed;
    }
  }

  const prefix = baseName.endsWith("_") ? baseName : `${baseName}_`;
  const matches = [...map.entries()].filter(([key]) => key.startsWith(prefix));
  if (matches.length === 1) {
    return matches[0][1];
  }

  if (matches.length > 1 && inferredDeck) {
    const deckPrefix = `${inferredDeck}_`;
    const deckMatches = matches.filter(([key]) => key.startsWith(deckPrefix));
    if (deckMatches.length === 1) {
      return deckMatches[0][1];
    }
  }

  if (inferredDeck) {
    const deckPrefix = `${inferredDeck}_${baseName}_`;
    const deckMatches = [...map.entries()].filter(([key]) =>
      key.startsWith(deckPrefix)
    );
    if (deckMatches.length === 1) {
      return deckMatches[0][1];
    }
  }

  return null;
}
