"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const grammy_1 = require("grammy");
const config_1 = require("./config");
const config = (0, config_1.loadConfig)();
const STRINGS = {
    ru: {
        menuTitle: "Добро пожаловать в Basil’s Arcana ✨",
        menuDescription: "Выбери действие из меню ниже.",
        menuButtons: {
            launchApp: "🚀 Запустить мини‑приложение",
            buy: "💳 Купить подписку",
            about: "✨ Что умеет бот",
            back: "⬅️ В меню",
        },
        launchUnavailable: "🚀 Временно недоступно",
        aboutText: "Basil’s Arcana — магия как сервис. Здесь ты можешь получить быстрые и глубокие расклады, персональные подсказки и историю своих обращений. Открывай мини‑приложение, чтобы начать чтение.",
        professionalTitle: "🔮 Профессиональное толкование",
        professionalDescription: "Хочешь более глубокий и персональный разбор?\nВыбери подходящий тариф — и оракул раскроется полностью.",
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
            about: "✨ What this bot can do",
            back: "⬅️ Back to menu",
        },
        launchUnavailable: "🚀 Temporarily unavailable",
        aboutText: "Basil’s Arcana is magic as a service. Get quick and deep readings, personalized insights, and a history of your requests. Open the mini app to begin.",
        professionalTitle: "🔮 Professional reading",
        professionalDescription: "Want a deeper, more personal interpretation?\nPick the plan that fits you — and the oracle will open up fully.",
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
            about: "✨ Бот не істей алады",
            back: "⬅️ Мәзірге",
        },
        launchUnavailable: "🚀 Уақытша қолжетімсіз",
        aboutText: "Basil’s Arcana — магия қызмет ретінде. Мұнда жылдам әрі терең жорамал, жеке кеңестер және сұраулар тарихын аласың. Бастау үшін мини‑қосымшаны аш.",
        professionalTitle: "🔮 Кәсіби жорамал",
        professionalDescription: "Терең әрі жеке талдау қалайсың ба?\nӨзіңе ыңғайлы тарифті таңда — сонда оракул толық ашылады.",
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
const userState = new Map();
function buildMainMenuKeyboard(locale) {
    const labels = STRINGS[locale].menuButtons;
    const keyboard = new grammy_1.InlineKeyboard();
    if (config.webAppUrl) {
        keyboard.webApp(labels.launchApp, config.webAppUrl).row();
    }
    keyboard.text(labels.buy, "menu:buy").row().text(labels.about, "menu:about");
    return keyboard;
}
function getLocale(ctx) {
    const code = ctx.from?.language_code?.toLowerCase() ?? "";
    if (code.startsWith("kk") || code.startsWith("kz")) {
        return "kk";
    }
    if (code.startsWith("en")) {
        return "en";
    }
    return "ru";
}
function getUserState(userId) {
    const existing = userState.get(userId);
    if (existing) {
        return existing;
    }
    const initial = {
        activeSubscription: false,
        selectedPlan: null,
    };
    userState.set(userId, initial);
    return initial;
}
function buildSubscriptionKeyboard(locale) {
    const labels = STRINGS[locale].planLabels;
    const backLabel = STRINGS[locale].menuButtons.back;
    return new grammy_1.InlineKeyboard()
        .text(labels.week, "plan:week")
        .text(labels.month, "plan:month")
        .text(labels.year, "plan:year")
        .row()
        .text(backLabel, "menu:home");
}
async function sendProfessionalReadingOffer(ctx) {
    const locale = getLocale(ctx);
    const strings = STRINGS[locale];
    const text = `${strings.professionalTitle}\n\n${strings.professionalDescription}`;
    await ctx.reply(text, { reply_markup: buildSubscriptionKeyboard(locale) });
}
async function sendMainMenu(ctx) {
    const locale = getLocale(ctx);
    const strings = STRINGS[locale];
    const lines = [strings.menuTitle, strings.menuDescription];
    if (!config.webAppUrl) {
        console.error("TELEGRAM_WEBAPP_URL is missing; Launch app button disabled.");
        lines.push("", strings.launchUnavailable);
    }
    await ctx.reply(lines.join("\n"), {
        reply_markup: buildMainMenuKeyboard(locale),
    });
}
async function sendAbout(ctx) {
    const locale = getLocale(ctx);
    const strings = STRINGS[locale];
    await ctx.reply(strings.aboutText, {
        reply_markup: new grammy_1.InlineKeyboard().text(strings.menuButtons.back, "menu:home"),
    });
}
function parseWebAppAction(data) {
    const trimmed = data.trim();
    if (!trimmed) {
        return null;
    }
    if (trimmed === "professional_reading") {
        return trimmed;
    }
    try {
        const parsed = JSON.parse(trimmed);
        if (parsed?.action) {
            return parsed.action;
        }
    }
    catch (_) {
        return null;
    }
    return null;
}
const webAppDebounceMs = 3000;
const lastWebAppActionAt = new Map();
function shouldHandleWebAppAction(userId) {
    const now = Date.now();
    const last = lastWebAppActionAt.get(userId) ?? 0;
    if (now - last < webAppDebounceMs) {
        return false;
    }
    lastWebAppActionAt.set(userId, now);
    return true;
}
async function startPaymentFlow(ctx, locale) {
    // TODO: Wire to the existing payment/subscription flow when available.
    await ctx.reply(STRINGS[locale].paymentStub);
}
async function sendPlans(ctx, { ignoreDebounce = false } = {}) {
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
function parseStartPayload(ctx) {
    const match = ctx.match?.trim();
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
async function sendLauncherMessage(ctx) {
    await sendMainMenu(ctx);
}
async function main() {
    const bot = new grammy_1.Bot(config.telegramToken);
    bot.command("start", async (ctx) => {
        const payload = parseStartPayload(ctx);
        if (payload === "plans") {
            await sendPlans(ctx, { ignoreDebounce: true });
            return;
        }
        await sendLauncherMessage(ctx);
    });
    bot.command("help", async (ctx) => {
        await sendMainMenu(ctx);
    });
    bot.command("chatid", async (ctx) => {
        const chatId = ctx.chat?.id;
        const userId = ctx.from?.id;
        const username = ctx.from?.username ? `@${ctx.from.username}` : "-";
        await ctx.reply(`chat_id: ${chatId ?? "-"}\nuser_id: ${userId ?? "-"}\nusername: ${username}`);
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
        const plan = ctx.match[1];
        if (state.selectedPlan === plan) {
            await ctx.reply(STRINGS[locale].planAlreadySelected);
            return;
        }
        state.selectedPlan = plan;
        await startPaymentFlow(ctx, locale);
    });
    bot.on("message:text", async (ctx) => {
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
