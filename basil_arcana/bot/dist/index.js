"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const grammy_1 = require("grammy");
const config_1 = require("./config");
const config = (0, config_1.loadConfig)();
const WELCOME_TEXT = "Welcome to Basil’s Arcana. Tap below to open the mini app.";
const HELP_TEXT = "Use the button below to open the Basil’s Arcana mini app inside Telegram.";
const NUDGE_TEXT = "Open Basil’s Arcana from the button below.";
function buildKeyboard() {
    return new grammy_1.InlineKeyboard().webApp("Open Basil’s Arcana", config.webAppUrl);
}
async function sendLauncherMessage(ctx) {
    await ctx.reply(WELCOME_TEXT, { reply_markup: buildKeyboard() });
}
async function main() {
    const bot = new grammy_1.Bot(config.telegramToken);
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
