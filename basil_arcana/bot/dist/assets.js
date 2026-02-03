"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveCardPath = resolveCardPath;
exports.ensurePng = ensurePng;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const sharp_1 = __importDefault(require("sharp"));
const conversionCache = new Map();
function resolveCardPath(cardId, assetsBasePath) {
    const majorPath = path_1.default.join(assetsBasePath, "cards", "major", `${cardId}.webp`);
    const wandsPath = path_1.default.join(assetsBasePath, "cards", "wands", `${cardId}.webp`);
    if (cardId.startsWith("major_") && fs_1.default.existsSync(majorPath)) {
        return majorPath;
    }
    if (cardId.startsWith("wands_") && fs_1.default.existsSync(wandsPath)) {
        return wandsPath;
    }
    return path_1.default.join(assetsBasePath, "deck", "cover.webp");
}
async function ensurePng(inputPath) {
    const cached = conversionCache.get(inputPath);
    if (cached && fs_1.default.existsSync(cached)) {
        return cached;
    }
    const outputDir = path_1.default.join("/tmp", "basil-arcana-bot");
    if (!fs_1.default.existsSync(outputDir)) {
        fs_1.default.mkdirSync(outputDir, { recursive: true });
    }
    const baseName = path_1.default.basename(inputPath, path_1.default.extname(inputPath));
    const outputPath = path_1.default.join(outputDir, `${baseName}.png`);
    await (0, sharp_1.default)(inputPath).png().toFile(outputPath);
    conversionCache.set(inputPath, outputPath);
    return outputPath;
}
