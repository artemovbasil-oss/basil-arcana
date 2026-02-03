import { Bot, InlineKeyboard, InputFile } from "grammy";
import type { Context } from "grammy";
import type { InputMediaPhoto } from "grammy/types";
import { randomUUID } from "crypto";
import { loadConfig } from "./config";
import {
  resolveCardImagePath,
  localAssetsAvailable,
  logAssetsSummary,
} from "./assets";
import { loadDecks, pickSpread, drawCards } from "./decks";
import { StateStore } from "./state/store";
import { t } from "./i18n";
import type { Locale } from "./config";
import type { DrawnCard, Spread } from "./state/types";

const config = loadConfig();
const stateStore = new StateStore(config.defaultLocale);

async function main(): Promise<void> {
  const decks = await loadDecks();
  logAssetsSummary(config.assetsBasePath);

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

  await sendCardImages(ctx, drawnIds, locale);

  let reading;
  try {
    reading = await callGenerate(question, spread, cardsPayload, locale);
  } catch (error) {
    if (error instanceof ApiError && error.status === 400) {
      await ctx.reply(t(locale).readingFailedBadRequest);
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
  cardIds: string[],
  locale: Locale
): Promise<void> {
  if (!localAssetsAvailable(config.assetsBasePath)) {
    console.warn(
      `Local assets missing at ${config.assetsBasePath}. Set BOT_ASSETS_ROOT if needed.`
    );
    return;
  }

  const localPaths = cardIds.flatMap((cardId) => {
    const resolved = resolveCardImagePath({ cardId }, config.assetsBasePath);
    if (!resolved) {
      console.warn(`Unable to resolve card image for ${cardId}`);
      return [];
    }
    return [resolved];
  });

  if (localPaths.length === 0) {
    return;
  }

  const messages = t(locale);

  if (localPaths.length === 1) {
    await ctx.replyWithPhoto(new InputFile(localPaths[0]));
    return;
  }

  const media: InputMediaPhoto[] = localPaths.map((localPath, index) => {
    const item: InputMediaPhoto = {
      type: "photo",
      media: new InputFile(localPath),
    };
    if (index === 0) {
      item.caption = messages.cardsCaption;
    }
    return item;
  });

  try {
    await ctx.replyWithMediaGroup(media);
    return;
  } catch (error) {
    console.warn("Media group failed, sending photos individually", error);
  }

  for (const [index, localPath] of localPaths.entries()) {
    const options = index === 0 ? { caption: messages.cardsCaption } : undefined;
    await ctx.replyWithPhoto(new InputFile(localPath), options);
  }
}

async function callGenerate(
  question: string,
  spread: Spread,
  cards: DrawnCard[],
  locale: Locale
): Promise<{ tldr?: string; fullText?: string; action?: string }> {
  const endpoint = "/api/reading/generate";
  const mode = "fast";
  const requestId = randomUUID();
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
      throw new ApiError(
        `Generate failed: ${response.status} ${serverMessage}`.trim(),
        response.status,
        endpoint,
        requestId,
        serverMessage
      );
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
  const endpoint = "/api/reading/details";
  const requestId = randomUUID();
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
      throw new ApiError(
        `Details failed: ${response.status} ${serverMessage}`.trim(),
        response.status,
        endpoint,
        requestId,
        serverMessage
      );
    }
    const result = (await response.json()) as { detailsText?: string };
    if (result.detailsText) {
      await ctx.reply(result.detailsText);
    }
  } finally {
    clearTimeout(timeout);
  }
}

class ApiError extends Error {
  status: number;
  endpoint: string;
  requestId?: string;
  serverMessage?: string;

  constructor(
    message: string,
    status: number,
    endpoint: string,
    requestId?: string,
    serverMessage?: string
  ) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.endpoint = endpoint;
    this.requestId = requestId;
    this.serverMessage = serverMessage;
  }
}

function toAiCardsPayload(
  cards: DrawnCard[],
  mode: "fast" | "deep"
): DrawnCard[] {
  const totalCards = cards.length;
  const keywordLimit =
    mode === "deep" ? (totalCards > 1 ? 4 : 6) : totalCards > 1 ? 3 : 5;
  const meaningLimit =
    mode === "deep" ? (totalCards > 1 ? 70 : 110) : totalCards > 1 ? 90 : 140;
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

function truncate(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }
  return value.substring(0, maxLength).trimRight();
}

async function readErrorBody(
  response: Response
): Promise<Record<string, unknown> | string | null> {
  try {
    return (await response.json()) as Record<string, unknown>;
  } catch (error) {
    try {
      const text = await response.text();
      return text || null;
    } catch (textError) {
      return null;
    }
  }
}

function extractServerMessage(
  errorBody: Record<string, unknown> | string | null,
  fallback: string
): string {
  if (!errorBody) {
    return fallback;
  }
  if (typeof errorBody === "string") {
    return errorBody;
  }
  const message =
    (typeof errorBody.message === "string" && errorBody.message) ||
    (typeof errorBody.error === "string" && errorBody.error) ||
    (typeof (errorBody.error as { message?: string } | undefined)?.message ===
      "string" &&
      (errorBody.error as { message?: string }).message);
  return message || fallback;
}

function logApiError({
  endpoint,
  status,
  requestId,
  payloadSummary,
  errorBody,
}: {
  endpoint: string;
  status: number;
  requestId: string;
  payloadSummary: Record<string, unknown>;
  errorBody: Record<string, unknown> | string | null;
}): void {
  const sanitizedPayload = {
    ...payloadSummary,
  };
  const serverMessage = extractServerMessage(
    errorBody,
    "Unexpected response"
  );
  const errorOutput = config.debug ? errorBody : serverMessage;
  console.error(
    `[ApiError] endpoint=${endpoint} status=${status} requestId=${requestId} payload=${JSON.stringify(
      sanitizedPayload
    )} error=${JSON.stringify(errorOutput)}`
  );
}

main().catch((error) => {
  console.error("Startup failure", error);
  process.exit(1);
});
