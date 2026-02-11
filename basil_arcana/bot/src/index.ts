import { Bot, InlineKeyboard, type Context } from "grammy";
import { loadConfig } from "./config";

const config = loadConfig();

type SupportedLocale = "ru" | "en" | "kk";
type PlanId = "week" | "month" | "year";

interface UserState {
  activeSubscription: boolean;
  selectedPlan: PlanId | null;
  locale: SupportedLocale | null;
  pendingStartPayload: string | null;
}

const STRINGS: Record<
  SupportedLocale,
  {
    menuTitle: string;
    menuDescription: string;
    menuButtons: {
      launchApp: string;
      buy: string;
      about: string;
      back: string;
    };
    languagePrompt: string;
    languageButtons: Record<SupportedLocale, string>;
    launchUnavailable: string;
    aboutText: string;
    professionalTitle: string;
    professionalDescription: string;
    planLabels: Record<PlanId, string>;
    alreadyActive: string;
    planAlreadySelected: string;
    paymentStub: string;
  }
> = {
  ru: {
    menuTitle: "Добро пожаловать в Basil’s Arcana ✨",
    menuDescription: "Выбери действие из меню ниже.",
    menuButtons: {
      launchApp: "🚀 Запустить мини‑приложение",
      buy: "💳 Купить подписку",
      about: "✨ Чем мы можем быть полезны",
      back: "⬅️ В меню",
    },
    languagePrompt:
      "На каком языке тебе удобнее общаться?\nТілді таңдаңыз.\nWhich language do you prefer?",
    languageButtons: {
      ru: "🇷🇺 Русский · ru",
      kk: "🇰🇿 Қазақша · kz",
      en: "🇬🇧 English · en",
    },
    launchUnavailable: "🚀 Временно недоступно",
    aboutText:
      "✨ Чем мы можем быть полезны\n\nВ приложении Basil’s Arcana:\n• Быстрые и глубокие расклады на отношения, деньги, карьеру и состояние.\n• Персональные подсказки и понятные шаги по ситуации.\n• История твоих раскладов в одном месте.\n• Мини‑приложение с атмосферой и интерактивными картами.\n\n🔮 Наш таролог и астролог София\n• Мягкий, точный и глубокий разбор запроса.\n• Личная консультация по твоей ситуации.\n• Видео Софии: https://cdn.basilarcana.com/sofia/sofia.webm\n• Профиль Софии: https://t.me/SofiaKnoxx",
    professionalTitle: "🔮 Профессиональное толкование",
    professionalDescription:
      "Хочешь более глубокий и персональный разбор?\nВыбери подходящий тариф — и оракул раскроется полностью.",
    planLabels: {
      week: "Неделя — 299 ₽",
      month: "Месяц — 899 ₽ ⭐️",
      year: "Год — 6 990 ₽",
    },
    alreadyActive: "У тебя уже есть активная подписка",
    planAlreadySelected: "Тариф уже выбран.",
    paymentStub: "Оплата скоро будет доступна.",
  },
  en: {
    menuTitle: "Welcome to Basil’s Arcana ✨",
    menuDescription: "Choose an action from the menu below.",
    menuButtons: {
      launchApp: "🚀 Launch app",
      buy: "💳 Buy subscription",
      about: "✨ How we can help",
      back: "⬅️ Back to menu",
    },
    languagePrompt:
      "На каком языке тебе удобнее общаться?\nТілді таңдаңыз.\nWhich language do you prefer?",
    languageButtons: {
      ru: "🇷🇺 Русский · ru",
      kk: "🇰🇿 Қазақша · kz",
      en: "🇬🇧 English · en",
    },
    launchUnavailable: "🚀 Temporarily unavailable",
    aboutText:
      "✨ How we can help\n\nInside Basil’s Arcana:\n• Quick and deep readings for love, money, career, and inner state.\n• Personalized insights with clear next steps.\n• Reading history in one place.\n• Atmospheric mini app with interactive cards.\n\n🔮 Our tarot reader and astrologer Sofia\n• Calm, precise, and deep interpretation.\n• Personal consultation for your situation.\n• Sofia video: https://cdn.basilarcana.com/sofia/sofia.webm\n• Sofia profile: https://t.me/SofiaKnoxx",
    professionalTitle: "🔮 Professional reading",
    professionalDescription:
      "Want a deeper, more personal interpretation?\nPick the plan that fits you — and the oracle will open up fully.",
    planLabels: {
      week: "Week — 299 ₽",
      month: "Month — 899 ₽ ⭐️",
      year: "Year — 6 990 ₽",
    },
    alreadyActive: "You already have an active subscription",
    planAlreadySelected: "Plan already selected.",
    paymentStub: "Coming soon.",
  },
  kk: {
    menuTitle: "Basil’s Arcana-ға қош келдің ✨",
    menuDescription: "Төмендегі мәзірден әрекет таңда.",
    menuButtons: {
      launchApp: "🚀 Мини‑қосымшаны ашу",
      buy: "💳 Жазылымды сатып алу",
      about: "✨ Қалай көмектесе аламыз",
      back: "⬅️ Мәзірге",
    },
    languagePrompt:
      "На каком языке тебе удобнее общаться?\nТілді таңдаңыз.\nWhich language do you prefer?",
    languageButtons: {
      ru: "🇷🇺 Русский · ru",
      kk: "🇰🇿 Қазақша · kz",
      en: "🇬🇧 English · en",
    },
    launchUnavailable: "🚀 Уақытша қолжетімсіз",
    aboutText:
      "✨ Қалай көмектесе аламыз\n\nBasil’s Arcana ішінде:\n• Қарым-қатынас, қаржы, мансап және ішкі күйге арналған жедел әрі терең жорамалдар.\n• Жеке кеңес және нақты келесі қадамдар.\n• Барлық жорамалдар тарихы бір жерде.\n• Атмосферасы бар интерактивті мини-қосымша.\n\n🔮 Біздің таролог және астролог София\n• Сұрағыңды жұмсақ әрі дәл талдайды.\n• Жағдайыңа сай жеке консультация береді.\n• София видеосы: https://cdn.basilarcana.com/sofia/sofia.webm\n• София профилі: https://t.me/SofiaKnoxx",
    professionalTitle: "🔮 Кәсіби жорамал",
    professionalDescription:
      "Терең әрі жеке талдау қалайсың ба?\nӨзіңе ыңғайлы тарифті таңда — сонда оракул толық ашылады.",
    planLabels: {
      week: "Апта — 299 ₽",
      month: "Ай — 899 ₽ ⭐️",
      year: "Жыл — 6 990 ₽",
    },
    alreadyActive: "Сенде белсенді жазылым бар",
    planAlreadySelected: "Тариф таңдалған.",
    paymentStub: "Жақында қолжетімді болады.",
  },
};

const userState = new Map<number, UserState>();

function buildMainMenuKeyboard(locale: SupportedLocale): InlineKeyboard {
  const labels = STRINGS[locale].menuButtons;
  const keyboard = new InlineKeyboard();
  if (config.webAppUrl) {
    keyboard.webApp(labels.launchApp, config.webAppUrl).row();
  }
  keyboard.text(labels.buy, "menu:buy").row().text(labels.about, "menu:about");
  return keyboard;
}

function buildLanguageKeyboard(): InlineKeyboard {
  const labels = STRINGS.ru.languageButtons;
  return new InlineKeyboard()
    .text(labels.ru, "lang:ru")
    .row()
    .text(labels.kk, "lang:kk")
    .row()
    .text(labels.en, "lang:en");
}

function detectLocaleFromTelegram(ctx: Context): SupportedLocale {
  const code = ctx.from?.language_code?.toLowerCase() ?? "";
  if (code.startsWith("kk") || code.startsWith("kz")) {
    return "kk";
  }
  if (code.startsWith("en")) {
    return "en";
  }
  return "ru";
}

function getLocale(ctx: Context): SupportedLocale {
  const userId = ctx.from?.id;
  if (userId) {
    const state = userState.get(userId);
    if (state?.locale) {
      return state.locale;
    }
  }
  return detectLocaleFromTelegram(ctx);
}

function getUserState(userId: number): UserState {
  const existing = userState.get(userId);
  if (existing) {
    return existing;
  }
  const initial: UserState = {
    activeSubscription: false,
    selectedPlan: null,
    locale: null,
    pendingStartPayload: null,
  };
  userState.set(userId, initial);
  return initial;
}

async function sendLanguagePicker(ctx: Context): Promise<void> {
  await ctx.reply(STRINGS.ru.languagePrompt, {
    reply_markup: buildLanguageKeyboard(),
  });
}

function buildSubscriptionKeyboard(locale: SupportedLocale): InlineKeyboard {
  const labels = STRINGS[locale].planLabels;
  const backLabel = STRINGS[locale].menuButtons.back;
  return new InlineKeyboard()
    .text(labels.week, "plan:week")
    .text(labels.month, "plan:month")
    .text(labels.year, "plan:year")
    .row()
    .text(backLabel, "menu:home");
}

async function sendProfessionalReadingOffer(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const text = `${strings.professionalTitle}\n\n${strings.professionalDescription}`;
  await ctx.reply(text, { reply_markup: buildSubscriptionKeyboard(locale) });
}

async function sendMainMenu(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const lines = [strings.menuTitle, strings.menuDescription];
  if (!config.webAppUrl) {
    console.error(
      "TELEGRAM_WEBAPP_URL is missing; Launch app button disabled.",
    );
    lines.push("", strings.launchUnavailable);
  }
  await ctx.reply(lines.join("\n"), {
    reply_markup: buildMainMenuKeyboard(locale),
  });
}

async function sendAbout(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  await ctx.reply(strings.aboutText, {
    reply_markup: new InlineKeyboard().text(
      strings.menuButtons.back,
      "menu:home",
    ),
  });
}

function parseWebAppAction(data: string): string | null {
  const trimmed = data.trim();
  if (!trimmed) {
    return null;
  }
  if (trimmed === "professional_reading") {
    return trimmed;
  }
  try {
    const parsed = JSON.parse(trimmed) as { action?: string } | null;
    if (parsed?.action) {
      return parsed.action;
    }
  } catch (_) {
    return null;
  }
  return null;
}

const webAppDebounceMs = 3000;
const lastWebAppActionAt = new Map<number, number>();

function shouldHandleWebAppAction(userId: number): boolean {
  const now = Date.now();
  const last = lastWebAppActionAt.get(userId) ?? 0;
  if (now - last < webAppDebounceMs) {
    return false;
  }
  lastWebAppActionAt.set(userId, now);
  return true;
}

async function startPaymentFlow(
  ctx: Context,
  locale: SupportedLocale,
): Promise<void> {
  // TODO: Wire to the existing payment/subscription flow when available.
  await ctx.reply(STRINGS[locale].paymentStub);
}

async function sendPlans(
  ctx: Context,
  { ignoreDebounce = false }: { ignoreDebounce?: boolean } = {},
): Promise<void> {
  const userId = ctx.from?.id;
  if (!userId) {
    return;
  }
  if (!ignoreDebounce && !shouldHandleWebAppAction(userId)) {
    return;
  }
  const locale = getLocale(ctx);
  const state = getUserState(userId);
  if (state.activeSubscription) {
    await ctx.reply(STRINGS[locale].alreadyActive);
    return;
  }
  await sendProfessionalReadingOffer(ctx);
}

function parseStartPayload(ctx: Context): string | null {
  const match = (ctx.match as string | undefined)?.trim();
  if (match) {
    return match.split(/\s+/)[0] ?? null;
  }
  const text = ctx.message?.text;
  if (!text) {
    return null;
  }
  const parts = text.trim().split(/\s+/);
  if (parts.length < 2) {
    return null;
  }
  return parts[1] ?? null;
}

async function sendLauncherMessage(ctx: Context): Promise<void> {
  await sendMainMenu(ctx);
}

async function main(): Promise<void> {
  const bot = new Bot(config.telegramToken);

  bot.command("start", async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await sendLauncherMessage(ctx);
      return;
    }
    const state = getUserState(userId);
    const payload = parseStartPayload(ctx);
    if (!state.locale) {
      state.pendingStartPayload = payload;
      await sendLanguagePicker(ctx);
      return;
    }
    if (payload === "plans") {
      await sendPlans(ctx, { ignoreDebounce: true });
      return;
    }
    await sendLauncherMessage(ctx);
  });

  bot.command("help", async (ctx) => {
    const userId = ctx.from?.id;
    if (userId) {
      const state = getUserState(userId);
      if (!state.locale) {
        await sendLanguagePicker(ctx);
        return;
      }
    }
    await sendMainMenu(ctx);
  });

  bot.command("chatid", async (ctx) => {
    const chatId = ctx.chat?.id;
    const userId = ctx.from?.id;
    const username = ctx.from?.username ? `@${ctx.from.username}` : "-";
    await ctx.reply(
      `chat_id: ${chatId ?? "-"}\nuser_id: ${userId ?? "-"}\nusername: ${username}`,
    );
  });

  bot.callbackQuery(/^lang:(ru|en|kk)$/, async (ctx) => {
    await ctx.answerCallbackQuery();
    const userId = ctx.from?.id;
    if (!userId) {
      await sendMainMenu(ctx);
      return;
    }
    const state = getUserState(userId);
    state.locale = ctx.match[1] as SupportedLocale;
    const pending = state.pendingStartPayload;
    state.pendingStartPayload = null;
    if (pending === "plans") {
      await sendPlans(ctx, { ignoreDebounce: true });
      return;
    }
    await sendMainMenu(ctx);
  });

  bot.on("message:web_app_data", async (ctx) => {
    const data = ctx.message.web_app_data?.data ?? "";
    const action = parseWebAppAction(data);
    if (action !== "professional_reading" && action !== "show_plans") {
      return;
    }
    await sendPlans(ctx);
  });

  bot.callbackQuery("menu:buy", async (ctx) => {
    await ctx.answerCallbackQuery();
    await sendPlans(ctx, { ignoreDebounce: true });
  });

  bot.callbackQuery("menu:about", async (ctx) => {
    await ctx.answerCallbackQuery();
    await sendAbout(ctx);
  });

  bot.callbackQuery("menu:home", async (ctx) => {
    await ctx.answerCallbackQuery();
    await sendMainMenu(ctx);
  });

  bot.callbackQuery(/^plan:(week|month|year)$/, async (ctx) => {
    await ctx.answerCallbackQuery();
    const userId = ctx.from?.id;
    if (!userId) {
      return;
    }
    const locale = getLocale(ctx);
    const state = getUserState(userId);
    if (state.activeSubscription) {
      await ctx.reply(STRINGS[locale].alreadyActive);
      return;
    }
    const plan = ctx.match[1] as PlanId;
    if (state.selectedPlan === plan) {
      await ctx.reply(STRINGS[locale].planAlreadySelected);
      return;
    }
    state.selectedPlan = plan;
    await startPaymentFlow(ctx, locale);
  });

  bot.on("message:text", async (ctx) => {
    const userId = ctx.from?.id;
    if (userId) {
      const state = getUserState(userId);
      if (!state.locale) {
        await sendLanguagePicker(ctx);
        return;
      }
    }
    await sendMainMenu(ctx);
  });

  bot.catch((err) => {
    console.error("Bot error", err.error);
  });

  await bot.start({
    allowed_updates: ["message", "callback_query"],
  });
  console.log("Telegram bot started.");
}

main().catch((error) => {
  console.error("Startup failure", error);
  process.exit(1);
});
