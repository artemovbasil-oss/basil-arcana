"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveBotAssetsRoot = resolveBotAssetsRoot;
exports.localAssetsAvailable = localAssetsAvailable;
exports.logAssetsSummary = logAssetsSummary;
exports.resolveCardImagePath = resolveCardImagePath;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const cardImageMapCache = new Map();
const SUPPORTED_DECKS = ["major", "wands"];
function resolveBotAssetsRoot() {
    const envRoot = process.env.BOT_ASSETS_ROOT?.trim() ||
        process.env.ASSETS_BASE_PATH?.trim();
    if (envRoot) {
        return path_1.default.resolve(envRoot);
    }
    return path_1.default.resolve(__dirname, "..", "assets");
}
function localAssetsAvailable(assetsBasePath) {
    return fs_1.default.existsSync(path_1.default.join(assetsBasePath, "cards"));
}
function logAssetsSummary(assetsBasePath) {
    const deckFolders = listDeckFolders(assetsBasePath);
    const display = deckFolders.length > 0 ? deckFolders.join(", ") : "none";
    console.log(`Assets root resolved to ${assetsBasePath}. Deck folders found: ${display}.`);
}
function listDeckFolders(assetsBasePath) {
    const cardRoot = path_1.default.join(assetsBasePath, "cards");
    return SUPPORTED_DECKS.filter((deck) => fs_1.default.existsSync(path_1.default.join(cardRoot, deck)));
}
function buildCardImageMap(assetsBasePath) {
    const map = new Map();
    const cardRoot = path_1.default.join(assetsBasePath, "cards");
    for (const deck of SUPPORTED_DECKS) {
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
function stripExtension(value) {
    return path_1.default.basename(value, path_1.default.extname(value));
}
function inferDeckId(value) {
    if (value.startsWith("major_")) {
        return "major";
    }
    if (value.startsWith("wands_")) {
        return "wands";
    }
    return undefined;
}
function resolveCardImagePath(input, assetsBasePath) {
    const map = getCardImageMap(assetsBasePath);
    if (input.imagePath) {
        const resolved = path_1.default.isAbsolute(input.imagePath)
            ? input.imagePath
            : path_1.default.resolve(assetsBasePath, input.imagePath);
        if (fs_1.default.existsSync(resolved)) {
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
        const deckMatches = [...map.entries()].filter(([key]) => key.startsWith(deckPrefix));
        if (deckMatches.length === 1) {
            return deckMatches[0][1];
        }
    }
    return null;
}
