import { Bot, InlineKeyboard, type Context } from "grammy";
import { loadConfig } from "./config";

const config = loadConfig();

const WELCOME_TEXT =
  "Welcome to Basil’s Arcana. Tap below to open the mini app.";
const HELP_TEXT =
  "Use the button below to open the Basil’s Arcana mini app inside Telegram.";
const NUDGE_TEXT = "Open Basil’s Arcana from the button below.";

function buildKeyboard(): InlineKeyboard {
  return new InlineKeyboard().webApp("Open Basil’s Arcana", config.webAppUrl);
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
