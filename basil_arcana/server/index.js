const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const { buildPromptMessages, buildDetailsPrompt } = require('./src/prompt');
const {
  createResponse,
  createTextResponse,
  listModels,
  OpenAIRequestError
} = require('./src/openai_client');
const { validateReadingRequest, validateDetailsRequest } = require('./src/validate');
const {
  ARCANA_API_KEY,
  PORT,
  RATE_LIMIT_MAX,
  RATE_LIMIT_WINDOW_MS,
  OPENAI_API_KEY,
  TELEGRAM_BOT_TOKEN
} = require('./src/config');
const { validateTelegramInitData } = require('./src/telegram');

const app = express();

app.set('trust proxy', 1);

app.use(cors());
app.use(express.json({ limit: '1mb' }));

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
const VERSION_PREFIX = `/v/${APP_VERSION}`;
const PUBLIC_ROOT = process.env.PUBLIC_ROOT || path.join(__dirname, 'public');
const VERSIONED_ROOT = path.join(PUBLIC_ROOT, 'v', APP_VERSION);
const VERSIONED_INDEX = path.join(VERSIONED_ROOT, 'index.html');

if (fs.existsSync(VERSIONED_ROOT)) {
  app.use(
    VERSION_PREFIX,
    express.static(VERSIONED_ROOT, {
      index: false,
      fallthrough: true
    })
  );

  app.get(`${VERSION_PREFIX}/*`, (req, res) => {
    if (fs.existsSync(VERSIONED_INDEX)) {
      return res.sendFile(VERSIONED_INDEX);
    }
    return res.status(404).json({ error: 'not_found', requestId: req.requestId });
  });
}

app.get('/', (req, res) => {
  res.json({
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

app.post('/api/reading/generate', async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      requestId: req.requestId
    });
  }
  if (!verifyArcanaApiKey(req, res)) {
    return;
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

app.post('/api/reading/generate_web', async (req, res) => {
  if (!OPENAI_API_KEY || !TELEGRAM_BOT_TOKEN) {
    return res.status(503).json({
      error: 'server_misconfig',
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
  const { initData, payload } = req.body || {};
  if (typeof initData !== 'string' || !initData.trim()) {
    return res.status(400).json({
      error: 'missing_init_data',
      requestId: req.requestId
    });
  }
  const validation = validateTelegramInitData(initData, TELEGRAM_BOT_TOKEN);
  if (!validation.ok) {
    return res.status(401).json({
      error: validation.error || 'invalid_init_data',
      requestId: req.requestId
    });
  }
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

app.post('/api/reading/details', async (req, res) => {
  if (!OPENAI_API_KEY) {
    return res.status(503).json({
      error: 'server_misconfig',
      requestId: req.requestId
    });
  }
  if (!verifyArcanaApiKey(req, res)) {
    return;
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
