const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');

const { buildPromptMessages } = require('./src/prompt');
const { createChatCompletion, listModels } = require('./src/openai_client');
const { validateReadingRequest } = require('./src/validate');
const {
  ARCANA_API_KEY,
  PORT,
  RATE_LIMIT_MAX,
  RATE_LIMIT_WINDOW_MS,
  OPENAI_API_KEY
} = require('./src/config');

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

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
app.use('/api', (req, res, next) => {
  if (!ARCANA_API_KEY) {
    return res.status(500).json({
      error: 'server_misconfig',
      requestId: req.requestId
    });
  }

  const providedKey = req.get('x-api-key');
  if (!providedKey || providedKey !== ARCANA_API_KEY) {
    return res.status(401).json({
      error: 'unauthorized',
      requestId: req.requestId
    });
  }

  return next();
});

app.post('/api/reading/generate', async (req, res) => {
  const mode = req.query.mode || 'deep';
  if (mode !== 'fast' && mode !== 'deep' && mode !== 'life_areas') {
    return res.status(400).json({
      error: 'invalid_mode',
      requestId: req.requestId
    });
  }
  const error = validateReadingRequest(req.body);
  if (error) {
    return res.status(400).json({ error, requestId: req.requestId });
  }

  try {
    const messages = buildPromptMessages(req.body, mode);
    const result = await createChatCompletion(messages, {
      requestId: req.requestId
    });
    return res.json({ ...result, requestId: req.requestId });
  } catch (err) {
    return res
      .status(502)
      .json({ error: 'upstream_failed', requestId: req.requestId });
  }
});

const port = PORT || 3000;
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
