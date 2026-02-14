const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const {
  buildPromptMessages,
  buildDetailsPrompt,
  buildNatalChartPrompt,
  buildCompatibilityPrompt
} = require('./src/prompt');
const {
  createResponse,
  createTextResponse,
  listModels,
  OpenAIRequestError
} = require('./src/openai_client');
const {
  validateReadingRequest,
  validateDetailsRequest,
  validateNatalChartRequest,
  validateCompatibilityRequest
} = require('./src/validate');
const {
  ARCANA_API_KEY,
  PORT,
  RATE_LIMIT_MAX,
  RATE_LIMIT_WINDOW_MS,
  OPENAI_API_KEY,
  TELEGRAM_BOT_TOKEN,
  SOFIA_NOTIFY_CHAT_ID,
  DATABASE_URL
} = require('./src/config');
const { validateTelegramInitData } = require('./src/telegram');
const { telegramAuthMiddleware } = require('./src/telegram_auth_middleware');
const {
  initDb,
  hasDb,
  ensureSchema,
  upsertUserProfile,
  recordSofiaConsent,
  saveCreatedInvoice,
  confirmInvoiceStatus,
  claimReferralBonus,
  consumeFreeFiveCardsCredit,
  getUserDashboard,
  logUserQuery,
  listRecentUserQueries,
  clearUserQueryHistory
} = require('./src/db');

const app = express();

app.set('trust proxy', 1);

app.use(
  cors({
    allowedHeaders: [
      'Content-Type',
      'X-Request-Id',
      'X-Telegram-InitData',
      'X-Telegram-Init-Data',
      'X-TG-Init-Data',
      'X-Api-Key'
    ],
    exposedHeaders: ['x-request-id']
  })
);
app.use(express.json({ limit: '1mb' }));

if (!TELEGRAM_BOT_TOKEN) {
  console.warn(
    JSON.stringify({
      event: 'telegram_bot_token_missing'
    })
  );
}

function verifyArcanaApiKey(req, res) {
  if (!ARCANA_API_KEY) {
    return true;
  }
  const provided = req.get('x-api-key');
  if (provided && provided === ARCANA_API_KEY) {
    return true;
  }
  res.status(401).json({ error: 'unauthorized', requestId: req.requestId });
  return false;
}

function readTelegramInitData(req) {
  const preferredHeader = req.get('x-telegram-initdata');
  if (typeof preferredHeader === 'string' && preferredHeader.trim()) {
    return { initData: preferredHeader.trim(), source: 'x-telegram-initdata' };
  }
  const fallbackHeaders = ['x-telegram-init-data', 'x-tg-init-data'];
  for (const headerName of fallbackHeaders) {
    const value = req.get(headerName);
    if (typeof value === 'string' && value.trim()) {
      return { initData: value.trim(), source: headerName };
    }
  }
  const bodyInitData =
    typeof req.body?.initData === 'string' ? req.body.initData.trim() : '';
  if (bodyInitData) {
    return { initData: bodyInitData, source: 'body' };
  }
  return { initData: '', source: null };
}

function logTelegramAuthFailure({ req, reason, hasBodyInitData, hasHeaderInitData }) {
  console.warn(
    JSON.stringify({
      event: 'telegram_auth_failed',
      requestId: req.requestId,
      path: req.originalUrl,
      reason,
      hasBodyInitData,
      hasHeaderInitData
    })
  );
}

function requireTelegramInitData(req, res) {
  const bodyInitData =
    typeof req.body?.initData === 'string' ? req.body.initData.trim() : '';
  const { initData, source } = readTelegramInitData(req);
  const headerCandidates = [
    'x-telegram-initdata',
    'x-telegram-init-data',
    'x-tg-init-data'
  ];
  const hasHeaderInitData = headerCandidates.some((headerName) => {
    const value = req.get(headerName);
    return typeof value === 'string' && value.trim();
  });
  const hasBodyInitData = Boolean(bodyInitData);
  const initDataLength = initData.length;
  if (!initData) {
    console.warn(
      JSON.stringify({
        event: 'telegram_auth_check',
        requestId: req.requestId,
        path: req.originalUrl,
        initData_present: false,
        initData_length: initDataLength,
        source,
        validation_ok: false
      })
    );
    logTelegramAuthFailure({
      req,
      reason: 'missing_initData',
      hasBodyInitData,
      hasHeaderInitData
    });
    res.status(401).json({
      error: 'unauthorized',
      reason: 'missing_initData',
      requestId: req.requestId
    });
    return null;
  }
  const validation = validateTelegramInitData(initData, TELEGRAM_BOT_TOKEN);
  if (!validation.ok) {
    const reason = 'invalid_initData';
    console.warn(
      JSON.stringify({
        event: 'telegram_auth_check',
        requestId: req.requestId,
        path: req.originalUrl,
        initData_present: true,
        initData_length: initDataLength,
        source,
        validation_ok: false
      })
    );
    logTelegramAuthFailure({
      req,
      reason,
      hasBodyInitData,
      hasHeaderInitData
    });
    res.status(401).json({
      error: 'unauthorized',
      reason,
      requestId: req.requestId
    });
    return null;
  }
  console.log(
    JSON.stringify({
      event: 'telegram_auth_check',
      requestId: req.requestId,
      path: req.originalUrl,
      initData_present: true,
      initData_length: initDataLength,
      source,
      validation_ok: true
    })
  );
  return initData;
}

app.use((req, res, next) => {
  const incomingRequestId = req.get('x-request-id');
  const requestId = incomingRequestId || uuidv4();
  req.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  const startTime = Date.now();
  res.on('finish', () => {
    const durationMs = Date.now() - startTime;
    console.log(
      JSON.stringify({
        method: req.method,
        path: req.originalUrl,
        status: res.statusCode,
        duration_ms: durationMs,
        requestId
      })
    );
  });

  next();
});

const APP_VERSION = process.env.APP_VERSION || '2026-02-08-1';
const PUBLIC_ROOT = process.env.PUBLIC_ROOT || path.join(__dirname, 'public');
const PUBLIC_INDEX = path.join(PUBLIC_ROOT, 'index.html');
const API_BASE_URL_ENV = process.env.API_BASE_URL || process.env.BASE_URL || '';
const ASSETS_BASE_URL_ENV = process.env.ASSETS_BASE_URL || 'https://cdn.basilarcana.com';
const STARS_PACK_FULL_XTR = 5;
const STARS_PACK_WEEK_XTR = Number(process.env.STARS_PACK_WEEK_XTR || 99);
const STARS_PACK_MONTH_XTR = Number(process.env.STARS_PACK_MONTH_XTR || 499);
const STARS_PACK_YEAR_XTR = Math.min(
  4999,
  Number(process.env.STARS_PACK_YEAR_XTR || 4999)
);
const STARS_PACK_FIVE_CARDS_SINGLE_XTR = Number(
  process.env.STARS_PACK_FIVE_CARDS_SINGLE_XTR || 1
);

const ENERGY_STARS_PACKS = {
  full: { energyAmount: 100, starsAmount: STARS_PACK_FULL_XTR, grantType: 'energy' },
  week_unlimited: { energyAmount: 0, starsAmount: STARS_PACK_WEEK_XTR, grantType: 'unlimited_week' },
  month_unlimited: { energyAmount: 0, starsAmount: STARS_PACK_MONTH_XTR, grantType: 'unlimited_month' },
  year_unlimited: { energyAmount: 0, starsAmount: STARS_PACK_YEAR_XTR, grantType: 'unlimited_year' },
  five_cards_single: {
    energyAmount: 0,
    starsAmount: STARS_PACK_FIVE_CARDS_SINGLE_XTR,
    grantType: 'five_cards_single'
  }
};

function normalizeConsentDecision(value) {
  const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (raw === 'accepted' || raw === 'rejected' || raw === 'revoked') {
    return raw;
  }
  return '';
}

function resolveUserName(telegramUser, userId) {
  const firstName = typeof telegramUser?.firstName === 'string' ? telegramUser.firstName.trim() : '';
  const lastName = typeof telegramUser?.lastName === 'string' ? telegramUser.lastName.trim() : '';
  const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();
  if (fullName) {
    return fullName;
  }
  const username = typeof telegramUser?.username === 'string' ? telegramUser.username.trim() : '';
  if (username) {
    return `@${username}`;
  }
  return `Пользователь #${userId}`;
}

function resolveUserUsername(telegramUser) {
  const username = typeof telegramUser?.username === 'string' ? telegramUser.username.trim() : '';
  if (username) {
    return `@${username}`;
  }
  return '—';
}

async function sendTelegramBotMessage({ chatId, text }) {
  const response = await fetch(
    `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        disable_web_page_preview: true
      })
    }
  );
  const responseText = await response.text();
  let parsed = null;
  try {
    parsed = JSON.parse(responseText);
  } catch (_) {
    parsed = null;
  }
  return {
    ok: response.ok && Boolean(parsed?.ok),
    status: response.status,
    description:
      typeof parsed?.description === 'string'
        ? parsed.description
        : responseText.slice(0, 300)
  };
}

async function upsertTelegramUserFromRequest(req, locale = null) {
  if (!hasDb()) {
    return;
  }
  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : null;
  if (!telegramUserId) {
    return;
  }
  const resolvedLocale =
    locale ||
    (typeof req.telegram?.user?.languageCode === 'string' &&
    req.telegram.user.languageCode.trim()
      ? normalizeLocale(req.telegram.user.languageCode)
      : null);
  await upsertUserProfile({
    telegramUserId,
    telegramUser: req.telegram?.user,
    locale: resolvedLocale
  });
}

async function tryClaimReferralForRequest(req) {
  if (!hasDb()) {
    return;
  }
  const referredUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : null;
  if (!referredUserId) {
    return;
  }
  const startParam = typeof req.telegram?.startParam === 'string' ? req.telegram.startParam : '';
  if (!startParam) {
    return;
  }
  const referrerUserId = parseReferrerUserIdFromStartParam(startParam);
  if (!referrerUserId) {
    return;
  }
  const claim = await claimReferralBonus({
    referredUserId,
    referrerUserId,
    startParam,
    bonusCredits: 20
  });
  if (claim.claimed) {
    console.log(
      JSON.stringify({
        event: 'referral_claimed',
        requestId: req.requestId,
        referredUserId,
        referrerUserId,
        bonusCredits: claim.bonusCredits,
        referrerCredits: claim.freeFiveCardsCredits
      })
    );
  }
}

async function logHistoryFromRequest({
  req,
  queryType,
  question,
  locale = null
}) {
  if (!hasDb()) {
    return;
  }
  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : null;
  if (!telegramUserId) {
    return;
  }
  await logUserQuery({
    telegramUserId,
    queryType,
    question,
    locale
  });
}

function parseUserIdFromInitData(initData) {
  if (!initData || typeof initData !== 'string') {
    return null;
  }
  try {
    const params = new URLSearchParams(initData);
    const userRaw = params.get('user');
    if (!userRaw) {
      return null;
    }
    const user = JSON.parse(userRaw);
    const userId = Number(user?.id);
    if (!Number.isFinite(userId)) {
      return null;
    }
    return userId;
  } catch (_) {
    return null;
  }
}

async function createTelegramInvoiceLink({
  title,
  description,
  payload,
  starsAmount
}) {
  const response = await fetch(
    `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/createInvoiceLink`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title,
        description,
        payload,
        currency: 'XTR',
        prices: [
          {
            label: title,
            amount: Math.max(1, Math.round(starsAmount))
          }
        ]
      })
    }
  );
  const responseText = await response.text();
  let parsed = null;
  try {
    parsed = JSON.parse(responseText);
  } catch (_) {
    parsed = null;
  }
  return {
    ok: response.ok && Boolean(parsed?.ok) && typeof parsed?.result === 'string',
    status: response.status,
    invoiceLink: typeof parsed?.result === 'string' ? parsed.result : '',
    errorDescription:
      typeof parsed?.description === 'string' ? parsed.description : responseText.slice(0, 300)
  };
}

function buildConfigPayload(req) {
  const apiBaseUrl =
    API_BASE_URL_ENV || `${req.protocol}://${req.get('host')}`;
  return {
    apiBaseUrl,
    assetsBaseUrl: ASSETS_BASE_URL_ENV,
    appVersion: APP_VERSION
  };
}

function normalizeLocale(value) {
  const code = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (code.startsWith('ru')) {
    return 'ru';
  }
  if (code.startsWith('kk') || code.startsWith('kz')) {
    return 'kk';
  }
  return 'en';
}

function encodeReferralCode(userId) {
  const numeric = Number(userId);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return '';
  }
  return `u${numeric.toString(36)}`;
}

function decodeReferralCode(code) {
  const raw = typeof code === 'string' ? code.trim().toLowerCase() : '';
  if (!raw.startsWith('u') || raw.length < 2) {
    return null;
  }
  const payload = raw.slice(1);
  if (!/^[0-9a-z]+$/.test(payload)) {
    return null;
  }
  const decoded = parseInt(payload, 36);
  if (!Number.isFinite(decoded) || decoded <= 0) {
    return null;
  }
  return decoded;
}

function parseReferrerUserIdFromStartParam(startParam) {
  const raw = typeof startParam === 'string' ? startParam.trim() : '';
  if (!raw.startsWith('ref_')) {
    return null;
  }
  return decodeReferralCode(raw.slice(4));
}

function buildReferralLink(userId) {
  const code = encodeReferralCode(userId);
  if (!code) {
    return 'https://t.me/tarot_arkana_bot/app';
  }
  return `https://t.me/tarot_arkana_bot/app?startapp=ref_${code}`;
}

function buildSofiaPromo(locale) {
  const normalized = normalizeLocale(locale);
  if (normalized === 'ru') {
    return 'Хочешь глубже и точнее? Обратись к профессиональному тарологу и астрологу Софии Нокс.\nПрофиль: https://t.me/SofiaKnoxx\nОформи подписку в нашем Telegram-боте и получи персональную консультацию.';
  }
  if (normalized === 'kk') {
    return 'Терең әрі нақты талдау керек пе? Кәсіби таролог және астролог София Ноксқа жүгін.\nПрофиль: https://t.me/SofiaKnoxx\nБіздің Telegram-ботта жазылымды қосып, жеке консультация ал.';
  }
  return 'Want a deeper and more precise reading? Connect with professional tarot reader and astrologer Sofia Knox.\nProfile: https://t.me/SofiaKnoxx\nActivate a subscription in our Telegram bot to get a personal consultation.';
}

function appendSofiaPromo(text, locale) {
  const source = typeof text === 'string' ? text.trim() : '';
  if (source.includes('@SofiaKnoxx') || source.includes('t.me/SofiaKnoxx')) {
    return source;
  }
  const promo = buildSofiaPromo(locale);
  return source ? `${source}\n\n${promo}` : promo;
}

function appendPromoToReadingResult(parsed, locale) {
  if (!parsed || typeof parsed !== 'object') {
    return parsed;
  }
  const next = { ...parsed };
  next.action = appendSofiaPromo(next.action, locale);
  next.fullText = appendSofiaPromo(next.fullText, locale);
  if (typeof next.detailsText === 'string') {
    next.detailsText = appendSofiaPromo(next.detailsText, locale);
  }
  return next;
}

app.get('/config.json', (req, res) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.json(buildConfigPayload(req));
});

const staticOptions = {
  index: false,
  fallthrough: true,
  setHeaders: (res, filePath) => {
    const filename = path.basename(filePath);
    if (filename === 'index.html') {
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
      return;
    }
    if (filename === 'flutter.js' || filename === 'flutter_bootstrap.js') {
      res.setHeader('Cache-Control', 'no-cache, max-age=0');
      return;
    }
    if (filePath.includes(`${path.sep}assets${path.sep}`)) {
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    }
  }
};

if (fs.existsSync(PUBLIC_ROOT)) {
  app.get('/v/:version', (req, res) => res.redirect(302, '/'));
  app.get('/v/:version/', (req, res) => res.redirect(302, '/'));
  app.get('/v/:version/*', (req, res) => {
    const restPath = req.params[0] ? `/${req.params[0]}` : '/';
    return res.redirect(302, restPath);
  });

  app.use(express.static(PUBLIC_ROOT, staticOptions));
}

app.get('/', (req, res) => {
  if (fs.existsSync(PUBLIC_INDEX)) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    return res.sendFile(PUBLIC_INDEX);
  }
  return res.json({
    ok: true,
    name: 'basils-arcana',
    message: 'Basil’s Arcana API',
    requestId: req.requestId
  });
});

app.get('/health', (req, res) => {
  res.json({ ok: true, name: 'basils-arcana', requestId: req.requestId });
});

app.get('/api/reading/availability', (req, res) => {
  const available = Boolean(OPENAI_API_KEY);
  return res.json({
    ok: available,
    available,
    requestId: req.requestId
  });
});

app.get('/api/history/queries', telegramAuthMiddleware, async (req, res) => {
  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }
  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!telegramUserId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }
  const limitRaw = Number(req.query?.limit);
  const limit = Number.isFinite(limitRaw) ? limitRaw : 20;
  await upsertTelegramUserFromRequest(req);
  await tryClaimReferralForRequest(req);
  const items = await listRecentUserQueries({
    telegramUserId,
    limit
  });
  return res.json({
    ok: true,
    items,
    requestId: req.requestId
  });
});

app.delete('/api/history/queries', telegramAuthMiddleware, async (req, res) => {
  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }
  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!telegramUserId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }
  await upsertTelegramUserFromRequest(req);
  await tryClaimReferralForRequest(req);
  const result = await clearUserQueryHistory({ telegramUserId });
  return res.json({
    ok: true,
    deletedCount: result.deletedCount,
    requestId: req.requestId
  });
});

app.get('/api/user/dashboard', telegramAuthMiddleware, async (req, res) => {
  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }
  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!telegramUserId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }
  await upsertTelegramUserFromRequest(req);
  await tryClaimReferralForRequest(req);
  const data = await getUserDashboard({ telegramUserId });
  return res.json({
    ok: true,
    profile: data.profile,
    perks: data.perks,
    referrals: data.referrals,
    services: data.services,
    referral: {
      code: encodeReferralCode(telegramUserId),
      link: buildReferralLink(telegramUserId)
    },
    requestId: req.requestId
  });
});

app.post('/api/premium/five-cards/consume', telegramAuthMiddleware, async (req, res) => {
  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }
  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!telegramUserId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }
  await upsertTelegramUserFromRequest(req);
  await tryClaimReferralForRequest(req);
  const result = await consumeFreeFiveCardsCredit({
    telegramUserId,
    reason: 'spread_five_unlock'
  });
  return res.json({
    ok: result.ok,
    consumed: result.consumed,
    remaining: result.remaining,
    requestId: req.requestId
  });
});

app.post('/api/payments/stars/invoice', telegramAuthMiddleware, async (req, res) => {
  if (!TELEGRAM_BOT_TOKEN) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_telegram_bot_token',
      requestId: req.requestId
    });
  }

  const packId = typeof req.body?.packId === 'string' ? req.body.packId.trim() : '';
  const pack = ENERGY_STARS_PACKS[packId];
  if (!pack) {
    return res.status(400).json({
      error: 'invalid_pack',
      requestId: req.requestId
    });
  }
  if (!Number.isFinite(pack.starsAmount) || pack.starsAmount <= 0) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'invalid_stars_pack_config',
      requestId: req.requestId
    });
  }

  const userId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!userId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }
  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }

  const payload = `energy:${packId}:user:${userId}:ts:${Date.now()}`;
  const title =
    pack.grantType === 'unlimited_week'
      ? 'Unlimited energy for 1 week'
      : pack.grantType === 'unlimited_month'
      ? 'Unlimited energy for 1 month'
      :
    pack.grantType === 'unlimited_year'
      ? 'Unlimited energy for 1 year'
      : pack.grantType === 'five_cards_single'
      ? 'Premium five-card reading'
      : 'Top up to 100%';
  const description =
    pack.grantType === 'unlimited_week'
      ? 'Unlock unlimited oracle energy for 7 days'
      : pack.grantType === 'unlimited_month'
      ? 'Unlock unlimited oracle energy for 30 days'
      :
    pack.grantType === 'unlimited_year'
      ? 'Unlock unlimited oracle energy for 365 days'
      : pack.grantType === 'five_cards_single'
      ? 'Unlock one premium five-card spread'
      : 'Restore oracle energy to 100%';

  try {
    await upsertTelegramUserFromRequest(req);
    await tryClaimReferralForRequest(req);
    const result = await createTelegramInvoiceLink({
      title,
      description,
      payload,
      starsAmount: pack.starsAmount
    });
    if (!result.ok) {
      return res.status(502).json({
        error: 'telegram_invoice_create_failed',
        status: result.status,
        details: result.errorDescription,
        requestId: req.requestId
      });
    }
    await saveCreatedInvoice({
      telegramUserId: userId,
      packId,
      grantType: pack.grantType,
      energyAmount: pack.energyAmount,
      starsAmount: Math.round(pack.starsAmount),
      payload,
      invoiceLink: result.invoiceLink
    });
    return res.json({
      ok: true,
      packId,
      grantType: pack.grantType,
      energyAmount: pack.energyAmount,
      starsAmount: Math.round(pack.starsAmount),
      invoiceLink: result.invoiceLink,
      payload,
      requestId: req.requestId
    });
  } catch (error) {
    return res.status(502).json({
      error: 'telegram_invoice_create_failed',
      details: error?.message ? String(error.message).slice(0, 300) : 'unknown',
      requestId: req.requestId
    });
  }
});

app.post('/api/payments/stars/confirm', telegramAuthMiddleware, async (req, res) => {
  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }
  const userId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!userId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }

  const payload = typeof req.body?.payload === 'string' ? req.body.payload.trim() : '';
  const statusRaw = typeof req.body?.status === 'string' ? req.body.status.trim().toLowerCase() : '';
  const allowedStatus = new Set(['paid', 'cancelled', 'pending', 'failed']);
  if (!payload) {
    return res.status(400).json({
      error: 'invalid_payload',
      requestId: req.requestId
    });
  }
  if (!allowedStatus.has(statusRaw)) {
    return res.status(400).json({
      error: 'invalid_status',
      requestId: req.requestId
    });
  }

  try {
    await upsertTelegramUserFromRequest(req);
    await tryClaimReferralForRequest(req);
    const result = await confirmInvoiceStatus({
      telegramUserId: userId,
      payload,
      status: statusRaw
    });
    if (!result.ok) {
      return res.status(400).json({
        error: result.reason || 'confirm_failed',
        requestId: req.requestId
      });
    }
    return res.json({
      ok: true,
      payload,
      status: statusRaw,
      grantApplied: result.grantApplied,
      packId: result.packId,
      grantType: result.grantType,
      energyAmount: result.energyAmount,
      starsAmount: result.starsAmount,
      totalEnergyGranted: result.totalEnergyGranted,
      unlimitedUntil: result.unlimitedUntil,
      requestId: req.requestId
    });
  } catch (error) {
    return res.status(502).json({
      error: 'confirm_failed',
      details: error?.message ? String(error.message).slice(0, 300) : 'unknown',
      requestId: req.requestId
    });
  }
});

app.post('/api/sofia/consent', telegramAuthMiddleware, async (req, res) => {
  if (!TELEGRAM_BOT_TOKEN) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_telegram_bot_token',
      requestId: req.requestId
    });
  }
  const notifyChatId = SOFIA_NOTIFY_CHAT_ID.trim();
  if (!notifyChatId) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_sofia_notify_chat_id',
      requestId: req.requestId
    });
  }

  const decision = normalizeConsentDecision(req.body?.decision);
  if (!decision) {
    return res.status(400).json({
      error: 'invalid_decision',
      requestId: req.requestId
    });
  }

  const telegramUserId =
    Number.isFinite(Number(req.telegram?.userId)) && Number(req.telegram?.userId) > 0
      ? Number(req.telegram.userId)
      : parseUserIdFromInitData(readTelegramInitData(req).initData);
  if (!telegramUserId) {
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'telegram_user_missing',
      requestId: req.requestId
    });
  }

  if (!hasDb()) {
    return res.status(503).json({
      error: 'storage_unavailable',
      reason: 'database_not_configured',
      requestId: req.requestId
    });
  }

  await upsertTelegramUserFromRequest(req);
  await tryClaimReferralForRequest(req);
  const state = await recordSofiaConsent({
    telegramUserId,
    decision
  });
  if (state.duplicate) {
    return res.json({
      ok: true,
      duplicate: true,
      totalUsers: state.totalUsers,
      requestId: req.requestId
    });
  }

  const userName = resolveUserName(req.telegram?.user, telegramUserId);
  const username = resolveUserUsername(req.telegram?.user);
  const message =
    decision === 'accepted'
      ? state.previousDecision === 'revoked'
        ? `🔁 Пользователь снова дал согласие на передачу контакта\nИмя: ${userName}\nUsername: ${username}\nВсего пользователей: ${state.totalUsers}`
        : `✅ Пользователь согласился на передачу контакта\nИмя: ${userName}\nUsername: ${username}\nВсего пользователей: ${state.totalUsers}`
      : decision === 'revoked'
        ? `⛔️ Пользователь отозвал согласие на передачу контакта\nИмя: ${userName}\nUsername: ${username}\nВсего пользователей: ${state.totalUsers}`
        : `ℹ️ Добавился еще 1 пользователь без передачи имени и username\nВсего пользователей: ${state.totalUsers}`;

  try {
    const result = await sendTelegramBotMessage({
      chatId: notifyChatId,
      text: message
    });
    if (!result.ok) {
      return res.status(502).json({
        error: 'telegram_send_failed',
        status: result.status,
        details: result.description,
        requestId: req.requestId
      });
    }
    return res.json({
      ok: true,
      decision,
      totalUsers: state.totalUsers,
      requestId: req.requestId
    });
  } catch (error) {
    return res.status(502).json({
      error: 'telegram_send_failed',
      details: error?.message ? String(error.message).slice(0, 300) : 'unknown',
      requestId: req.requestId
    });
  }
});

app.get('/api/openai/health', (req, res) => {
  const hasKey = Boolean(OPENAI_API_KEY);
  return res.json({
    ok: hasKey,
    hasKey,
    hasModel: Boolean(process.env.OPENAI_MODEL),
    requestId: req.requestId
  });
});

app.get('/debug/openai', async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.json({
      hasKey: false,
      model: null,
      ok: false,
      status: null,
      errorType: 'MissingOpenAIKey',
      errorMessage: 'Missing OPENAI_API_KEY',
      bodyPreview: '',
      requestId: req.requestId
    });
  }

  const result = await listModels({ requestId: req.requestId, timeoutMs: 10000 });
  return res.json({
    hasKey: true,
    model: result.model,
    ok: result.ok,
    status: result.status,
    errorType: result.errorType,
    errorMessage: result.errorMessage,
    bodyPreview: result.bodyPreview,
    requestId: req.requestId
  });
});

app.get('/debug/openai-generate', async (req, res) => {
  const hasKey = Boolean(OPENAI_API_KEY);
  if (!hasKey) {
    return res.json({
      hasKey: false,
      model: null,
      ok: false,
      status: null,
      duration_ms: null,
      upstream: { code: null, type: 'MissingOpenAIKey', message: 'Missing OPENAI_API_KEY' },
      samplePreview: null,
      requestId: req.requestId
    });
  }

  const debugMessages = [
    {
      role: 'system',
      content:
        'Return a short JSON object with keys "ok" and "message". Keep the message under 60 characters.'
    },
    {
      role: 'user',
      content: 'Say hello from Basil’s Arcana.'
    }
  ];

  const startTime = Date.now();
  try {
    const result = await createResponse(debugMessages, { requestId: req.requestId });
    const durationMs = Date.now() - startTime;
    const samplePreview = JSON.stringify(result.parsed).slice(0, 300);
    return res.json({
      hasKey: true,
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      ok: true,
      status: result.meta.status,
      duration_ms: durationMs,
      upstream: { code: null, type: null, message: null },
      samplePreview,
      requestId: req.requestId
    });
  } catch (error) {
    const durationMs = Date.now() - startTime;
    const upstream = {
      code: error instanceof OpenAIRequestError ? error.errorCode : null,
      type: error instanceof OpenAIRequestError ? error.errorType : error.name,
      message: error.message ? error.message.slice(0, 300) : null
    };
    return res.json({
      hasKey: true,
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      ok: false,
      status: error instanceof OpenAIRequestError ? error.status : null,
      duration_ms: durationMs,
      upstream,
      samplePreview: null,
      requestId: req.requestId
    });
  }
});

app.get('/api/telegram/debug', (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'not_found', requestId: req.requestId });
  }
  const token = TELEGRAM_BOT_TOKEN;
  const botId = token ? token.split(':')[0] : null;
  const tokenFingerprint = token
    ? crypto.createHash('sha256').update(token).digest('hex').slice(0, 12)
    : null;
  return res.json({
    hasToken: Boolean(token),
    botId,
    tokenFingerprint,
    requestId: req.requestId
  });
});

app.post('/api/debug/telegram', (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'not_found', requestId: req.requestId });
  }
  const headerValue =
    req.get('x-telegram-initdata') ||
    req.get('x-telegram-init-data') ||
    req.get('x-tg-init-data') ||
    '';
  const bodyValue =
    typeof req.body?.initData === 'string' ? req.body.initData : '';
  const headerTrimmed = headerValue.trim();
  const bodyTrimmed = bodyValue.trim();
  return res.json({
    hasHeader: Boolean(headerTrimmed),
    hasBody: Boolean(bodyTrimmed),
    headerLen: headerTrimmed.length,
    bodyLen: bodyTrimmed.length
  });
});

if (RATE_LIMIT_MAX != null) {
  const apiLimiter = rateLimit({
    windowMs: RATE_LIMIT_WINDOW_MS ?? 60000,
    max: RATE_LIMIT_MAX,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) =>
      res.status(429).json({ error: 'rate_limited', requestId: req.requestId })
  });
  app.use('/api', apiLimiter);
}

app.post('/api/reading/generate', telegramAuthMiddleware, async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_openai_api_key',
      requestId: req.requestId
    });
  }
  const mode = req.query.mode || 'deep';
  if (
    mode !== 'fast' &&
    mode !== 'deep' &&
    mode !== 'life_areas' &&
    mode !== 'details_relationships_career'
  ) {
    return res.status(400).json({
      error: 'invalid_mode',
      requestId: req.requestId
    });
  }
  const error = validateReadingRequest(req.body);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const locale = normalizeLocale(req.body?.language);
    await upsertTelegramUserFromRequest(req, locale);
    await tryClaimReferralForRequest(req);
    const messages = buildPromptMessages(req.body, mode);
    const result = await createResponse(messages, {
      requestId: req.requestId
    });
    const enriched = appendPromoToReadingResult(result.parsed, locale);
    await logHistoryFromRequest({
      req,
      queryType: `reading_${String(mode)}`,
      question: req.body?.userQuestion || req.body?.question,
      locale
    });
    return res.json({ ...enriched, requestId: req.requestId });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };

    console.error(
      JSON.stringify({
        event: 'openai_upstream_error',
        requestId: req.requestId,
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );

    return res
      .status(502)
      .json({
        error: 'upstream_failed',
        requestId: req.requestId,
        upstream
      });
  }
});

app.post('/api/reading/generate_web', telegramAuthMiddleware, async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_openai_api_key',
      requestId: req.requestId
    });
  }
  const mode = req.query.mode || 'deep';
  if (
    mode !== 'fast' &&
    mode !== 'deep' &&
    mode !== 'life_areas' &&
    mode !== 'details_relationships_career'
  ) {
    return res.status(400).json({
      error: 'invalid_mode',
      requestId: req.requestId
    });
  }
  const { payload } = req.body || {};
  const error = validateReadingRequest(payload);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const locale = normalizeLocale(payload?.language);
    await upsertTelegramUserFromRequest(req, locale);
    await tryClaimReferralForRequest(req);
    const messages = buildPromptMessages(payload, mode);
    const result = await createResponse(messages, {
      requestId: req.requestId
    });
    const enriched = appendPromoToReadingResult(result.parsed, locale);
    await logHistoryFromRequest({
      req,
      queryType: `reading_${String(mode)}`,
      question: payload?.userQuestion || payload?.question,
      locale
    });
    return res.json({ ...enriched, requestId: req.requestId });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };

    console.error(
      JSON.stringify({
        event: 'openai_upstream_error',
        requestId: req.requestId,
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );

    return res
      .status(502)
      .json({
        error: 'upstream_failed',
        requestId: req.requestId,
        upstream
      });
  }
});

app.post('/api/reading/details', telegramAuthMiddleware, async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_openai_api_key',
      requestId: req.requestId
    });
  }
  const error = validateDetailsRequest(req.body);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const locale = normalizeLocale(req.body?.locale);
    await upsertTelegramUserFromRequest(req, locale);
    await tryClaimReferralForRequest(req);
    const messages = buildDetailsPrompt(req.body);
    const result = await createTextResponse(messages, {
      requestId: req.requestId,
      timeoutMs: 35000,
    });
    const detailsText = result.text.trim();
    if (!detailsText) {
      throw new OpenAIRequestError('Empty OpenAI response', {
        status: result.meta?.status,
      });
    }
    const durationMs = Date.now() - startTime;
    console.log(
      JSON.stringify({
        event: 'details_request',
        requestId: req.requestId,
        status: 200,
        duration_ms: durationMs,
      })
    );
    return res.json({
      detailsText: appendSofiaPromo(detailsText, locale),
      requestId: req.requestId
    });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    if (err?.name === 'AbortError') {
      console.error(
        JSON.stringify({
          event: 'details_timeout',
          requestId: req.requestId,
          status: 504,
          duration_ms: durationMs,
        })
      );
      return res.status(504).json({ error: 'timeout', requestId: req.requestId });
    }
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };

    console.error(
      JSON.stringify({
        event: 'details_upstream_error',
        requestId: req.requestId,
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );
    return res
      .status(502)
      .json({
        error: 'upstream_failed',
        requestId: req.requestId,
        upstream
      });
  }
});

app.post('/api/natal-chart/generate', async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_openai_api_key',
      requestId: req.requestId
    });
  }
  if (!verifyArcanaApiKey(req, res)) {
    return;
  }
  const error = validateNatalChartRequest(req.body);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const messages = buildNatalChartPrompt(req.body);
    const result = await createTextResponse(messages, {
      requestId: req.requestId,
      timeoutMs: 35000,
    });
    const interpretation = result.text.trim();
    if (!interpretation) {
      throw new OpenAIRequestError('Empty OpenAI response', {
        status: result.meta?.status,
      });
    }
    const durationMs = Date.now() - startTime;
    console.log(
      JSON.stringify({
        event: 'natal_chart_request',
        requestId: req.requestId,
        status: 200,
        duration_ms: durationMs,
      })
    );
    return res.json({
      interpretation,
      requestId: req.requestId
    });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    if (err?.name === 'AbortError') {
      console.error(
        JSON.stringify({
          event: 'natal_chart_timeout',
          requestId: req.requestId,
          duration_ms: durationMs,
        })
      );
      return res.status(504).json({
        error: 'timeout',
        requestId: req.requestId,
      });
    }
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };
    console.error(
      JSON.stringify({
        event: 'natal_chart_error',
        requestId: req.requestId,
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );
    return res.status(502).json({
      error: 'upstream_failed',
      requestId: req.requestId,
      upstream
    });
  }
});

app.post('/api/natal-chart/generate_web', async (req, res) => {
  if (!OPENAI_API_KEY || !TELEGRAM_BOT_TOKEN) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: !OPENAI_API_KEY ? 'missing_openai_api_key' : 'missing_telegram_bot_token',
      requestId: req.requestId
    });
  }
  const { payload } = req.body || {};
  const initData = requireTelegramInitData(req, res);
  if (!initData) {
    return;
  }
  const error = validateNatalChartRequest(payload);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const messages = buildNatalChartPrompt(payload);
    const result = await createTextResponse(messages, {
      requestId: req.requestId,
      timeoutMs: 35000,
    });
    const interpretation = result.text.trim();
    if (!interpretation) {
      throw new OpenAIRequestError('Empty OpenAI response', {
        status: result.meta?.status,
      });
    }
    const durationMs = Date.now() - startTime;
    console.log(
      JSON.stringify({
        event: 'natal_chart_request',
        requestId: req.requestId,
        status: 200,
        duration_ms: durationMs,
      })
    );
    return res.json({
      interpretation,
      requestId: req.requestId
    });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    if (err?.name === 'AbortError') {
      console.error(
        JSON.stringify({
          event: 'natal_chart_timeout',
          requestId: req.requestId,
          duration_ms: durationMs,
        })
      );
      return res.status(504).json({
        error: 'timeout',
        requestId: req.requestId,
      });
    }
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };
    console.error(
      JSON.stringify({
        event: 'natal_chart_error',
        requestId: req.requestId,
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );
    return res.status(502).json({
      error: 'upstream_failed',
      requestId: req.requestId,
      upstream
    });
  }
});

app.post('/api/compatibility/generate', async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: 'missing_openai_api_key',
      requestId: req.requestId
    });
  }
  if (!verifyArcanaApiKey(req, res)) {
    return;
  }
  const error = validateCompatibilityRequest(req.body);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const messages = buildCompatibilityPrompt(req.body);
    const result = await createTextResponse(messages, {
      requestId: req.requestId,
      timeoutMs: 35000,
    });
    const interpretation = result.text.trim();
    if (!interpretation) {
      throw new OpenAIRequestError('Empty OpenAI response', {
        status: result.meta?.status,
      });
    }
    const durationMs = Date.now() - startTime;
    console.log(
      JSON.stringify({
        event: 'compatibility_request',
        requestId: req.requestId,
        status: 200,
        duration_ms: durationMs,
      })
    );
    return res.json({
      interpretation,
      requestId: req.requestId
    });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    if (err?.name === 'AbortError') {
      console.error(
        JSON.stringify({
          event: 'compatibility_timeout',
          requestId: req.requestId,
          duration_ms: durationMs,
        })
      );
      return res.status(504).json({
        error: 'timeout',
        requestId: req.requestId,
      });
    }
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };
    console.error(
      JSON.stringify({
        event: 'compatibility_error',
        requestId: req.requestId,
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );
    return res.status(502).json({
      error: 'upstream_failed',
      requestId: req.requestId,
      upstream
    });
  }
});

app.post('/api/compatibility/generate_web', async (req, res) => {
  if (!OPENAI_API_KEY || !TELEGRAM_BOT_TOKEN) {
    return res.status(503).json({
      error: 'server_misconfig',
      reason: !OPENAI_API_KEY ? 'missing_openai_api_key' : 'missing_telegram_bot_token',
      requestId: req.requestId
    });
  }
  const { payload } = req.body || {};
  const initData = requireTelegramInitData(req, res);
  if (!initData) {
    return;
  }
  const error = validateCompatibilityRequest(payload);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  const startTime = Date.now();
  try {
    const messages = buildCompatibilityPrompt(payload);
    const result = await createTextResponse(messages, {
      requestId: req.requestId,
      timeoutMs: 35000,
    });
    const interpretation = result.text.trim();
    if (!interpretation) {
      throw new OpenAIRequestError('Empty OpenAI response', {
        status: result.meta?.status,
      });
    }
    const durationMs = Date.now() - startTime;
    console.log(
      JSON.stringify({
        event: 'compatibility_request',
        requestId: req.requestId,
        status: 200,
        duration_ms: durationMs,
      })
    );
    return res.json({
      interpretation,
      requestId: req.requestId
    });
  } catch (err) {
    const durationMs = Date.now() - startTime;
    if (err?.name === 'AbortError') {
      console.error(
        JSON.stringify({
          event: 'compatibility_timeout',
          requestId: req.requestId,
          duration_ms: durationMs,
        })
      );
      return res.status(504).json({
        error: 'timeout',
        requestId: req.requestId,
      });
    }
    const upstream = {
      status: err instanceof OpenAIRequestError ? err.status : null,
      code: err instanceof OpenAIRequestError ? err.errorCode : null,
      type: err instanceof OpenAIRequestError ? err.errorType : err.name,
      message: err.message ? err.message.slice(0, 300) : null
    };
    console.error(
      JSON.stringify({
        event: 'compatibility_error',
        requestId: req.requestId,
        duration_ms: durationMs,
        status: upstream.status,
        errorCode: upstream.code,
        errorType: upstream.type
      })
    );
    return res.status(502).json({
      error: 'upstream_failed',
      requestId: req.requestId,
      upstream
    });
  }
});

app.get('*', (req, res) => {
  if (req.path.startsWith('/api') || req.path === '/health' || req.path === '/config.json') {
    return res.status(404).json({ error: 'not_found', requestId: req.requestId });
  }
  if (fs.existsSync(PUBLIC_INDEX)) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    return res.sendFile(PUBLIC_INDEX);
  }
  return res.status(404).json({ error: 'not_found', requestId: req.requestId });
});

const missingRequired = [];
if (!OPENAI_API_KEY) {
  missingRequired.push('OPENAI_API_KEY');
}

if (missingRequired.length > 0) {
  console.error(
    `Missing required environment variables: ${missingRequired.join(', ')}`
  );
  process.exit(1);
}

if (!ARCANA_API_KEY && !TELEGRAM_BOT_TOKEN) {
  console.warn(
    'ARCANA_API_KEY or TELEGRAM_BOT_TOKEN is not set; running without auth.'
  );
}

async function startServer() {
  if (DATABASE_URL && DATABASE_URL.trim()) {
    initDb(DATABASE_URL);
    await ensureSchema();
    console.log(JSON.stringify({ event: 'db_ready' }));
  } else {
    console.warn(JSON.stringify({ event: 'db_missing', message: 'DATABASE_URL is not configured' }));
  }

  const port = Number(PORT) || 3000;
  app.listen(port, () => {
    const region =
      process.env.RAILWAY_REGION ||
      process.env.AWS_REGION ||
      process.env.FLY_REGION ||
      process.env.VERCEL_REGION ||
      '';
    console.log(
      JSON.stringify({
        event: 'startup',
        openaiKeyPresent: Boolean(OPENAI_API_KEY),
        nodeEnv: process.env.NODE_ENV || '',
        nodeVersion: process.version,
        region
      })
    );
    console.log(`Basil's Arcana API listening on ${port}`);
  });
}

startServer().catch((error) => {
  console.error('Server startup failed', error);
  process.exit(1);
});
