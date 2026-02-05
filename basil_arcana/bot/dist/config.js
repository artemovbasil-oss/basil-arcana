"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadConfig = loadConfig;
function requireEnv(name) {
    const value = process.env[name];
    if (!value || value.trim().length === 0) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}
function loadConfig() {
    const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
    const webAppUrl = requireEnv("TELEGRAM_WEBAPP_URL");
    return {
        telegramToken,
        webAppUrl,
    };
}
