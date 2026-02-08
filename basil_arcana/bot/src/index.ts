import { Bot, InlineKeyboard, type Context } from "grammy";
import { loadConfig } from "./config";

const config = loadConfig();

const WELCOME_TEXT =
  "Welcome to Basil’s Arcana. Tap below to open the mini app.";
const HELP_TEXT =
  "Use the button below to open the Basil’s Arcana mini app inside Telegram.";
const NUDGE_TEXT = "Open Basil’s Arcana from the button below.";

type SupportedLocale = "ru" | "en" | "kk";
type PlanId = "week" | "month" | "year";

interface UserState {
  activeSubscription: boolean;
  selectedPlan: PlanId | null;
}

const STRINGS: Record<
  SupportedLocale,
  {
    professionalTitle: string;
    professionalDescription: string;
    planLabels: Record<PlanId, string>;
    alreadyActive: string;
    planAlreadySelected: string;
    paymentStub: string;
  }
> = {
  ru: {
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
    paymentStub:
      "Оплата пока не настроена. Мы сохранили твой выбор и скоро продолжим.",
  },
  en: {
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
    paymentStub:
      "Payments are not set up yet. We saved your choice and will continue soon.",
  },
  kk: {
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
    paymentStub:
      "Төлем әзірге бапталмаған. Таңдауың сақталды, жақында жалғастырамыз.",
  },
};

const userState = new Map<number, UserState>();

function buildKeyboard(): InlineKeyboard {
  return new InlineKeyboard().webApp("Open Basil’s Arcana", config.webAppUrl);
}

function getLocale(ctx: Context): SupportedLocale {
  const code = ctx.from?.language_code?.toLowerCase() ?? "";
  if (code.startsWith("kk") || code.startsWith("kz")) {
    return "kk";
  }
  if (code.startsWith("en")) {
    return "en";
  }
  return "ru";
}

function getUserState(userId: number): UserState {
  const existing = userState.get(userId);
  if (existing) {
    return existing;
  }
  const initial: UserState = {
    activeSubscription: false,
    selectedPlan: null,
  };
  userState.set(userId, initial);
  return initial;
}

function buildSubscriptionKeyboard(locale: SupportedLocale): InlineKeyboard {
  const labels = STRINGS[locale].planLabels;
  return new InlineKeyboard()
    .text(labels.week, "plan:week")
    .row()
    .text(labels.month, "plan:month")
    .row()
    .text(labels.year, "plan:year");
}

async function sendProfessionalReadingOffer(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const text = `${strings.professionalTitle}\n\n${strings.professionalDescription}`;
  await ctx.reply(text, { reply_markup: buildSubscriptionKeyboard(locale) });
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

async function startPaymentFlow(
  ctx: Context,
  locale: SupportedLocale,
): Promise<void> {
  // TODO: Wire to the existing payment/subscription flow when available.
  await ctx.reply(STRINGS[locale].paymentStub);
}

async function sendLauncherMessage(ctx: Context): Promise<void> {
  await ctx.reply(WELCOME_TEXT, { reply_markup: buildKeyboard() });
}

async function main(): Promise<void> {
  const bot = new Bot(config.telegramToken);

  bot.command("start", async (ctx) => {
    await sendLauncherMessage(ctx);
  });

  bot.command("help", async (ctx) => {
    await ctx.reply(HELP_TEXT, { reply_markup: buildKeyboard() });
  });

  bot.on("message:web_app_data", async (ctx) => {
    const data = ctx.message.web_app_data?.data ?? "";
    const action = parseWebAppAction(data);
    if (action !== "professional_reading") {
      return;
    }
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
    await sendProfessionalReadingOffer(ctx);
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
    await ctx.reply(NUDGE_TEXT, { reply_markup: buildKeyboard() });
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
