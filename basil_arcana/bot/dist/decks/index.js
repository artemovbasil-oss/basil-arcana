"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadDecks = loadDecks;
exports.pickSpread = pickSpread;
exports.drawCards = drawCards;
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
async function readJsonFile(filePath) {
    try {
        await promises_1.default.access(filePath);
    }
    catch (error) {
        throw new Error(`Missing deck data file at ${filePath}. cwd=${process.cwd()}`);
    }
    const raw = await promises_1.default.readFile(filePath, "utf-8");
    return JSON.parse(raw);
}
async function loadDecks(dataBasePath) {
    const locales = ["en", "ru", "kk"];
    const cardsByLocale = {
        en: {},
        ru: {},
        kk: {},
    };
    const spreadsByLocale = {
        en: [],
        ru: [],
        kk: [],
    };
    await Promise.all(locales.map(async (locale) => {
        const cardsPath = path_1.default.resolve(dataBasePath, `cards_${locale}.json`);
        const spreadsPath = path_1.default.resolve(dataBasePath, `spreads_${locale}.json`);
        const [cards, spreads] = await Promise.all([
            readJsonFile(cardsPath),
            readJsonFile(spreadsPath),
        ]);
        cardsByLocale[locale] = cards;
        spreadsByLocale[locale] = spreads;
    }));
    const allCardIds = Object.keys(cardsByLocale.en);
    return { cardsByLocale, spreadsByLocale, allCardIds };
}
function pickSpread(spreads, spreadId) {
    if (spreadId === "one") {
        return spreads[0];
    }
    return spreads[1] || spreads[0];
}
function drawCards(cardIds, count) {
    const remaining = [...cardIds];
    const selected = [];
    while (selected.length < count && remaining.length > 0) {
        const index = Math.floor(Math.random() * remaining.length);
        selected.push(remaining.splice(index, 1)[0]);
    }
    return selected;
}
