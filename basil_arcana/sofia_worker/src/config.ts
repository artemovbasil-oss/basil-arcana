export interface BotConfig {
  telegramToken: string;
  databaseUrl: string;
  webAppUrl?: string;
  sofiaChatId?: string;
}

export interface SofiaAgentConfig {
  databaseUrl: string;
  openAiApiKey?: string;
  openAiModel: string;
  personaHandle: string;
  personaDisplayName: string;
  telegramApiId?: number;
  telegramApiHash?: string;
  telegramSessionString?: string;
  inboxDialogLimit: number;
  inboxMessageLimit: number;
  inboxLookbackHours: number;
  schedulerPollMinutes: number;
  schedulerSearchLimit: number;
  generationBatchSize: number;
  autoSendApproved: boolean;
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

function optionalNumberEnv(name: string): number | undefined {
  const value = optionalEnv(name);
  if (!value) {
    return undefined;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Environment variable ${name} must be a number`);
  }
  return parsed;
}

function booleanEnv(name: string, fallback: boolean): boolean {
  const value = optionalEnv(name);
  if (!value) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  throw new Error(`Environment variable ${name} must be a boolean`);
}

function buildRootUrl(url: string): string {
  try {
    const parsed = new URL(url);
    const normalizedPath = parsed.pathname.replace(/\/+$/, "") || "/";
    parsed.pathname = normalizedPath.endsWith("/") ? normalizedPath : `${normalizedPath}/`;
    return parsed.toString();
  } catch (error) {
    const trimmed = url.replace(/\/+$/, "");
    return trimmed.length > 0 ? `${trimmed}/` : "/";
  }
}

export function loadConfig(): BotConfig {
  const telegramToken = requireEnv("TELEGRAM_BOT_TOKEN");
  const databaseUrl = requireEnv("DATABASE_URL");
  const webAppUrl = optionalEnv("TELEGRAM_WEBAPP_URL");
  const sofiaChatId =
    optionalEnv("SOFIA_CHAT_ID") ?? optionalEnv("SOFIA_NOTIFY_CHAT_ID");

  return {
    telegramToken,
    databaseUrl,
    webAppUrl: webAppUrl ? buildRootUrl(webAppUrl) : undefined,
    sofiaChatId,
  };
}

export function loadSofiaAgentConfig(): SofiaAgentConfig {
  return {
    databaseUrl: requireEnv("DATABASE_URL"),
    openAiApiKey: optionalEnv("OPENAI_API_KEY"),
    openAiModel: optionalEnv("SOFIA_AGENT_MODEL") ?? "gpt-4.1-mini",
    personaHandle: optionalEnv("SOFIA_AGENT_HANDLE") ?? "@SofiaKnoxx",
    personaDisplayName: optionalEnv("SOFIA_AGENT_NAME") ?? "Sofia Knox",
    telegramApiId: optionalNumberEnv("TELEGRAM_API_ID"),
    telegramApiHash: optionalEnv("TELEGRAM_API_HASH"),
    telegramSessionString: optionalEnv("SOFIA_SESSION_STRING"),
    inboxDialogLimit: optionalNumberEnv("SOFIA_INBOX_DIALOG_LIMIT") ?? 30,
    inboxMessageLimit: optionalNumberEnv("SOFIA_INBOX_MESSAGE_LIMIT") ?? 8,
    inboxLookbackHours: optionalNumberEnv("SOFIA_INBOX_LOOKBACK_HOURS") ?? 72,
    schedulerPollMinutes: optionalNumberEnv("SOFIA_SCHEDULER_POLL_MINUTES") ?? 15,
    schedulerSearchLimit: optionalNumberEnv("SOFIA_SCHEDULER_SEARCH_LIMIT") ?? 12,
    generationBatchSize: optionalNumberEnv("SOFIA_GENERATION_BATCH_SIZE") ?? 5,
    autoSendApproved: booleanEnv("SOFIA_AUTO_SEND_APPROVED", false),
  };
}
