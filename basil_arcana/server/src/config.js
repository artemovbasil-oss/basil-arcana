const PORT = process.env.PORT || '';
const ARCANA_API_KEY = process.env.ARCANA_API_KEY || '';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
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
  RATE_LIMIT_WINDOW_MS,
  RATE_LIMIT_MAX,
};
