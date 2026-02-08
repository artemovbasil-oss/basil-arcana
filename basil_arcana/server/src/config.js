const PORT = process.env.PORT || '';
const ARCANA_API_KEY = process.env.ARCANA_API_KEY || '';
const OPENAI_API_KEY =
  process.env.OPENAI_API_KEY ||
  process.env.OPENAI_KEY ||
  process.env.OPENAI_API_TOKEN ||
  '';
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const RATE_LIMIT_WINDOW_MS = process.env.RATE_LIMIT_WINDOW_MS
  ? Number(process.env.RATE_LIMIT_WINDOW_MS)
  : null;
const RATE_LIMIT_MAX = process.env.RATE_LIMIT_MAX
  ? Number(process.env.RATE_LIMIT_MAX)
  : null;

module.exports = {
  PORT,
  ARCANA_API_KEY,
  OPENAI_API_KEY,
  OPENAI_MODEL,
  TELEGRAM_BOT_TOKEN,
  RATE_LIMIT_WINDOW_MS,
  RATE_LIMIT_MAX,
};
