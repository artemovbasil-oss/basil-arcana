export interface BotConfig {
  telegramToken: string;
  webAppUrl: string;
}

function optionalEnv(name: string, fallback: string): string {
  const value = process.env[name];
  if (!value) {
    return fallback;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? fallback : trimmed;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function appendVersion(url: string, version: string): string {
  try {
    const parsed = new URL(url);
    parsed.searchParams.set("v", version);
    return parsed.toString();
  } catch (error) {
    const separator = url.includes("?") ? "&" : "?";
    return `${url}${separator}v=${encodeURIComponent(version)}`;
  }
}

export function loadConfig(): BotConfig {
  const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
  const webAppUrl = requireEnv("TELEGRAM_WEBAPP_URL");
  const appVersion = optionalEnv("APP_VERSION", "dev");

  return {
    telegramToken,
    webAppUrl: appendVersion(webAppUrl, appVersion),
  };
}
