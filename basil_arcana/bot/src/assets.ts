import fs from "fs";
import path from "path";
import sharp from "sharp";
import { InputFile } from "grammy";

const conversionCache = new Map<string, string>();
const cardImageMapCache = new Map<string, Map<string, string>>();

export function resolveFlutterAssetsRoot(): string {
  const checkedPaths: string[] = [];
  const envRoot = process.env.FLUTTER_ASSETS_ROOT?.trim();
  if (envRoot) {
    const resolved = path.resolve(envRoot);
    const cardsPath = path.join(resolved, "cards");
    if (
      resolved.includes(`${path.sep}assets${path.sep}cards`) ||
      fs.existsSync(cardsPath)
    ) {
      return resolved;
    }
    checkedPaths.push(resolved);
  }

  const candidates = [
    path.resolve(process.cwd(), "..", "app_flutter", "assets"),
    path.resolve(process.cwd(), "..", "basil_arcana", "app_flutter", "assets"),
    path.resolve(process.cwd(), "..", "..", "app_flutter", "assets"),
    path.resolve(
      process.cwd(),
      "..",
      "..",
      "basil_arcana",
      "app_flutter",
      "assets"
    ),
  ];

  for (const candidate of candidates) {
    checkedPaths.push(candidate);
    if (fs.existsSync(path.join(candidate, "cards"))) {
      return candidate;
    }
  }

  throw new Error(
    `Unable to locate Flutter assets root. cwd=${process.cwd()} Checked: ${checkedPaths.join(
      ", "
    )}`
  );
}

function buildCardImageMap(assetsBasePath: string): Map<string, string> {
  const map = new Map<string, string>();
  const cardRoot = path.join(assetsBasePath, "cards");
  const deckFolders = ["wands", "major"];

  for (const deck of deckFolders) {
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

export function resolveCardImage(
  cardId: string,
  assetsBasePath: string
): string {
  const map = getCardImageMap(assetsBasePath);
  const exact = map.get(cardId);
  if (exact) {
    return exact;
  }

  const prefix = `${cardId}_`;
  const matches = [...map.keys()].filter((key) => key.startsWith(prefix));
  if (matches.length === 1) {
    return map.get(matches[0]) as string;
  }

  const suggestions = [...map.keys()]
    .filter((key) => key.startsWith(cardId.split("_")[0]))
    .slice(0, 5);

  if (matches.length > 1) {
    throw new Error(
      `Multiple matches for cardId=${cardId}: ${matches.join(", ")}`
    );
  }

  throw new Error(
    `Unable to resolve card image for ${cardId}. Suggestions: ${suggestions.join(
      ", "
    )}`
  );
}

export function localAssetsAvailable(assetsBasePath: string): boolean {
  return fs.existsSync(path.join(assetsBasePath, "cards"));
}

export async function ensurePng(inputPath: string): Promise<string> {
  const cached = conversionCache.get(inputPath);
  if (cached && fs.existsSync(cached)) {
    return cached;
  }
  const outputDir = path.join("/tmp", "basil-arcana-bot");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  const baseName = path.basename(inputPath, path.extname(inputPath));
  const outputPath = path.join(outputDir, `${baseName}.png`);
  await sharp(inputPath).png().toFile(outputPath);
  conversionCache.set(inputPath, outputPath);
  return outputPath;
}

export async function fileToInputFile(
  inputPath: string
): Promise<InputFile> {
  const fileBuffer = await fs.promises.readFile(inputPath);
  const pngBuffer = await sharp(fileBuffer).png().toBuffer();
  const baseName = path.basename(inputPath, path.extname(inputPath));
  return new InputFile(pngBuffer, `${baseName}.png`);
}
