export interface BotConfig {
  telegramToken: string;
  webAppUrl: string;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function loadConfig(): BotConfig {
  const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
  const webAppUrl = requireEnv("TELEGRAM_WEBAPP_URL");

  return {
    telegramToken,
    webAppUrl,
  };
}
