"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveFlutterAssetsRoot = resolveFlutterAssetsRoot;
exports.resolveCardImage = resolveCardImage;
exports.localAssetsAvailable = localAssetsAvailable;
exports.ensurePng = ensurePng;
exports.fileToInputFile = fileToInputFile;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const sharp_1 = __importDefault(require("sharp"));
const grammy_1 = require("grammy");
const conversionCache = new Map();
const cardImageMapCache = new Map();
function resolveFlutterAssetsRoot() {
    const checkedPaths = [];
    const envRoot = process.env.FLUTTER_ASSETS_ROOT?.trim();
    if (envRoot) {
        const resolved = path_1.default.resolve(envRoot);
        const cardsPath = path_1.default.join(resolved, "cards");
        if (resolved.includes(`${path_1.default.sep}assets${path_1.default.sep}cards`) ||
            fs_1.default.existsSync(cardsPath)) {
            return resolved;
        }
        checkedPaths.push(resolved);
    }
    const candidates = [
        path_1.default.resolve(process.cwd(), "..", "app_flutter", "assets"),
        path_1.default.resolve(process.cwd(), "..", "basil_arcana", "app_flutter", "assets"),
        path_1.default.resolve(process.cwd(), "..", "..", "app_flutter", "assets"),
        path_1.default.resolve(process.cwd(), "..", "..", "basil_arcana", "app_flutter", "assets"),
    ];
    for (const candidate of candidates) {
        checkedPaths.push(candidate);
        if (fs_1.default.existsSync(path_1.default.join(candidate, "cards"))) {
            return candidate;
        }
    }
    throw new Error(`Unable to locate Flutter assets root. cwd=${process.cwd()} Checked: ${checkedPaths.join(", ")}`);
}
function buildCardImageMap(assetsBasePath) {
    const map = new Map();
    const cardRoot = path_1.default.join(assetsBasePath, "cards");
    const deckFolders = ["wands", "major"];
    for (const deck of deckFolders) {
        const deckDir = path_1.default.join(cardRoot, deck);
        if (!fs_1.default.existsSync(deckDir)) {
            continue;
        }
        const entries = fs_1.default.readdirSync(deckDir, { withFileTypes: true });
        for (const entry of entries) {
            if (!entry.isFile()) {
                continue;
            }
            const ext = path_1.default.extname(entry.name);
            if (ext !== ".webp") {
                continue;
            }
            const baseName = path_1.default.basename(entry.name, ext);
            map.set(baseName, path_1.default.join(deckDir, entry.name));
        }
    }
    return map;
}
function getCardImageMap(assetsBasePath) {
    const existing = cardImageMapCache.get(assetsBasePath);
    if (existing) {
        return existing;
    }
    const built = buildCardImageMap(assetsBasePath);
    cardImageMapCache.set(assetsBasePath, built);
    return built;
}
function resolveCardImage(cardId, assetsBasePath) {
    const map = getCardImageMap(assetsBasePath);
    const exact = map.get(cardId);
    if (exact) {
        return exact;
    }
    const prefix = `${cardId}_`;
    const matches = [...map.keys()].filter((key) => key.startsWith(prefix));
    if (matches.length === 1) {
        return map.get(matches[0]);
    }
    const suggestions = [...map.keys()]
        .filter((key) => key.startsWith(cardId.split("_")[0]))
        .slice(0, 5);
    if (matches.length > 1) {
        throw new Error(`Multiple matches for cardId=${cardId}: ${matches.join(", ")}`);
    }
    throw new Error(`Unable to resolve card image for ${cardId}. Suggestions: ${suggestions.join(", ")}`);
}
function localAssetsAvailable(assetsBasePath) {
    return fs_1.default.existsSync(path_1.default.join(assetsBasePath, "cards"));
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
async function fileToInputFile(inputPath) {
    const fileBuffer = await fs_1.default.promises.readFile(inputPath);
    const pngBuffer = await (0, sharp_1.default)(fileBuffer).png().toBuffer();
    const baseName = path_1.default.basename(inputPath, path_1.default.extname(inputPath));
    return new grammy_1.InputFile(pngBuffer, `${baseName}.png`);
}
