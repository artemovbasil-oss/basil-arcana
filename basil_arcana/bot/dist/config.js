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
function buildVersionedUrl(url, version) {
    try {
        const parsed = new URL(url);
        parsed.pathname = `/v/${version}/`;
        parsed.search = "";
        return parsed.toString();
    }
    catch (error) {
        const trimmed = url.replace(/\/+$/, "");
        return `${trimmed}/v/${encodeURIComponent(version)}/`;
    }
}
function loadConfig() {
    const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
    const webAppUrl = requireEnv("TELEGRAM_WEBAPP_URL");
    const appVersion = requireEnv("APP_VERSION");
    return {
        telegramToken,
        webAppUrl: buildVersionedUrl(webAppUrl, appVersion),
    };
}
