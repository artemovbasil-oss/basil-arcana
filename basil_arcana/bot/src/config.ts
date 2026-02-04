type Locale = "en" | "ru" | "kk";

export interface BotConfig {
  telegramToken: string;
  telegramWebAppUrl: string;
  defaultLocale: Locale;
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
  const telegramWebAppUrl = requireEnv("TELEGRAM_WEBAPP_URL");
  const defaultLocale = parseLocale(process.env.DEFAULT_LOCALE, "en");

  return {
    telegramToken,
    telegramWebAppUrl,
    defaultLocale,
  };
}

export type { Locale };
