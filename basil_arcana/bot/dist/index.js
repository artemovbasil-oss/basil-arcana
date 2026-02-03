"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const grammy_1 = require("grammy");
const crypto_1 = require("crypto");
const config_1 = require("./config");
const assets_1 = require("./assets");
const decks_1 = require("./decks");
const store_1 = require("./state/store");
const i18n_1 = require("./i18n");
const config = (0, config_1.loadConfig)();
const stateStore = new store_1.StateStore(config.defaultLocale);
async function main() {
    const decks = await (0, decks_1.loadDecks)();
    (0, assets_1.logAssetsSummary)(config.assetsBasePath);
    const bot = new grammy_1.Bot(config.telegramToken);
    bot.command("start", async (ctx) => {
        const userId = ctx.from?.id;
        if (!userId) {
            return;
        }
        const messages = (0, i18n_1.t)(stateStore.get(userId).locale);
        const keyboard = new grammy_1.InlineKeyboard()
            .text("EN", "lang:en")
            .text("RU", "lang:ru")
            .text("KZ", "lang:kk");
        stateStore.update(userId, { step: "idle", isProcessing: false });
        await ctx.reply(messages.languagePrompt, { reply_markup: keyboard });
    });
    bot.on("callback_query:data", async (ctx) => {
        const userId = ctx.from?.id;
        if (!userId) {
            await ctx.answerCallbackQuery();
            return;
        }
        const data = ctx.callbackQuery.data;
        const state = stateStore.get(userId);
        const messages = (0, i18n_1.t)(state.locale);
        if (state.isProcessing) {
            await ctx.answerCallbackQuery({ text: messages.alreadyProcessing });
            return;
        }
        if (data.startsWith("lang:")) {
            const locale = data.replace("lang:", "");
            stateStore.update(userId, {
                locale,
                step: "awaiting_question",
                isProcessing: false,
            });
            await ctx.answerCallbackQuery();
            await ctx.reply((0, i18n_1.t)(locale).languageSet);
            await ctx.reply((0, i18n_1.t)(locale).askQuestion);
            return;
        }
        if (data.startsWith("spread:")) {
            const spreadId = data.replace("spread:", "");
            const current = stateStore.get(userId);
            if (!current.question) {
                await ctx.answerCallbackQuery();
                await ctx.reply(messages.askQuestion);
                stateStore.update(userId, { step: "awaiting_question" });
                return;
            }
            await ctx.answerCallbackQuery();
            stateStore.update(userId, { spreadId, isProcessing: true });
            await ctx.reply(messages.processing);
            try {
                await handleReading(ctx, current.question, spreadId, current.locale, decks);
            }
            catch (error) {
                console.error(error);
                await ctx.reply(messages.readingFailed);
            }
            finally {
                stateStore.update(userId, { isProcessing: false, step: "showing_result" });
            }
            return;
        }
        if (data === "action:new") {
            await ctx.answerCallbackQuery();
            stateStore.update(userId, {
                question: undefined,
                spreadId: undefined,
                step: "awaiting_question",
                isProcessing: false,
            });
            await ctx.reply(messages.askQuestion);
            return;
        }
        if (data === "action:details") {
            await ctx.answerCallbackQuery();
            const current = stateStore.get(userId);
            if (!current.lastReading) {
                await ctx.reply(messages.missingReading);
                return;
            }
            stateStore.update(userId, { isProcessing: true });
            try {
                await sendDetails(ctx, current.lastReading, current.locale);
            }
            catch (error) {
                console.error(error);
                await ctx.reply(messages.detailsFailed);
            }
            finally {
                stateStore.update(userId, { isProcessing: false });
            }
            return;
        }
        await ctx.answerCallbackQuery();
    });
    bot.on("message:text", async (ctx) => {
        const userId = ctx.from?.id;
        if (!userId) {
            return;
        }
        const state = stateStore.get(userId);
        const messages = (0, i18n_1.t)(state.locale);
        if (state.step !== "awaiting_question") {
            return;
        }
        const question = ctx.message.text.trim();
        if (!question) {
            await ctx.reply(messages.askQuestion);
            return;
        }
        stateStore.update(userId, { question, step: "awaiting_spread" });
        const keyboard = new grammy_1.InlineKeyboard()
            .text(messages.spreadOne, "spread:one")
            .text(messages.spreadThree, "spread:three");
        await ctx.reply(messages.chooseSpread, { reply_markup: keyboard });
    });
    bot.catch((err) => {
        console.error("Bot error", err.error);
    });
    await bot.start({
        allowed_updates: ["message", "callback_query"],
    });
    console.log("Telegram bot started.");
}
async function handleReading(ctx, question, spreadId, locale, decks) {
    const spreads = decks.spreadsByLocale[locale] || decks.spreadsByLocale.en;
    const spread = (0, decks_1.pickSpread)(spreads, spreadId);
    const drawnIds = (0, decks_1.drawCards)(decks.allCardIds, spread.positions.length);
    const cardsData = decks.cardsByLocale[locale] || decks.cardsByLocale.en;
    const fallbackCards = decks.cardsByLocale.en;
    const cardsPayload = spread.positions.map((position, index) => {
        const cardId = drawnIds[index];
        const cardData = cardsData[cardId] || fallbackCards[cardId];
        if (!cardData) {
            throw new Error(`Missing card data for ${cardId}`);
        }
        return {
            positionId: position.id,
            positionTitle: position.title,
            cardId,
            cardName: cardData?.title || cardId,
            keywords: cardData?.keywords || [],
            meaning: cardData?.meaning || {
                general: "",
                light: "",
                shadow: "",
                advice: "",
            },
        };
    });
    await sendCardImages(ctx, drawnIds, locale);
    let reading;
    try {
        reading = await callGenerate(question, spread, cardsPayload, locale);
    }
    catch (error) {
        if (error instanceof ApiError && error.status === 400) {
            await ctx.reply((0, i18n_1.t)(locale).readingFailedBadRequest);
            return;
        }
        throw error;
    }
    const shortText = [reading.tldr, reading.action, reading.fullText]
        .filter(Boolean)
        .join("\n\n");
    if (shortText) {
        await ctx.reply(shortText);
    }
    const keyboard = new grammy_1.InlineKeyboard()
        .text((0, i18n_1.t)(locale).detailsButton, "action:details")
        .text((0, i18n_1.t)(locale).newReadingButton, "action:new");
    await ctx.reply((0, i18n_1.t)(locale).nextAction, { reply_markup: keyboard });
    const userId = ctx.from?.id;
    if (userId) {
        stateStore.update(userId, {
            lastReading: { question, spread, cards: cardsPayload },
            step: "showing_result",
        });
    }
}
async function sendCardImages(ctx, cardIds, locale) {
    if (!(0, assets_1.localAssetsAvailable)(config.assetsBasePath)) {
        console.warn(`Local assets missing at ${config.assetsBasePath}. Set BOT_ASSETS_ROOT if needed.`);
        return;
    }
    const localPaths = cardIds.flatMap((cardId) => {
        const resolved = (0, assets_1.resolveCardImagePath)({ cardId }, config.assetsBasePath);
        if (!resolved) {
            console.warn(`Unable to resolve card image for ${cardId}`);
            return [];
        }
        return [resolved];
    });
    if (localPaths.length === 0) {
        return;
    }
    const messages = (0, i18n_1.t)(locale);
    if (localPaths.length === 1) {
        await ctx.replyWithPhoto(new grammy_1.InputFile(localPaths[0]));
        return;
    }
    const media = localPaths.map((localPath, index) => {
        const item = {
            type: "photo",
            media: new grammy_1.InputFile(localPath),
        };
        if (index === 0) {
            item.caption = messages.cardsCaption;
        }
        return item;
    });
    try {
        await ctx.replyWithMediaGroup(media);
        return;
    }
    catch (error) {
        console.warn("Media group failed, sending photos individually", error);
    }
    for (const [index, localPath] of localPaths.entries()) {
        const options = index === 0 ? { caption: messages.cardsCaption } : undefined;
        await ctx.replyWithPhoto(new grammy_1.InputFile(localPath), options);
    }
}
async function callGenerate(question, spread, cards, locale) {
    const endpoint = "/api/reading/generate";
    const mode = "fast";
    const requestId = (0, crypto_1.randomUUID)();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    try {
        const cardsPayload = toAiCardsPayload(cards, "fast");
        const payload = {
            question,
            spread,
            cards: cardsPayload,
            tone: "neutral",
            language: locale,
            responseFormat: "strict_json",
            responseConstraints: {
                tldrMaxChars: 180,
                sectionMaxChars: 280,
                actionMaxChars: 160,
            },
        };
        const payloadSummary = {
            questionLength: question.length,
            spreadId: spread.id,
            locale,
            cardCount: cardsPayload.length,
            mode,
            deckMode: "random",
        };
        console.info(`[Api] generate payload ${JSON.stringify(payloadSummary)}`);
        const url = new URL(`${config.apiBaseUrl}${endpoint}`);
        url.searchParams.set("mode", mode);
        const response = await fetch(url.toString(), {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "x-api-key": config.arcanaApiKey,
                "x-request-id": requestId,
            },
            body: JSON.stringify(payload),
            signal: controller.signal,
        });
        if (!response.ok) {
            const errorBody = await readErrorBody(response);
            logApiError({
                endpoint,
                status: response.status,
                requestId,
                payloadSummary,
                errorBody,
            });
            const serverMessage = extractServerMessage(errorBody, response.statusText);
            throw new ApiError(`Generate failed: ${response.status} ${serverMessage}`.trim(), response.status, endpoint, requestId, serverMessage);
        }
        return (await response.json());
    }
    finally {
        clearTimeout(timeout);
    }
}
async function sendDetails(ctx, payload, locale) {
    const endpoint = "/api/reading/details";
    const requestId = (0, crypto_1.randomUUID)();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    try {
        const cardsPayload = toAiCardsPayload(payload.cards, "deep");
        const payloadSummary = {
            questionLength: payload.question.length,
            spreadId: payload.spread.id,
            locale,
            cardCount: cardsPayload.length,
            mode: "details",
            deckMode: "random",
        };
        console.info(`[Api] details payload ${JSON.stringify(payloadSummary)}`);
        const response = await fetch(`${config.apiBaseUrl}${endpoint}`, {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "x-api-key": config.arcanaApiKey,
                "x-request-id": requestId,
            },
            body: JSON.stringify({
                question: payload.question,
                spread: payload.spread,
                cards: cardsPayload,
                locale,
            }),
            signal: controller.signal,
        });
        if (!response.ok) {
            const errorBody = await readErrorBody(response);
            logApiError({
                endpoint,
                status: response.status,
                requestId,
                payloadSummary,
                errorBody,
            });
            const serverMessage = extractServerMessage(errorBody, response.statusText);
            throw new ApiError(`Details failed: ${response.status} ${serverMessage}`.trim(), response.status, endpoint, requestId, serverMessage);
        }
        const result = (await response.json());
        if (result.detailsText) {
            await ctx.reply(result.detailsText);
        }
    }
    finally {
        clearTimeout(timeout);
    }
}
class ApiError extends Error {
    status;
    endpoint;
    requestId;
    serverMessage;
    constructor(message, status, endpoint, requestId, serverMessage) {
        super(message);
        this.name = "ApiError";
        this.status = status;
        this.endpoint = endpoint;
        this.requestId = requestId;
        this.serverMessage = serverMessage;
    }
}
function toAiCardsPayload(cards, mode) {
    const totalCards = cards.length;
    const keywordLimit = mode === "deep" ? (totalCards > 1 ? 4 : 6) : totalCards > 1 ? 3 : 5;
    const meaningLimit = mode === "deep" ? (totalCards > 1 ? 70 : 110) : totalCards > 1 ? 90 : 140;
    return cards.map((card) => ({
        ...card,
        keywords: card.keywords.slice(0, keywordLimit),
        meaning: {
            general: truncate(card.meaning.general, meaningLimit),
            light: truncate(card.meaning.light, meaningLimit),
            shadow: truncate(card.meaning.shadow, meaningLimit),
            advice: truncate(card.meaning.advice, meaningLimit),
        },
    }));
}
function truncate(value, maxLength) {
    if (value.length <= maxLength) {
        return value;
    }
    return value.substring(0, maxLength).trimRight();
}
async function readErrorBody(response) {
    try {
        return (await response.json());
    }
    catch (error) {
        try {
            const text = await response.text();
            return text || null;
        }
        catch (textError) {
            return null;
        }
    }
}
function extractServerMessage(errorBody, fallback) {
    if (!errorBody) {
        return fallback;
    }
    if (typeof errorBody === "string") {
        return errorBody;
    }
    const message = (typeof errorBody.message === "string" && errorBody.message) ||
        (typeof errorBody.error === "string" && errorBody.error) ||
        (typeof errorBody.error?.message ===
            "string" &&
            errorBody.error.message);
    return message || fallback;
}
function logApiError({ endpoint, status, requestId, payloadSummary, errorBody, }) {
    const sanitizedPayload = {
        ...payloadSummary,
    };
    const serverMessage = extractServerMessage(errorBody, "Unexpected response");
    const errorOutput = config.debug ? errorBody : serverMessage;
    console.error(`[ApiError] endpoint=${endpoint} status=${status} requestId=${requestId} payload=${JSON.stringify(sanitizedPayload)} error=${JSON.stringify(errorOutput)}`);
}
main().catch((error) => {
    console.error("Startup failure", error);
    process.exit(1);
});
