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
  buildNatalChartPrompt
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
  validateNatalChartRequest
} = require('./src/validate');
const {
  ARCANA_API_KEY,
  PORT,
  RATE_LIMIT_MAX,
  RATE_LIMIT_WINDOW_MS,
  OPENAI_API_KEY,
  TELEGRAM_BOT_TOKEN
} = require('./src/config');
const { validateTelegramInitData } = require('./src/telegram');
const { telegramAuthMiddleware } = require('./src/telegram_auth_middleware');

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
const STARS_PACK_SMALL_XTR = Number(process.env.STARS_PACK_SMALL_XTR || 25);
const STARS_PACK_MEDIUM_XTR = Number(process.env.STARS_PACK_MEDIUM_XTR || 45);
const STARS_PACK_FULL_XTR = Number(process.env.STARS_PACK_FULL_XTR || 75);
const STARS_PACK_YEAR_XTR = Number(process.env.STARS_PACK_YEAR_XTR || 1000);

const ENERGY_STARS_PACKS = {
  small: { energyAmount: 25, starsAmount: STARS_PACK_SMALL_XTR, grantType: 'energy' },
  medium: { energyAmount: 50, starsAmount: STARS_PACK_MEDIUM_XTR, grantType: 'energy' },
  full: { energyAmount: 100, starsAmount: STARS_PACK_FULL_XTR, grantType: 'energy' },
  year_unlimited: { energyAmount: 0, starsAmount: STARS_PACK_YEAR_XTR, grantType: 'unlimited_year' }
};

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

  const payload = `energy:${packId}:user:${userId}:ts:${Date.now()}`;
  const title =
    pack.grantType === 'unlimited_year'
      ? 'Unlimited energy for 1 year'
      : `Energy +${pack.energyAmount}%`;
  const description =
    pack.grantType === 'unlimited_year'
      ? 'Unlock unlimited oracle energy for 365 days'
      : `Top up oracle energy by ${pack.energyAmount}%`;

  try {
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
    const messages = buildPromptMessages(req.body, mode);
    const result = await createResponse(messages, {
      requestId: req.requestId
    });
    return res.json({ ...result.parsed, requestId: req.requestId });
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
    const messages = buildPromptMessages(payload, mode);
    const result = await createResponse(messages, {
      requestId: req.requestId
    });
    return res.json({ ...result.parsed, requestId: req.requestId });
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
    return res.json({ detailsText, requestId: req.requestId });
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
    return res.json({ interpretation, requestId: req.requestId });
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
    return res.json({ interpretation, requestId: req.requestId });
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
