import path from "path";

type Locale = "en" | "ru" | "kk";

export interface BotConfig {
  telegramToken: string;
  apiBaseUrl: string;
  arcanaApiKey: string;
  defaultLocale: Locale;
  assetsBasePath: string;
  dataBasePath: string;
  requestTimeoutMs: number;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function parseLocale(value: string | undefined, fallback: Locale): Locale {
  if (value === "en" || value === "ru" || value === "kk") {
    return value;
  }
  return fallback;
}

export function loadConfig(): BotConfig {
  const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
  const apiBaseUrl = process.env.API_BASE_URL || "https://api.basilarcana.com";
  const arcanaApiKey = requireEnv("ARCANA_API_KEY");
  const defaultLocale = parseLocale(process.env.DEFAULT_LOCALE, "en");
  const assetsBasePath =
    process.env.ASSETS_BASE_PATH ||
    path.resolve(process.cwd(), "..", "app_flutter", "assets");
  const dataBasePath =
    process.env.DATA_BASE_PATH ||
    path.resolve(process.cwd(), "..", "app_flutter", "assets", "data");
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

export type { Locale };
