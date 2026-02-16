import { Bot, InlineKeyboard, type Context } from "grammy";
import { loadConfig } from "./config";
import {
  completeConsultation,
  ensureSchema,
  getUserLocale,
  getUserSubscription,
  initDb,
  insertFunnelEvent,
  insertPayment,
  listActiveSubscriptions,
  listRecentUserQueriesForUser,
  listUsersCreatedTodayForSofia,
  listUsersForBroadcast,
  listUsersForSofia,
  paymentExists,
  saveUserSubscription,
  upsertUserProfile,
  type DbLocale,
  type UserSubscriptionRecord,
} from "./db";

const config = loadConfig();

type SupportedLocale = "ru" | "en" | "kk";
type PlanId = "single" | "week" | "month" | "year";

interface Plan {
  id: PlanId;
  stars: number;
  durationDays: number;
  isSingleUse: boolean;
}

interface LocalizedPlan {
  label: string;
  notifyLabel: string;
  fiatPriceDisplay: string;
}

interface UserState {
  locale: SupportedLocale | null;
  pendingStartPayload: string | null;
  selectedPlan: PlanId | null;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
}

const SOFIA_PROFILE_URL = "https://t.me/SofiaKnoxx";
const TELEGRAM_STARS_CURRENCY = "XTR";
const PURCHASE_CODE_LENGTH = 6;
const DAY_MS = 24 * 60 * 60 * 1000;
const MINI_APP_VERSION_TAG = "20260214-novideo";

const PLANS: Record<PlanId, Plan> = {
  single: {
    id: "single",
    stars: 140,
    durationDays: 1,
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
      language: string;
      back: string;
      subscriptions: string;
    };
    languagePrompt: string;
    languageButtons: Record<SupportedLocale, string>;
    launchUnavailable: string;
    aboutText: string;
    professionalTitle: string;
    professionalDescription: string;
    planLabels: Record<PlanId, LocalizedPlan>;
    invoiceTitle: string;
    invoiceDescription: string;
    paymentPrompt: string;
    paymentCancelled: string;
    paymentSuccess: string;
    activationUntil: string;
    codeInstruction: string;
    sofiaNotifyTitle: string;
    sofiaContactCard: string;
    contactSofiaButton: string;
    contactSofiaDoneButton: string;
    contactSofiaDoneAck: string;
    sofiaMessageTemplate: string;
    missingSofiaChatWarn: string;
    unknownPaymentPlan: string;
    subscriptionsTitle: string;
    subscriptionsNone: string;
    subscriptionsUntil: string;
    subscriptionsSingleLeft: string;
    subscriptionsPlansCount: string;
  }
> = {
  ru: {
    menuTitle: "Добро пожаловать в The Real Magic Bot ✨",
    menuDescription: "Выбери действие из меню ниже.",
    menuButtons: {
      launchApp: "🚀 Запустить мини‑приложение",
      buy: "💳 Купить разбор/подписку",
      about: "✨ Чем мы можем быть полезны",
      language: "🌐 Сменить язык",
      back: "⬅️ В меню",
      subscriptions: "📦 Мои активные подписки",
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
      "✨ Чем мы можем быть полезны\n\nЕсли ты в ситуации неопределенности, мы поможем перейти к ясному плану действий.\n\nЧто получаешь:\n• Точный разбор запроса на 1, 3 или 5 карт.\n• Конкретные шаги по отношениям, карьере и личным решениям.\n• Приоритетный детальный разбор от Софии (таролог + астролог).\n\nПочему это работает:\n• Без общих фраз, только прикладные выводы.\n• Понятный формат: что происходит, почему, что делать дальше.\n• Можно начать с мини‑приложения или сразу перейти к платному разбору.",
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
    contactSofiaButton: "✉️ Написать Софии с кодом",
    contactSofiaDoneButton: "✅ Я отправил(а) код Софии",
    contactSofiaDoneAck: "Отлично, София свяжется с тобой после проверки кода.",
    sofiaMessageTemplate:
      "Здравствуйте! Я оплатил(а) консультацию в Basil’s Arcana. Код доступа: {code}",
    missingSofiaChatWarn:
      "Оплата прошла, но уведомление Софии не отправлено автоматически. Напиши ей и отправь код вручную: https://t.me/SofiaKnoxx",
    unknownPaymentPlan: "Не удалось определить тариф оплаты.",
    subscriptionsTitle: "📦 Твои активные подписки",
    subscriptionsNone: "У тебя сейчас нет активных подписок.",
    subscriptionsUntil: "Активно до",
    subscriptionsSingleLeft: "Осталось разовых разборов",
    subscriptionsPlansCount: "Куплено пакетов",
  },
  en: {
    menuTitle: "Welcome to Basil’s Arcana ✨",
    menuDescription: "Choose an action from the menu below.",
    menuButtons: {
      launchApp: "🚀 Launch app",
      buy: "💳 Buy reading/subscription",
      about: "✨ How we can help",
      language: "🌐 Change language",
      back: "⬅️ Back to menu",
      subscriptions: "📦 My active subscriptions",
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
      "✨ How we can help\n\nIf you are stuck or unsure, we help you turn uncertainty into a clear action plan.\n\nWhat you get:\n• Precise readings for your exact question (1, 3, or 5 cards).\n• Practical next steps for relationships, career, and personal decisions.\n• Priority deep interpretation by Sofia (tarot reader + astrologer).\n\nWhy users choose us:\n• No vague wording, only actionable conclusions.\n• Clear structure: what is happening, why, what to do next.\n• You can start in the mini app or go straight to a paid deep reading.",
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
    invoiceTitle: "Basil’s Arcana • Payment",
    invoiceDescription:
      "Detailed spread and natal-chart interpretation by Sofia.",
    paymentPrompt:
      "Choose an option below and the bot will send a Telegram Stars invoice.",
    paymentCancelled: "Payment failed. Please try again.",
    paymentSuccess: "Payment received ✅",
    activationUntil: "Active until",
    codeInstruction:
      "Your access code: {code}\n\nSend this code to Sofia for verification:\n{sofia}\n\nTip: this is a one-time verification code.",
    sofiaNotifyTitle: "🧾 New purchase in Basil’s Arcana",
    sofiaContactCard:
      "👩‍💼 Sofia contact\n• Sofia Knox — tarot reader/astrologer\n• Telegram: @SofiaKnoxx\n• Message: https://t.me/SofiaKnoxx",
    contactSofiaButton: "✉️ Message Sofia with code",
    contactSofiaDoneButton: "✅ I sent Sofia the code",
    contactSofiaDoneAck: "Great, Sofia will contact you after code verification.",
    sofiaMessageTemplate:
      "Hi! I paid for a consultation in Basil’s Arcana. My access code is {code}",
    missingSofiaChatWarn:
      "Payment is complete, but Sofia was not notified automatically. Please message Sofia and send the code manually: https://t.me/SofiaKnoxx",
    unknownPaymentPlan: "Could not determine payment plan.",
    subscriptionsTitle: "📦 Your active subscriptions",
    subscriptionsNone: "You currently have no active subscriptions.",
    subscriptionsUntil: "Active until",
    subscriptionsSingleLeft: "Single readings left",
    subscriptionsPlansCount: "Purchased packs",
  },
  kk: {
    menuTitle: "Basil’s Arcana-ға қош келдің ✨",
    menuDescription: "Төмендегі мәзірден әрекет таңда.",
    menuButtons: {
      launchApp: "🚀 Мини‑қосымшаны ашу",
      buy: "💳 Талдау/жазылым сатып алу",
      about: "✨ Қалай көмектесе аламыз",
      language: "🌐 Тілді өзгерту",
      back: "⬅️ Мәзірге",
      subscriptions: "📦 Белсенді жазылымдарым",
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
      "✨ Қалай көмектесе аламыз\n\nЕгер шешім қабылдау қиын болса, біз белгісіздікті нақты әрекет жоспарына айналдырамыз.\n\nНе аласыз:\n• Сұрағыңызға дәл расклад (1, 3 немесе 5 карта).\n• Қарым‑қатынас, мансап және жеке шешімдерге арналған нақты қадамдар.\n• Софиядан (таролог + астролог) терең кәсіби талдау.\n\nНеге тиімді:\n• Жалпы сөздерсіз, тек қолданбалы қорытынды.\n• Түсінікті формат: не болып жатыр, неге, әрі қарай не істеу керек.\n• Мини‑қосымшадан бастауға немесе бірден терең талдауға өтуге болады.",
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
    invoiceTitle: "Basil’s Arcana • Төлем",
    invoiceDescription:
      "Софиядан расклад және натал карта бойынша терең талдау.",
    paymentPrompt: "Төменнен таңдаңыз, бот Telegram Stars шотын жібереді.",
    paymentCancelled: "Төлем өтпеді. Қайталап көріңіз.",
    paymentSuccess: "Төлем қабылданды ✅",
    activationUntil: "Белсенді мерзімі",
    codeInstruction:
      "Қолжетімділік коды: {code}\n\nРастау үшін осы кодты Софияға жіберіңіз:\n{sofia}\n\nКеңес: бұл сатып алуды тексеруге арналған бір реттік код.",
    sofiaNotifyTitle: "🧾 Basil’s Arcana ішіндегі жаңа сатып алу",
    sofiaContactCard:
      "👩‍💼 София байланысы\n• София Нокс — таролог/астролог\n• Telegram: @SofiaKnoxx\n• Жазу: https://t.me/SofiaKnoxx",
    contactSofiaButton: "✉️ Кодпен Софияға жазу",
    contactSofiaDoneButton: "✅ Кодты Софияға жібердім",
    contactSofiaDoneAck: "Тамаша, код тексерілгеннен кейін София сізбен байланысады.",
    sofiaMessageTemplate:
      "Сәлеметсіз бе! Basil’s Arcana ішінде консультация төледім. Қолжетімділік кодым: {code}",
    missingSofiaChatWarn:
      "Төлем өтті, бірақ Софияға автоматты хабарлама жіберілмеді. Кодты Софияға қолмен жіберіңіз: https://t.me/SofiaKnoxx",
    unknownPaymentPlan: "Төлем тарифін анықтау мүмкін болмады.",
    subscriptionsTitle: "📦 Белсенді жазылымдарыңыз",
    subscriptionsNone: "Қазір белсенді жазылымдарыңыз жоқ.",
    subscriptionsUntil: "Белсенді мерзімі",
    subscriptionsSingleLeft: "Бір реттік талдау қалды",
    subscriptionsPlansCount: "Сатып алынған пакеттер",
  },
};

const userState = new Map<number, UserState>();
const issuedCodes = new Set<string>();
const processedPayments = new Set<string>();
const sofiaAwaitingPushText = new Set<number>();

function getUserState(userId: number): UserState {
  const existing = userState.get(userId);
  if (existing) {
    return existing;
  }
  const initial: UserState = {
    locale: null,
    pendingStartPayload: null,
    selectedPlan: null,
    username: null,
    firstName: null,
    lastName: null,
  };
  userState.set(userId, initial);
  return initial;
}

function toDbLocale(locale: SupportedLocale | null): DbLocale | null {
  if (!locale) {
    return null;
  }
  return locale;
}

async function rememberUserProfile(ctx: Context): Promise<void> {
  const userId = ctx.from?.id;
  if (!userId) {
    return;
  }
  const state = getUserState(userId);
  if (!state.locale) {
    state.locale = (await getUserLocale(userId)) as SupportedLocale | null;
  }
  state.username = ctx.from?.username ?? state.username;
  state.firstName = ctx.from?.first_name ?? state.firstName;
  state.lastName = ctx.from?.last_name ?? state.lastName;
  await upsertUserProfile(
    userId,
    state.username,
    state.firstName,
    state.lastName,
    toDbLocale(state.locale),
  );
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
  return parsePlanId(payload.replace("purchase:", "").trim());
}

function isMiniAppEnergyPayload(payload: string): boolean {
  return payload.startsWith("energy:");
}

function extendSubscription(currentEndsAt: number | null, addDays: number): number {
  const now = Date.now();
  const base = currentEndsAt && currentEndsAt > now ? currentEndsAt : now;
  return base + addDays * DAY_MS;
}

function isSubscriptionActive(
  state: Pick<UserSubscriptionRecord, "subscriptionEndsAt" | "unspentSingleReadings">,
): boolean {
  const now = Date.now();
  return (state.subscriptionEndsAt ?? 0) > now || state.unspentSingleReadings > 0;
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

function buildLanguageKeyboard(): InlineKeyboard {
  const labels = STRINGS.ru.languageButtons;
  return new InlineKeyboard()
    .text(labels.ru, "lang:ru")
    .row()
    .text(labels.kk, "lang:kk")
    .row()
    .text(labels.en, "lang:en");
}

function buildLocalizedWebAppUrl(baseUrl: string, locale: SupportedLocale): string {
  try {
    const url = new URL(baseUrl);
    url.searchParams.set("lang", locale);
    url.searchParams.set("v", MINI_APP_VERSION_TAG);
    return url.toString();
  } catch (_) {
    const separator = baseUrl.includes("?") ? "&" : "?";
    return `${baseUrl}${separator}lang=${locale}&v=${MINI_APP_VERSION_TAG}`;
  }
}

function buildMainMenuKeyboard(locale: SupportedLocale, hasActiveSubs: boolean): InlineKeyboard {
  const labels = STRINGS[locale].menuButtons;
  const keyboard = new InlineKeyboard();
  if (config.webAppUrl) {
    keyboard
      .webApp(labels.launchApp, buildLocalizedWebAppUrl(config.webAppUrl, locale))
      .row();
  }
  keyboard.text(labels.buy, "menu:buy").row().text(labels.about, "menu:about");
  if (hasActiveSubs) {
    keyboard.row().text(labels.subscriptions, "menu:subscriptions");
  }
  keyboard.row().text(labels.language, "menu:language");
  return keyboard;
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

function buildBackKeyboard(locale: SupportedLocale): InlineKeyboard {
  return new InlineKeyboard().text(STRINGS[locale].menuButtons.back, "menu:home");
}

function buildAboutKeyboard(locale: SupportedLocale): InlineKeyboard {
  const labels = STRINGS[locale].menuButtons;
  const keyboard = new InlineKeyboard().text(labels.buy, "menu:buy");
  if (config.webAppUrl) {
    keyboard
      .row()
      .webApp(labels.launchApp, buildLocalizedWebAppUrl(config.webAppUrl, locale));
  }
  return keyboard.row().text(labels.back, "menu:home");
}

function buildSofiaDeepLink(message: string): string {
  const encoded = encodeURIComponent(message);
  return `${SOFIA_PROFILE_URL}?text=${encoded}`;
}

function buildSofiaContactKeyboard(locale: SupportedLocale, code: string): InlineKeyboard {
  const strings = STRINGS[locale];
  const message = strings.sofiaMessageTemplate.replace("{code}", code);
  return new InlineKeyboard()
    .url(strings.contactSofiaButton, buildSofiaDeepLink(message))
    .row()
    .text(strings.contactSofiaDoneButton, "sofia:contacted");
}

async function trackFunnelEvent(
  ctx: Context,
  eventName:
    | "start"
    | "language_selected"
    | "menu_buy_click"
    | "plan_selected"
    | "invoice_sent"
    | "precheckout_ok"
    | "payment_success"
    | "show_plans"
    | "sofia_contact_clicked",
  {
    planId = null,
    source = null,
  }: { planId?: PlanId | null; source?: string | null } = {},
): Promise<void> {
  const userId = ctx.from?.id ?? null;
  const locale = toDbLocale(getLocale(ctx));
  try {
    await insertFunnelEvent({
      telegramUserId: userId,
      eventName,
      locale,
      planId,
      source,
    });
  } catch (error) {
    console.error("Failed to track funnel event", error);
  }
}

async function sendLanguagePicker(ctx: Context): Promise<void> {
  await ctx.reply(STRINGS.ru.languagePrompt, {
    reply_markup: buildLanguageKeyboard(),
  });
}

async function sendMainMenu(ctx: Context): Promise<void> {
  await rememberUserProfile(ctx);
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const userId = ctx.from?.id;
  const subscription = userId ? await getUserSubscription(userId) : null;
  const hasActiveSubs = subscription ? isSubscriptionActive(subscription) : false;

  const lines = [strings.menuTitle, strings.menuDescription];
  if (!config.webAppUrl) {
    console.error(
      "TELEGRAM_WEBAPP_URL is missing; Launch app button disabled.",
    );
    lines.push("", strings.launchUnavailable);
  }
  await ctx.reply(lines.join("\n"), {
    reply_markup: buildMainMenuKeyboard(locale, hasActiveSubs),
  });
}

async function sendAbout(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  await ctx.reply(`${strings.aboutText}\n\n${strings.sofiaContactCard}`, {
    reply_markup: buildAboutKeyboard(locale),
  });
}

async function sendProfessionalReadingOffer(ctx: Context): Promise<void> {
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const text = `${strings.professionalTitle}\n\n${strings.professionalDescription}\n\n${strings.paymentPrompt}`;
  await ctx.reply(text, { reply_markup: buildSubscriptionKeyboard(locale) });
}

async function sendMySubscriptions(ctx: Context): Promise<void> {
  const userId = ctx.from?.id;
  if (!userId) {
    return;
  }
  const locale = getLocale(ctx);
  const strings = STRINGS[locale];
  const state = await getUserSubscription(userId);

  if (!state || !isSubscriptionActive(state)) {
    await ctx.reply(strings.subscriptionsNone, { reply_markup: buildBackKeyboard(locale) });
    return;
  }

  const endsAt = state.subscriptionEndsAt
    ? formatDateForLocale(new Date(state.subscriptionEndsAt), locale)
    : "-";

  const lines = [
    strings.subscriptionsTitle,
    "",
    `${strings.subscriptionsUntil}: ${endsAt}`,
    `${strings.subscriptionsSingleLeft}: ${state.unspentSingleReadings}`,
    `${strings.subscriptionsPlansCount}: 1d x${state.purchasedSingle}, 7d x${state.purchasedWeek}, 30d x${state.purchasedMonth}, 365d x${state.purchasedYear}`,
  ];

  await ctx.reply(lines.join("\n"), { reply_markup: buildBackKeyboard(locale) });
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
  await trackFunnelEvent(ctx, "invoice_sent", { planId });
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
  const state = ctx.from?.id ? getUserState(ctx.from.id) : null;

  const username = state?.username ? `@${state.username}` : "-";
  const firstName = state?.firstName ?? "-";
  const lastName = state?.lastName ?? "-";
  const userId = ctx.from?.id ?? "-";

  const label = strings.planLabels[planId].notifyLabel;
  const fiatPrice = strings.planLabels[planId].fiatPriceDisplay;
  const stars = PLANS[planId].stars;

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
    `Стоимость: ${fiatPrice} / ${stars} ⭐`,
    `Активно до: ${expires}`,
    `Код: ${purchaseCode}`,
  ].join("\n");

  await ctx.api.sendMessage(sofiaChatId, text);
  return true;
}

async function applyPurchasedPlan(userId: number, planId: PlanId): Promise<Date> {
  const prev = await getUserSubscription(userId);
  const nextEnds = extendSubscription(prev?.subscriptionEndsAt ?? null, PLANS[planId].durationDays);

  const next: UserSubscriptionRecord = {
    telegramUserId: userId,
    subscriptionEndsAt: nextEnds,
    unspentSingleReadings: (prev?.unspentSingleReadings ?? 0) + (PLANS[planId].isSingleUse ? 1 : 0),
    purchasedSingle: (prev?.purchasedSingle ?? 0) + (planId === "single" ? 1 : 0),
    purchasedWeek: (prev?.purchasedWeek ?? 0) + (planId === "week" ? 1 : 0),
    purchasedMonth: (prev?.purchasedMonth ?? 0) + (planId === "month" ? 1 : 0),
    purchasedYear: (prev?.purchasedYear ?? 0) + (planId === "year" ? 1 : 0),
  };

  await saveUserSubscription(next);
  return new Date(nextEnds);
}

async function handleSuccessfulPayment(ctx: Context): Promise<void> {
  await rememberUserProfile(ctx);
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
  if (await paymentExists(payment.telegram_payment_charge_id)) {
    processedPayments.add(payment.telegram_payment_charge_id);
    return;
  }

  const planId = parsePlanFromPayload(payment.invoice_payload);
  if (!planId) {
    if (isMiniAppEnergyPayload(payment.invoice_payload)) {
      return;
    }
    await ctx.reply(strings.unknownPaymentPlan);
    return;
  }

  const plan = PLANS[planId];
  if (payment.currency !== TELEGRAM_STARS_CURRENCY || payment.total_amount !== plan.stars) {
    await ctx.reply(strings.paymentCancelled);
    return;
  }

  processedPayments.add(payment.telegram_payment_charge_id);

  const code = generatePurchaseCode();
  const expiresAt = await applyPurchasedPlan(userId, planId);
  await insertPayment(
    payment.telegram_payment_charge_id,
    userId,
    planId,
    payment.currency,
    payment.total_amount,
    code,
    expiresAt.getTime(),
  );

  const expiresText = formatDateForLocale(expiresAt, locale);
  const instruction = strings.codeInstruction
    .replace("{code}", code)
    .replace("{sofia}", SOFIA_PROFILE_URL);

  await ctx.reply(
    `${strings.paymentSuccess}\n${strings.activationUntil}: ${expiresText}\n\n${instruction}`,
    {
      reply_markup: buildSofiaContactKeyboard(locale, code),
    },
  );
  await trackFunnelEvent(ctx, "payment_success", { planId });

  const notified = await notifySofia(ctx, planId, code, expiresAt);
  if (!notified) {
    await ctx.reply(strings.missingSofiaChatWarn);
  }
}

async function sendPlans(
  ctx: Context,
  {
    ignoreDebounce = false,
    source = null,
  }: { ignoreDebounce?: boolean; source?: string | null } = {},
): Promise<void> {
  const userId = ctx.from?.id;
  if (!userId) {
    return;
  }
  if (!ignoreDebounce && !shouldHandleWebAppAction(userId)) {
    return;
  }
  await sendProfessionalReadingOffer(ctx);
  await trackFunnelEvent(ctx, "show_plans", { source });
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

function isSofiaOperator(ctx: Context): boolean {
  const target = config.sofiaChatId;
  if (!target) {
    return false;
  }
  return `${ctx.from?.id ?? ""}` === target || `${ctx.chat?.id ?? ""}` === target;
}

function parseCommandArg(ctx: Context): string | null {
  const match = (ctx.match as string | undefined)?.trim();
  if (!match) {
    return null;
  }
  const parts = match.split(/\s+/);
  return parts[0] ?? null;
}

function parseCommandArgs(ctx: Context): string[] {
  const match = (ctx.match as string | undefined)?.trim();
  if (!match) {
    return [];
  }
  return match.split(/\s+/).filter(Boolean);
}

function formatUserRowForSofia(row: {
  telegramUserId: number;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
  locale: DbLocale | null;
  createdAt: number | null;
}): string {
  const created = row.createdAt
    ? formatDateForLocale(new Date(row.createdAt), "ru")
    : "-";
  const username = row.username ? `@${row.username}` : "-";
  const fullName = `${row.firstName ?? ""} ${row.lastName ?? ""}`.trim() || "-";
  const locale = row.locale ?? "-";
  return `ID: ${row.telegramUserId} | ${username} | ${fullName} | lang=${locale} | created=${created}`;
}

async function replyTextChunks(ctx: Context, lines: string[]): Promise<void> {
  const maxChunkSize = 3800;
  let chunk = "";
  for (const line of lines) {
    if (!line) {
      continue;
    }
    const next = chunk.length === 0 ? line : `${chunk}\n${line}`;
    if (next.length > maxChunkSize) {
      if (chunk.length > 0) {
        await ctx.reply(chunk);
      }
      chunk = line;
      continue;
    }
    chunk = next;
  }
  if (chunk.length > 0) {
    await ctx.reply(chunk);
  }
}

function buildSofiaPushComposeKeyboard(): InlineKeyboard {
  return new InlineKeyboard().text("📝 Ввести текст пуша", "sofia_push:compose");
}

function formatStateForSofia(row: {
  telegramUserId: number;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
  subscriptionEndsAt: number | null;
  unspentSingleReadings: number;
  purchasedSingle: number;
  purchasedWeek: number;
  purchasedMonth: number;
  purchasedYear: number;
}): string {
  const ends = row.subscriptionEndsAt
    ? formatDateForLocale(new Date(row.subscriptionEndsAt), "ru")
    : "-";
  const username = row.username ? `@${row.username}` : "-";
  const fullName = `${row.firstName ?? ""} ${row.lastName ?? ""}`.trim() || "-";
  return [
    `ID: ${row.telegramUserId}`,
    `Username: ${username}`,
    `Имя: ${fullName}`,
    `Активно до: ${ends}`,
    `Разовые разборы: ${row.unspentSingleReadings}`,
    `Пакеты: 1d x${row.purchasedSingle}, 7d x${row.purchasedWeek}, 30d x${row.purchasedMonth}, 365d x${row.purchasedYear}`,
  ].join("\n");
}

function formatQueryTypeForSofia(queryType: string): string {
  if (queryType.startsWith("reading_")) {
    return `Расклад (${queryType.replace("reading_", "")})`;
  }
  if (queryType === "natal_chart") {
    return "Натальная карта";
  }
  if (queryType === "reading_details") {
    return "Детальный разбор";
  }
  return queryType;
}

function newsMessageForLocale(locale: SupportedLocale): string {
  if (locale === "en") {
    return [
      "✨ The real magic update",
      "",
      "New in this version:",
      "• Lenormand reading (choose your deck in Profile)",
      "• Couple compatibility check (try it for free)",
      "• Natal chart reading (try it for free)",
    ].join("\n");
  }
  if (locale === "kk") {
    return [
      "✨ The real magic жаңартуы",
      "",
      "Осы нұсқада жаңасы:",
      "• Ленорман колодасымен болжау (колоданы Профильден таңда)",
      "• Жұп үйлесімділігін тексеру (тегін байқап көр)",
      "• Наталдық картаны оқу (тегін байқап көр)",
    ].join("\n");
  }
  return [
    "✨ Обновление The real magic",
    "",
    "Что нового в этой версии:",
    "• Гадание по колоде Ленорман (выбери колоду в профиле)",
    "• Проверка совместимости пары (попробуй бесплатно)",
    "• Чтение натальной карты (попробуй бесплатно)",
  ].join("\n");
}

function supportedLocaleFromDb(value: DbLocale | null): SupportedLocale {
  if (value === "en" || value === "kk" || value === "ru") {
    return value;
  }
  return "ru";
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isGetUpdatesConflictError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const details = error as {
    error_code?: number;
    description?: string;
    message?: string;
    method?: string;
    payload?: { method?: string; error_code?: number };
  };
  const errorCode = details.error_code ?? details.payload?.error_code;
  const method = details.method ?? details.payload?.method;
  const text = `${details.description ?? ""} ${details.message ?? ""}`;
  return (
    errorCode === 409 &&
    (method === "getUpdates" || text.includes("terminated by other getUpdates request"))
  );
}

async function sendLauncherMessage(ctx: Context): Promise<void> {
  await sendMainMenu(ctx);
}

async function main(): Promise<void> {
  initDb(config.databaseUrl);
  await ensureSchema();

  const bot = new Bot(config.telegramToken);

  bot.command("start", async (ctx) => {
    await rememberUserProfile(ctx);
    const userId = ctx.from?.id;
    if (!userId) {
      await sendAbout(ctx);
      return;
    }
    const state = getUserState(userId);
    const payload = parseStartPayload(ctx);
    state.pendingStartPayload = payload ?? "about";
    await trackFunnelEvent(ctx, "start", { source: payload ?? "direct" });

    if (!state.locale) {
      await sendLanguagePicker(ctx);
      return;
    }

    state.pendingStartPayload = null;
    if (payload === "plans") {
      await sendPlans(ctx, { ignoreDebounce: true, source: "start_payload_plans" });
      return;
    }
    await sendAbout(ctx);
  });

  bot.command("lang", async (ctx) => {
    await rememberUserProfile(ctx);
    await sendLanguagePicker(ctx);
  });

  bot.command("help", async (ctx) => {
    await rememberUserProfile(ctx);
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

  bot.command("subs", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }

    const active = await listActiveSubscriptions();

    if (active.length === 0) {
      await ctx.reply("Активных подписок сейчас нет.");
      return;
    }

    const chunks: string[] = [];
    for (const row of active) {
      chunks.push(formatStateForSofia(row));
    }

    await ctx.reply(
      `Активные подписки (${active.length}):\n\n${chunks.join("\n\n----------------\n\n")}\n\nКоманда закрытия: /sub_done <user_id>\nИстория запросов: /queries <user_id> [limit]`,
    );
  });

  bot.command("sub_done", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }

    const arg = parseCommandArg(ctx);
    const userId = arg ? Number(arg) : NaN;
    if (!Number.isFinite(userId)) {
      await ctx.reply("Использование: /sub_done <user_id>");
      return;
    }

    const completion = await completeConsultation(userId);
    if (completion === "single") {
      await ctx.reply(`Завершен один разовый разбор для user_id=${userId}.`);
      try {
        await ctx.api.sendMessage(
          userId,
          "✅ София отметила, что консультация оказана. Один разовый разбор списан.",
        );
      } catch (error) {
        console.error("Cannot notify user about consumed single reading", error);
      }
      return;
    }

    if (completion === "timed") {
      await ctx.reply(`Подписка пользователя user_id=${userId} завершена.`);
      try {
        await ctx.api.sendMessage(
          userId,
          "✅ София отметила консультацию как завершенную. Текущая подписка закрыта.",
        );
      } catch (error) {
        console.error("Cannot notify user about subscription close", error);
      }
      return;
    }

    await ctx.reply("У пользователя нет активной подписки для завершения или он не найден.");
  });

  bot.command("queries", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }

    const args = parseCommandArgs(ctx);
    const userId = args[0] ? Number(args[0]) : NaN;
    const limit = args[1] ? Number(args[1]) : 10;
    if (!Number.isFinite(userId) || userId <= 0) {
      await ctx.reply("Использование: /queries <user_id> [limit]");
      return;
    }

    const rows = await listRecentUserQueriesForUser(userId, limit);
    if (rows.length === 0) {
      await ctx.reply(`По user_id=${userId} запросов пока нет.`);
      return;
    }

    const lines = rows.map((row, index) => {
      const date = row.createdAt
        ? formatDateForLocale(new Date(row.createdAt), "ru")
        : "-";
      const type = formatQueryTypeForSofia(row.queryType);
      const question = row.question || "-";
      return `${index + 1}. ${date} • ${type}\n${question}`;
    });

    await ctx.reply(
      `Недавние запросы user_id=${userId} (${rows.length}):\n\n${lines.join("\n\n")}`,
    );
  });

  bot.command("users_today", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }

    const rows = await listUsersCreatedTodayForSofia();
    if (rows.length === 0) {
      await ctx.reply("Сегодня новых пользователей пока нет.");
      return;
    }

    const lines = rows.map((row, index) => `${index + 1}. ${formatUserRowForSofia(row)}`);
    await replyTextChunks(ctx, [
      `Новые пользователи за сегодня: ${rows.length}`,
      "",
      ...lines,
    ]);
  });

  bot.command("users_all", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }

    const rows = await listUsersForSofia();
    if (rows.length === 0) {
      await ctx.reply("В users пока нет записей.");
      return;
    }

    const lines = rows.map((row, index) => `${index + 1}. ${formatUserRowForSofia(row)}`);
    await replyTextChunks(ctx, [
      `Все пользователи: ${rows.length}`,
      "",
      ...lines,
    ]);
  });

  bot.command("push", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }
    const fromId = ctx.from?.id;
    if (!fromId) {
      return;
    }
    sofiaAwaitingPushText.delete(fromId);
    await ctx.reply(
      "Нажми кнопку ниже, затем отправь следующим сообщением текст пуша для рассылки всем пользователям.",
      { reply_markup: buildSofiaPushComposeKeyboard() },
    );
  });

  bot.command("cancel_push", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }
    const fromId = ctx.from?.id;
    if (!fromId) {
      return;
    }
    sofiaAwaitingPushText.delete(fromId);
    await ctx.reply("Режим ввода текста пуша отменен.");
  });

  bot.command("broadcast_whatsnew", async (ctx) => {
    if (!isSofiaOperator(ctx)) {
      return;
    }
    const users = await listUsersForBroadcast();
    if (users.length === 0) {
      await ctx.reply("В таблице users пока нет получателей.");
      return;
    }

    await ctx.reply(`Начинаю рассылку новинок. Получателей: ${users.length}.`);

    let sent = 0;
    let failed = 0;

    for (const user of users) {
      const locale = supportedLocaleFromDb(user.locale);
      try {
        await ctx.api.sendMessage(user.telegramUserId, newsMessageForLocale(locale));
        sent += 1;
      } catch (error) {
        failed += 1;
        console.error(`Broadcast failed for user_id=${user.telegramUserId}`, error);
      }
      // Keeps a safe pace and reduces rate-limit spikes.
      await delay(45);
    }

    await ctx.reply(
      `Рассылка завершена.\nОтправлено: ${sent}\nОшибок: ${failed}\nВсего: ${users.length}`,
    );
  });

  bot.callbackQuery(/^lang:(ru|en|kk)$/, async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    const userId = ctx.from?.id;
    if (!userId) {
      await sendMainMenu(ctx);
      return;
    }
    const state = getUserState(userId);
    state.locale = ctx.match[1] as SupportedLocale;
    await upsertUserProfile(
      userId,
      state.username,
      state.firstName,
      state.lastName,
      toDbLocale(state.locale),
    );
    await trackFunnelEvent(ctx, "language_selected");
    const pending = state.pendingStartPayload;
    state.pendingStartPayload = null;
    if (pending === "plans") {
      await sendPlans(ctx, { ignoreDebounce: true, source: "lang_after_start_payload_plans" });
      return;
    }
    if (pending === "about") {
      await sendAbout(ctx);
      return;
    }
    await sendMainMenu(ctx);
  });

  bot.on("message:web_app_data", async (ctx) => {
    await rememberUserProfile(ctx);
    const data = ctx.message.web_app_data?.data ?? "";
    const action = parseWebAppAction(data);
    if (action !== "professional_reading" && action !== "show_plans") {
      return;
    }
    await sendPlans(ctx, { source: `web_app_data:${action}` });
  });

  bot.callbackQuery("menu:buy", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    await trackFunnelEvent(ctx, "menu_buy_click", { source: "menu" });
    await sendPlans(ctx, { ignoreDebounce: true, source: "menu_buy" });
  });

  bot.callbackQuery("menu:about", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    await sendAbout(ctx);
  });

  bot.callbackQuery("menu:language", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    await sendLanguagePicker(ctx);
  });

  bot.callbackQuery("menu:subscriptions", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    await sendMySubscriptions(ctx);
  });

  bot.callbackQuery("menu:home", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    await sendMainMenu(ctx);
  });

  bot.callbackQuery("sofia:contacted", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    const locale = getLocale(ctx);
    await trackFunnelEvent(ctx, "sofia_contact_clicked");
    await ctx.reply(STRINGS[locale].contactSofiaDoneAck, {
      reply_markup: buildBackKeyboard(locale),
    });
  });

  bot.callbackQuery("sofia_push:compose", async (ctx) => {
    await rememberUserProfile(ctx);
    await ctx.answerCallbackQuery();
    if (!isSofiaOperator(ctx)) {
      return;
    }
    const fromId = ctx.from?.id;
    if (!fromId) {
      return;
    }
    sofiaAwaitingPushText.add(fromId);
    await ctx.reply(
      "Отправь текст пуша следующим сообщением. Команда для отмены: /cancel_push",
    );
  });

  bot.callbackQuery(/^plan:(single|week|month|year)$/, async (ctx) => {
    await rememberUserProfile(ctx);
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
    await trackFunnelEvent(ctx, "plan_selected", { planId, source: "plans_keyboard" });
    await startPaymentFlow(ctx, planId);
  });

  bot.on("pre_checkout_query", async (ctx) => {
    await rememberUserProfile(ctx);
    const query = ctx.preCheckoutQuery;
    if (!query) {
      return;
    }

    const planId = parsePlanFromPayload(query.invoice_payload);
    if (!planId) {
      if (isMiniAppEnergyPayload(query.invoice_payload)) {
        await ctx.answerPreCheckoutQuery(true);
        return;
      }
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
    await trackFunnelEvent(ctx, "precheckout_ok", { planId });
  });

  bot.on("message:successful_payment", async (ctx) => {
    await handleSuccessfulPayment(ctx);
  });

  bot.on("message:text", async (ctx) => {
    await rememberUserProfile(ctx);
    const fromId = ctx.from?.id;
    if (fromId && sofiaAwaitingPushText.has(fromId) && isSofiaOperator(ctx)) {
      const pushText = ctx.message.text.trim();
      if (!pushText) {
        await ctx.reply("Текст пуша пустой. Отправь непустое сообщение или /cancel_push.");
        return;
      }
      sofiaAwaitingPushText.delete(fromId);

      const users = await listUsersForBroadcast();
      if (users.length === 0) {
        await ctx.reply("В таблице users пока нет получателей.");
        return;
      }

      await ctx.reply(`Начинаю пуш-рассылку. Получателей: ${users.length}.`);
      let sent = 0;
      let failed = 0;

      for (const user of users) {
        try {
          await ctx.api.sendMessage(user.telegramUserId, pushText);
          sent += 1;
        } catch (error) {
          failed += 1;
          console.error(`Push broadcast failed for user_id=${user.telegramUserId}`, error);
        }
        await delay(45);
      }

      await ctx.reply(
        `Пуш-рассылка завершена.\nОтправлено: ${sent}\nОшибок: ${failed}\nВсего: ${users.length}`,
      );
      return;
    }

    if (fromId) {
      const state = getUserState(fromId);
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

  const retryDelayMs = 5000;
  for (;;) {
    try {
      await bot.start({
        allowed_updates: ["message", "callback_query", "pre_checkout_query"],
      });
      console.log("Telegram bot stopped.");
      return;
    } catch (error) {
      if (!isGetUpdatesConflictError(error)) {
        throw error;
      }
      console.warn(
        `Detected Telegram getUpdates conflict (409). Retrying in ${retryDelayMs}ms.`,
      );
      await delay(retryDelayMs);
    }
  }
}

main().catch((error) => {
  console.error("Startup failure", error);
  process.exit(1);
});
