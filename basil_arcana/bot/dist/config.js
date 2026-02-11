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
function optionalEnv(name) {
    const value = process.env[name];
    if (!value || value.trim().length === 0) {
        return undefined;
    }
    return value;
}
function buildRootUrl(url) {
    try {
        const parsed = new URL(url);
        const normalizedPath = parsed.pathname.replace(/\/+$/, "") || "/";
        parsed.pathname = normalizedPath.endsWith("/") ? normalizedPath : `${normalizedPath}/`;
        return parsed.toString();
    }
    catch (error) {
        const trimmed = url.replace(/\/+$/, "");
        return trimmed.length > 0 ? `${trimmed}/` : "/";
    }
}
function loadConfig() {
    const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
    const webAppUrl = optionalEnv("TELEGRAM_WEBAPP_URL");
    const sofiaChatId = optionalEnv("SOFIA_CHAT_ID") ?? optionalEnv("SOFIA_NOTIFY_CHAT_ID");
    return {
        telegramToken,
        webAppUrl: webAppUrl ? buildRootUrl(webAppUrl) : undefined,
        sofiaChatId,
    };
}
