import { Bot, InlineKeyboard, InputFile } from "grammy";
import type { Context } from "grammy";
import { loadConfig } from "./config";
import { resolveCardPath, ensurePng } from "./assets";
import { loadDecks, pickSpread, drawCards } from "./decks";
import { StateStore } from "./state/store";
import { t } from "./i18n";
import type { Locale } from "./config";
import type { DrawnCard, Spread } from "./state/types";

const config = loadConfig();
const stateStore = new StateStore(config.defaultLocale);

async function main(): Promise<void> {
  const decks = await loadDecks(config.dataBasePath);

  const bot = new Bot(config.telegramToken);

  bot.command("start", async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      return;
    }
    const messages = t(stateStore.get(userId).locale);
    const keyboard = new InlineKeyboard()
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
    const messages = t(state.locale);

    if (state.isProcessing) {
      await ctx.answerCallbackQuery({ text: messages.alreadyProcessing });
      return;
    }

    if (data.startsWith("lang:")) {
      const locale = data.replace("lang:", "") as Locale;
      stateStore.update(userId, {
        locale,
        step: "awaiting_question",
        isProcessing: false,
      });
      await ctx.answerCallbackQuery();
      await ctx.reply(t(locale).languageSet);
      await ctx.reply(t(locale).askQuestion);
      return;
    }

    if (data.startsWith("spread:")) {
      const spreadId = data.replace("spread:", "") as "one" | "three";
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
      } catch (error) {
        console.error(error);
        await ctx.reply(messages.readingFailed);
      } finally {
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
      } catch (error) {
        console.error(error);
        await ctx.reply(messages.detailsFailed);
      } finally {
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
    const messages = t(state.locale);
    if (state.step !== "awaiting_question") {
      return;
    }
    const question = ctx.message.text.trim();
    if (!question) {
      await ctx.reply(messages.askQuestion);
      return;
    }
    stateStore.update(userId, { question, step: "awaiting_spread" });
    const keyboard = new InlineKeyboard()
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

async function handleReading(
  ctx: Context,
  question: string,
  spreadId: "one" | "three",
  locale: Locale,
  decks: Awaited<ReturnType<typeof loadDecks>>
): Promise<void> {
  const spreads = decks.spreadsByLocale[locale] || decks.spreadsByLocale.en;
  const spread = pickSpread(spreads, spreadId);
  const drawnIds = drawCards(decks.allCardIds, spread.positions.length);
  const cardsData = decks.cardsByLocale[locale] || decks.cardsByLocale.en;
  const fallbackCards = decks.cardsByLocale.en;
  const cardsPayload: DrawnCard[] = spread.positions.map((position, index) => {
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

  await sendCardImages(ctx, drawnIds);

  const reading = await callGenerate(question, spread, cardsPayload, locale);
  const shortText = [reading.tldr, reading.action, reading.fullText]
    .filter(Boolean)
    .join("\n\n");
  if (shortText) {
    await ctx.reply(shortText);
  }

  const keyboard = new InlineKeyboard()
    .text(t(locale).detailsButton, "action:details")
    .text(t(locale).newReadingButton, "action:new");
  await ctx.reply(t(locale).nextAction, { reply_markup: keyboard });

  const userId = ctx.from?.id;
  if (userId) {
    stateStore.update(userId, {
      lastReading: { question, spread, cards: cardsPayload },
      step: "showing_result",
    });
  }
}

async function sendCardImages(
  ctx: Context,
  cardIds: string[]
): Promise<void> {
  const paths = cardIds.map((cardId) => resolveCardPath(cardId, config.assetsBasePath));
  if (paths.length === 1) {
    try {
      await ctx.replyWithPhoto(new InputFile(paths[0]));
      return;
    } catch (error) {
      console.warn("WEBP failed, converting to PNG", error);
    }
    const pngPath = await ensurePng(paths[0]);
    await ctx.replyWithPhoto(new InputFile(pngPath));
    return;
  }

  const media = paths.map((p) => ({ type: "photo", media: new InputFile(p) }));
  try {
    await ctx.replyWithMediaGroup(media);
    return;
  } catch (error) {
    console.warn("WEBP media group failed, converting to PNG", error);
  }

  const pngPaths = await Promise.all(paths.map((p) => ensurePng(p)));
  const pngMedia = pngPaths.map((p) => ({ type: "photo", media: new InputFile(p) }));
  await ctx.replyWithMediaGroup(pngMedia);
}

async function callGenerate(
  question: string,
  spread: Spread,
  cards: DrawnCard[],
  locale: Locale
): Promise<{ tldr?: string; fullText?: string; action?: string }> {
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
    return (await response.json()) as {
      tldr?: string;
      fullText?: string;
      action?: string;
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function sendDetails(
  ctx: Context,
  payload: { question: string; spread: Spread; cards: DrawnCard[] },
  locale: Locale
): Promise<void> {
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
    const result = (await response.json()) as { detailsText?: string };
    if (result.detailsText) {
      await ctx.reply(result.detailsText);
    }
  } finally {
    clearTimeout(timeout);
  }
}

main().catch((error) => {
  console.error("Startup failure", error);
  process.exit(1);
});
