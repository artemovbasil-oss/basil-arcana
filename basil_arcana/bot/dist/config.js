"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadConfig = loadConfig;
function optionalEnv(name, fallback) {
    const value = process.env[name];
    if (!value) {
        return fallback;
    }
    const trimmed = value.trim();
    return trimmed.length === 0 ? fallback : trimmed;
}
function requireEnv(name) {
    const value = process.env[name];
    if (!value || value.trim().length === 0) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}
function appendVersion(url, version) {
    try {
        const parsed = new URL(url);
        parsed.searchParams.set("v", version);
        return parsed.toString();
    }
    catch (error) {
        const separator = url.includes("?") ? "&" : "?";
        return `${url}${separator}v=${encodeURIComponent(version)}`;
    }
}
function loadConfig() {
    const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
    const webAppUrl = requireEnv("TELEGRAM_WEBAPP_URL");
    const appVersion = optionalEnv("APP_VERSION", "dev");
    return {
        telegramToken,
        webAppUrl: appendVersion(webAppUrl, appVersion),
    };
}
