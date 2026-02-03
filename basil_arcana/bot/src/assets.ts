import fs from "fs";
import path from "path";
import sharp from "sharp";

const conversionCache = new Map<string, string>();

export function resolveCardPath(cardId: string, assetsBasePath: string): string {
  const majorPath = path.join(assetsBasePath, "cards", "major", `${cardId}.webp`);
  const wandsPath = path.join(assetsBasePath, "cards", "wands", `${cardId}.webp`);
  if (cardId.startsWith("major_") && fs.existsSync(majorPath)) {
    return majorPath;
  }
  if (cardId.startsWith("wands_") && fs.existsSync(wandsPath)) {
    return wandsPath;
  }
  return path.join(assetsBasePath, "deck", "cover.webp");
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
