"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const grammy_1 = require("grammy");
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
    const reading = await callGenerate(question, spread, cardsPayload, locale);
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
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    try {
        const response = await fetch(`${config.apiBaseUrl}/api/reading/generate`, {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "x-api-key": config.arcanaApiKey,
            },
            body: JSON.stringify({
                question,
                spread,
                cards,
                language: locale,
            }),
            signal: controller.signal,
        });
        if (!response.ok) {
            throw new Error(`Generate failed: ${response.status}`);
        }
        return (await response.json());
    }
    finally {
        clearTimeout(timeout);
    }
}
async function sendDetails(ctx, payload, locale) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    try {
        const response = await fetch(`${config.apiBaseUrl}/api/reading/details`, {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "x-api-key": config.arcanaApiKey,
            },
            body: JSON.stringify({
                question: payload.question,
                spread: payload.spread,
                cards: payload.cards,
                locale,
            }),
            signal: controller.signal,
        });
        if (!response.ok) {
            throw new Error(`Details failed: ${response.status}`);
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
main().catch((error) => {
    console.error("Startup failure", error);
    process.exit(1);
});
