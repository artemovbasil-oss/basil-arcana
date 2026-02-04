import { Bot, InlineKeyboard } from "grammy";
import { loadConfig } from "./config";
import { t } from "./i18n";
import type { Locale } from "./config";

const config = loadConfig();

const bot = new Bot(config.telegramToken);

function resolveLocale(languageCode?: string): Locale {
  if (!languageCode) {
    return config.defaultLocale;
  }
  if (languageCode.startsWith("ru")) {
    return "ru";
  }
  if (languageCode.startsWith("kk")) {
    return "kk";
  }
  return "en";
}

bot.command("start", async (ctx) => {
  const locale = resolveLocale(ctx.from?.language_code);
  const messages = t(locale);
  const keyboard = new InlineKeyboard().webApp(
    messages.openAppButton,
    config.telegramWebAppUrl
  );
  await ctx.reply(messages.welcome, { reply_markup: keyboard });
});

bot.command("health", async (ctx) => {
  await ctx.reply("ok");
});

bot.catch((err) => {
  console.error("Bot error", err.error);
});

bot
  .start({
    allowed_updates: ["message"],
  })
  .then(() => {
    console.log("Telegram bot started.");
  })
  .catch((error) => {
    console.error("Startup failure", error);
    process.exit(1);
  });
