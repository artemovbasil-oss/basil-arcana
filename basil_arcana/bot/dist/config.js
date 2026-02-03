"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadConfig = loadConfig;
const path_1 = __importDefault(require("path"));
function requireEnv(name) {
    const value = process.env[name];
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
    const arcanaApiKey = requireEnv("ARCANA_API_KEY");
    const defaultLocale = parseLocale(process.env.DEFAULT_LOCALE, "en");
    const assetsBasePath = process.env.ASSETS_BASE_PATH ||
        path_1.default.resolve(process.cwd(), "..", "app_flutter", "assets");
    const dataBasePath = process.env.DATA_BASE_PATH ||
        path_1.default.resolve(process.cwd(), "..", "app_flutter", "assets", "data");
    const requestTimeoutMs = 35000;
    return {
        telegramToken,
        apiBaseUrl,
        arcanaApiKey,
        defaultLocale,
        assetsBasePath,
        dataBasePath,
        requestTimeoutMs,
    };
}
