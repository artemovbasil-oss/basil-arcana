"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadConfig = loadConfig;
const assets_1 = require("./assets");
function requireEnv(name, fallback) {
    const value = process.env[name] || fallback;
    if (!value || value.trim().length === 0) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}
function parseLocale(value, fallback) {
    if (value === "en" || value === "ru" || value === "kk") {
        return value;
    }
    return fallback;
}
function loadConfig() {
    const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
    const apiBaseUrl = process.env.API_BASE_URL || "https://api.basilarcana.com";
    const arcanaApiKey = requireEnv("BASIL_ARCANA_API_KEY", process.env.ARCANA_API_KEY);
    const defaultLocale = parseLocale(process.env.DEFAULT_LOCALE, "en");
    const assetsBasePath = (0, assets_1.resolveBotAssetsRoot)();
    const requestTimeoutMs = 35000;
    return {
        telegramToken,
        apiBaseUrl,
        arcanaApiKey,
        defaultLocale,
        assetsBasePath,
        requestTimeoutMs,
    };
}
