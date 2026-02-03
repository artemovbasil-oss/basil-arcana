"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadDecks = loadDecks;
exports.pickSpread = pickSpread;
exports.drawCards = drawCards;
const MAJOR_CARD_IDS = [
    "major_00_fool",
    "major_01_magician",
    "major_02_high_priestess",
    "major_03_empress",
    "major_04_emperor",
    "major_05_hierophant",
    "major_06_lovers",
    "major_07_chariot",
    "major_08_strength",
    "major_09_hermit",
    "major_10_wheel_of_fortune",
    "major_11_justice",
    "major_12_hanged_man",
    "major_13_death",
    "major_14_temperance",
    "major_15_devil",
    "major_16_tower",
    "major_17_star",
    "major_18_moon",
    "major_19_sun",
    "major_20_judgement",
    "major_21_world",
];
const WANDS_CARD_IDS = Array.from({ length: 14 }, (_, index) => `wands_${String(index + 1).padStart(2, "0")}`);
function humanizeCardId(cardId, deckId) {
    const withoutPrefix = cardId.startsWith(`${deckId}_`)
        ? cardId.slice(deckId.length + 1)
        : cardId;
    return withoutPrefix
        .split("_")
        .filter(Boolean)
        .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
        .join(" ");
}
function buildDeck(deckId, cardIds) {
    return cardIds.map((id) => ({
        id,
        deckId,
        displayName: humanizeCardId(id, deckId),
    }));
}
async function loadDecks() {
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
    const majorCards = buildDeck("major", MAJOR_CARD_IDS);
    const wandsCards = buildDeck("wands", WANDS_CARD_IDS);
    const allCards = [...majorCards, ...wandsCards];
    const cardRecords = allCards.reduce((acc, card) => {
        acc[card.id] = {
            title: card.displayName,
            keywords: [],
            meaning: {
                general: "",
                light: "",
                shadow: "",
                advice: "",
            },
        };
        return acc;
    }, {});
    const spreads = [
        {
            id: "spread_1_focus",
            name: "Focus / Advice",
            positions: [{ id: "p1", title: "Focus / Advice" }],
        },
        {
            id: "spread_3_situation_challenge_step",
            name: "Situation / Challenge / Next Step",
            positions: [
                { id: "p1", title: "Situation" },
                { id: "p2", title: "Challenge" },
                { id: "p3", title: "Next Step" },
            ],
        },
    ];
    locales.forEach((locale) => {
        cardsByLocale[locale] = { ...cardRecords };
        spreadsByLocale[locale] = spreads;
    });
    const allCardIds = allCards.map((card) => card.id).sort();
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
