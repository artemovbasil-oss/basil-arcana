import { Bot, InlineKeyboard, type Context } from "grammy";
import { loadConfig } from "./config";

const config = loadConfig();

type SupportedLocale = "ru" | "en" | "kk";
type PlanId = "single" | "week" | "month" | "year";

interface Plan {
  id: PlanId;
  stars: number;
  durationDays: number;
  isSingleUse: boolean;
}

interface UserState {
  activeSubscription: boolean;
  selectedPlan: PlanId | null;
  locale: SupportedLocale | null;
  pendingStartPayload: string | null;
  subscriptionEndsAt: number | null;
}

interface LocalizedPlan {
  label: string;
  notifyLabel: string;
  fiatPriceDisplay: string;
}

const SOFIA_PROFILE_URL = "https://t.me/SofiaKnoxx";
const TELEGRAM_STARS_CURRENCY = "XTR";
const PURCHASE_CODE_LENGTH = 6;
const PURCHASE_CODE_TTL_DAYS = 30;

const PLANS: Record<PlanId, Plan> = {
  single: {
    id: "single",
    stars: 140,
    durationDays: PURCHASE_CODE_TTL_DAYS,
    isSingleUse: true,
  },
  week: {
    id: "week",
    stars: 275,
    durationDays: 7,
    isSingleUse: false,
  },
  month: {
    id: "month",
    stars: 550,
    durationDays: 30,
    isSingleUse: false,
  },
  year: {
    id: "year",
    stars: 3900,
    durationDays: 365,
    isSingleUse: false,
  },
};

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
    planLabels: Record<PlanId, LocalizedPlan>;
    planAlreadySelected: string;
    invoiceTitle: string;
    invoiceDescription: string;
    paymentPrompt: string;
    paymentCancelled: string;
    paymentSuccess: string;
    activationUntil: string;
    codeInstruction: string;
    sofiaNotifyTitle: string;
    sofiaContactCard: string;
    missingSofiaChatWarn: string;
    unknownPaymentPlan: string;
  }
> = {
  ru: {
    menuTitle: "Добро пожаловать в Basil’s Arcana ✨",
    menuDescription: "Выбери действие из меню ниже.",
    menuButtons: {
      launchApp: "🚀 Запустить мини‑приложение",
      buy: "💳 Купить разбор/подписку",
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
      "✨ Чем мы можем быть полезны\n\nВ приложении Basil’s Arcana:\n• Расклады на 1, 3 и 5 карт под твой запрос.\n• Глубокий анализ в разрезе карьеры и отношений.\n• Персональные подсказки и понятные шаги по ситуации.\n• Мини‑приложение с атмосферой и интерактивными картами.\n\n🔮 Наш таролог и астролог София\n• Детально разбирает расклады и натальные карты.\n• Помогает дойти до практичного решения без воды.",
    professionalTitle: "🔮 Детальный разбор с Софией",
    professionalDescription:
      "Оформи доступ к детальному разбору раскладов и натальных карт нашим тарологом/астрологом Софией.",
    planLabels: {
      single: {
        label: "1 разбор — 250 ₽ / 140 ⭐",
        notifyLabel: "Разовый детальный разбор",
        fiatPriceDisplay: "250 ₽",
      },
      week: {
        label: "Неделя — 490 ₽ / 275 ⭐",
        notifyLabel: "Подписка на неделю",
        fiatPriceDisplay: "490 ₽",
      },
      month: {
        label: "Месяц — 990 ₽ / 550 ⭐",
        notifyLabel: "Подписка на месяц",
        fiatPriceDisplay: "990 ₽",
      },
      year: {
        label: "Год — 6 990 ₽ / 3900 ⭐",
        notifyLabel: "Подписка на год",
        fiatPriceDisplay: "6 990 ₽",
      },
    },
    planAlreadySelected: "Тариф уже выбран.",
    invoiceTitle: "Basil’s Arcana • Оплата",
    invoiceDescription:
      "Детальный разбор раскладов и натальных карт от Софии.",
    paymentPrompt: "Выбери вариант ниже, бот пришлет счет в Telegram Stars.",
    paymentCancelled: "Оплата не прошла. Попробуй еще раз.",
    paymentSuccess: "Оплата принята ✅",
    activationUntil: "Активно до",
    codeInstruction:
      "Твой код доступа: {code}\n\nНапиши Софии и передай этот код для подтверждения:\n{sofia}\n\nПодсказка: код одноразовый для проверки покупки.",
    sofiaNotifyTitle: "🧾 Новая покупка в Basil’s Arcana",
    sofiaContactCard:
      "👩‍💼 Контакт Софии\n• София Нокс — таролог/астролог\n• Telegram: @SofiaKnoxx\n• Написать: https://t.me/SofiaKnoxx",
    missingSofiaChatWarn:
      "Оплата прошла, но уведомление Софии не отправлено автоматически. Напиши ей и отправь код вручную: https://t.me/SofiaKnoxx",
    unknownPaymentPlan: "Не удалось определить тариф оплаты.",
  },
  en: {
    menuTitle: "Welcome to Basil’s Arcana ✨",
    menuDescription: "Choose an action from the menu below.",
    menuButtons: {
      launchApp: "🚀 Launch app",
      buy: "💳 Buy reading/subscription",
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
      "✨ How we can help\n\nInside Basil’s Arcana:\n• Spreads with 1, 3, and 5 cards for your exact question.\n• Deep analysis focused on career and relationships.\n• Personalized guidance with clear next steps.\n• Atmospheric mini app with interactive cards.\n\n🔮 Our tarot reader and astrologer Sofia\n• Provides detailed interpretation of spreads and natal charts.\n• Helps turn insight into practical decisions.",
    professionalTitle: "🔮 Detailed reading with Sofia",
    professionalDescription:
      "Get detailed spread and natal-chart interpretation from our tarot reader/astrologer Sofia.",
    planLabels: {
      single: {
        label: "1 reading — $2.99 / 140 ⭐",
        notifyLabel: "Single detailed reading",
        fiatPriceDisplay: "$2.99",
      },
      week: {
        label: "Week — $5.99 / 275 ⭐",
        notifyLabel: "Weekly subscription",
        fiatPriceDisplay: "$5.99",
      },
      month: {
        label: "Month — $11.99 / 550 ⭐",
        notifyLabel: "Monthly subscription",
        fiatPriceDisplay: "$11.99",
      },
      year: {
        label: "Year — $84.99 / 3900 ⭐",
        notifyLabel: "Yearly subscription",
        fiatPriceDisplay: "$84.99",
      },
    },
    planAlreadySelected: "Plan already selected.",
    invoiceTitle: "Basil’s Arcana • Payment",
    invoiceDescription:
      "Detailed spread and natal-chart interpretation by Sofia.",
    paymentPrompt: "Choose an option below and the bot will send a Telegram Stars invoice.",
    paymentCancelled: "Payment failed. Please try again.",
    paymentSuccess: "Payment received ✅",
    activationUntil: "Active until",
    codeInstruction:
      "Your access code: {code}\n\nSend this code to Sofia for verification:\n{sofia}\n\nTip: this is a one-time verification code.",
    sofiaNotifyTitle: "🧾 New purchase in Basil’s Arcana",
    sofiaContactCard:
      "👩‍💼 Sofia contact\n• Sofia Knox — tarot reader/astrologer\n• Telegram: @SofiaKnoxx\n• Message: https://t.me/SofiaKnoxx",
    missingSofiaChatWarn:
      "Payment is complete, but Sofia was not notified automatically. Please message Sofia and send the code manually: https://t.me/SofiaKnoxx",
    unknownPaymentPlan: "Could not determine payment plan.",
  },
  kk: {
    menuTitle: "Basil’s Arcana-ға қош келдің ✨",
    menuDescription: "Төмендегі мәзірден әрекет таңда.",
    menuButtons: {
      launchApp: "🚀 Мини‑қосымшаны ашу",
      buy: "💳 Талдау/жазылым сатып алу",
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
      "✨ Қалай көмектесе аламыз\n\nBasil’s Arcana ішінде:\n• Сұрағыңа сай 1, 3 және 5 карталық раскладтар.\n• Мансап пен қарым‑қатынас бағыты бойынша терең талдау.\n• Нақты келесі қадамдары бар жеке кеңес.\n• Атмосферасы бар интерактивті мини‑қосымша.\n\n🔮 Біздің таролог және астролог София\n• Расклад пен натал картаны егжей‑тегжейлі талдайды.\n• Инсайтты нақты шешімге айналдыруға көмектеседі.",
    professionalTitle: "🔮 Софиямен терең талдау",
    professionalDescription:
      "Раскладтар мен натал карталар бойынша кәсіби талдауды таролог/астролог Софиядан алыңыз.",
    planLabels: {
      single: {
        label: "1 талдау — 1 300 ₸ / 140 ⭐",
        notifyLabel: "Бір реттік терең талдау",
        fiatPriceDisplay: "1 300 ₸",
      },
      week: {
        label: "Апта — 2 550 ₸ / 275 ⭐",
        notifyLabel: "Апталық жазылым",
        fiatPriceDisplay: "2 550 ₸",
      },
      month: {
        label: "Ай — 5 150 ₸ / 550 ⭐",
        notifyLabel: "Айлық жазылым",
        fiatPriceDisplay: "5 150 ₸",
      },
      year: {
        label: "Жыл — 36 400 ₸ / 3900 ⭐",
        notifyLabel: "Жылдық жазылым",
        fiatPriceDisplay: "36 400 ₸",
      },
    },
    planAlreadySelected: "Тариф таңдалды.",
    invoiceTitle: "Basil’s Arcana • Төлем",
    invoiceDescription: "Софиядан расклад және натал карта бойынша терең талдау.",
    paymentPrompt: "Төменнен таңдаңыз, бот Telegram Stars шотын жібереді.",
    paymentCancelled: "Төлем өтпеді. Қайталап көріңіз.",
    paymentSuccess: "Төлем қабылданды ✅",
    activationUntil: "Белсенді мерзімі",
    codeInstruction:
      "Қолжетімділік коды: {code}\n\nРастау үшін осы кодты Софияға жіберіңіз:\n{sofia}\n\nКеңес: бұл сатып алуды тексеруге арналған бір реттік код.",
    sofiaNotifyTitle: "🧾 Basil’s Arcana ішіндегі жаңа сатып алу",
    sofiaContactCard:
      "👩‍💼 София байланысы\n• София Нокс — таролог/астролог\n• Telegram: @SofiaKnoxx\n• Жазу: https://t.me/SofiaKnoxx",
    missingSofiaChatWarn:
      "Төлем өтті, бірақ Софияға автоматты хабарлама жіберілмеді. Кодты Софияға қолмен жіберіңіз: https://t.me/SofiaKnoxx",
    unknownPaymentPlan: "Төлем тарифін анықтау мүмкін болмады.",
  },
};

const userState = new Map<number, UserState>();
const issuedCodes = new Set<string>();
const processedPayments = new Set<string>();

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
    subscriptionEndsAt: null,
  };
  userState.set(userId, initial);
  return initial;
}

function parsePlanId(value: string): PlanId | null {
  if (value === "single" || value === "week" || value === "month" || value === "year") {
    return value;
  }
  return null;
}

function paymentPayload(plan: PlanId): string {
  return `purchase:${plan}`;
}

function parsePlanFromPayload(payload: string): PlanId | null {
  if (!payload.startsWith("purchase:")) {
    return null;
  }
  const rawPlan = payload.replace("purchase:", "").trim();
  return parsePlanId(rawPlan);
}

function formatDateForLocale(date: Date, locale: SupportedLocale): string {
  const localeMap: Record<SupportedLocale, string> = {
    ru: "ru-RU",
    kk: "kk-KZ",
    en: "en-US",
  };
  return new Intl.DateTimeFormat(localeMap[locale], {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);
}

function addDays(now: Date, days: number): Date {
  const next = new Date(now);
  next.setDate(next.getDate() + days);
  return next;
}

function generatePurchaseCode(): string {
  for (let i = 0; i < 24; i += 1) {
    const value = Math.floor(100000 + Math.random() * 900000).toString();
    if (!issuedCodes.has(value)) {
      issuedCodes.add(value);
      return value;
    }
  }
  const fallback = `${Date.now()}`.slice(-PURCHASE_CODE_LENGTH);
  issuedCodes.add(fallback);
  return fallback;
}

function buildSubscriptionKeyboard(locale: SupportedLocale): InlineKeyboard {
  const labels = STRINGS[locale].planLabels;
  const backLabel = STRINGS[locale].menuButtons.back;
  return new InlineKeyboard()
    .text(labels.single.label, "plan:single")
    .row()
    .text(labels.week.label, "plan:week")
    .row()
    .text(labels.month.label, "plan:month")
    .row()
    .text(labels.year.label, "plan:year")
    .row()
    .text(backLabel, "menu:home");
}

async function sendLanguagePicker(ctx: Context): Promise<void> {
  await ctx.reply(STRINGS.ru.languagePrompt, {
    reply_markup: buildLanguageKeyboard(),
  });
}

async function sendProfessionalReadingOffer(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const text = `${strings.professionalTitle}\n\n${strings.professionalDescription}\n\n${strings.paymentPrompt}`;
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
  await ctx.reply(`${strings.aboutText}\n\n${strings.sofiaContactCard}`, {
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

async function startPaymentFlow(ctx: Context, planId: PlanId): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const plan = PLANS[planId];
  const localizedPlan = strings.planLabels[planId];

  await ctx.replyWithInvoice(
    strings.invoiceTitle,
    `${strings.invoiceDescription}\n${localizedPlan.label}`,
    paymentPayload(planId),
    TELEGRAM_STARS_CURRENCY,
    [{ label: localizedPlan.notifyLabel, amount: plan.stars }],
  );
}

async function notifySofia(
  ctx: Context,
  planId: PlanId,
  purchaseCode: string,
  expiresAt: Date,
): Promise<boolean> {
  const sofiaChatId = config.sofiaChatId;
  if (!sofiaChatId) {
    console.error("SOFIA_CHAT_ID is missing; Sofia notification was skipped.");
    return false;
  }

  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const user = ctx.from;
  const username = user?.username ? `@${user.username}` : "-";
  const firstName = user?.first_name?.trim() || "-";
  const lastName = user?.last_name?.trim() || "-";
  const userId = user?.id ?? "-";

  const plan = PLANS[planId];
  const label = strings.planLabels[planId].notifyLabel;
  const fiatPrice = strings.planLabels[planId].fiatPriceDisplay;
  const expires = formatDateForLocale(expiresAt, "ru");

  const text = [
    strings.sofiaNotifyTitle,
    "",
    `Пользователь: ${username}`,
    `Имя: ${firstName}`,
    `Фамилия: ${lastName}`,
    `User ID: ${userId}`,
    `Язык: ${locale}`,
    "",
    `Покупка: ${label}`,
    `Стоимость: ${fiatPrice} / ${plan.stars} ⭐`,
    `Активно до: ${expires}`,
    `Код: ${purchaseCode}`,
  ].join("\n");

  await ctx.api.sendMessage(sofiaChatId, text);
  return true;
}

function applyPurchasedPlan(userId: number, planId: PlanId, expiresAt: Date): void {
  const state = getUserState(userId);
  state.selectedPlan = planId;
  if (!PLANS[planId].isSingleUse) {
    state.activeSubscription = true;
    state.subscriptionEndsAt = expiresAt.getTime();
  }
}

async function handleSuccessfulPayment(ctx: Context): Promise<void> {
  const userId = ctx.from?.id;
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  if (!userId) {
    return;
  }

  const payment = ctx.message?.successful_payment;
  if (!payment) {
    return;
  }

  if (processedPayments.has(payment.telegram_payment_charge_id)) {
    return;
  }

  const planId = parsePlanFromPayload(payment.invoice_payload);
  if (!planId) {
    await ctx.reply(strings.unknownPaymentPlan);
    return;
  }

  const plan = PLANS[planId];
  if (payment.currency !== TELEGRAM_STARS_CURRENCY || payment.total_amount !== plan.stars) {
    await ctx.reply(strings.paymentCancelled);
    return;
  }

  processedPayments.add(payment.telegram_payment_charge_id);

  const now = new Date();
  const expiresAt = addDays(now, plan.durationDays);
  applyPurchasedPlan(userId, planId, expiresAt);

  const code = generatePurchaseCode();
  const expiresText = formatDateForLocale(expiresAt, locale);
  const instruction = strings.codeInstruction
    .replace("{code}", code)
    .replace("{sofia}", SOFIA_PROFILE_URL);

  await ctx.reply(
    `${strings.paymentSuccess}\n${strings.activationUntil}: ${expiresText}\n\n${instruction}`,
  );

  const notified = await notifySofia(ctx, planId, code, expiresAt);
  if (!notified) {
    await ctx.reply(strings.missingSofiaChatWarn);
  }
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

  bot.callbackQuery(/^plan:(single|week|month|year)$/, async (ctx) => {
    await ctx.answerCallbackQuery();
    const userId = ctx.from?.id;
    if (!userId) {
      return;
    }

    const planId = parsePlanId(ctx.match[1]);
    if (!planId) {
      return;
    }

    const state = getUserState(userId);
    state.selectedPlan = planId;
    await startPaymentFlow(ctx, planId);
  });

  bot.on("pre_checkout_query", async (ctx) => {
    const query = ctx.preCheckoutQuery;
    if (!query) {
      return;
    }

    const planId = parsePlanFromPayload(query.invoice_payload);
    if (!planId) {
      await ctx.answerPreCheckoutQuery(false, {
        error_message: STRINGS[getLocale(ctx)].unknownPaymentPlan,
      });
      return;
    }

    const plan = PLANS[planId];
    if (query.currency !== TELEGRAM_STARS_CURRENCY || query.total_amount !== plan.stars) {
      await ctx.answerPreCheckoutQuery(false, {
        error_message: STRINGS[getLocale(ctx)].paymentCancelled,
      });
      return;
    }

    await ctx.answerPreCheckoutQuery(true);
  });

  bot.on("message:successful_payment", async (ctx) => {
    await handleSuccessfulPayment(ctx);
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
    allowed_updates: ["message", "callback_query", "pre_checkout_query"],
  });
  console.log("Telegram bot started.");
}

main().catch((error) => {
  console.error("Startup failure", error);
  process.exit(1);
});
