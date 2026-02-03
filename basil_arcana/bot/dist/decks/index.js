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
        const cardsPath = path_1.default.join(dataBasePath, `cards_${locale}.json`);
        const spreadsPath = path_1.default.join(dataBasePath, `spreads_${locale}.json`);
        const [cardsRaw, spreadsRaw] = await Promise.all([
            promises_1.default.readFile(cardsPath, "utf-8"),
            promises_1.default.readFile(spreadsPath, "utf-8"),
        ]);
        cardsByLocale[locale] = JSON.parse(cardsRaw);
        spreadsByLocale[locale] = JSON.parse(spreadsRaw);
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
