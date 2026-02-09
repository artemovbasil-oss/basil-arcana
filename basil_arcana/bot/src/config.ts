export interface BotConfig {
  telegramToken: string;
  webAppUrl?: string;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalEnv(name: string): string | undefined {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    return undefined;
  }
  return value;
}

function buildVersionedUrl(url: string, version: string): string {
  try {
    const parsed = new URL(url);
    parsed.pathname = `/v/${version}/`;
    parsed.search = "";
    return parsed.toString();
  } catch (error) {
    const trimmed = url.replace(/\/+$/, "");
    return `${trimmed}/v/${encodeURIComponent(version)}/`;
  }
}

export function loadConfig(): BotConfig {
  const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
  const webAppUrl = optionalEnv("TELEGRAM_WEBAPP_URL");
  const appVersion = optionalEnv("APP_VERSION") ?? "dev";

  return {
    telegramToken,
    webAppUrl: webAppUrl ? buildVersionedUrl(webAppUrl, appVersion) : undefined,
  };
}
