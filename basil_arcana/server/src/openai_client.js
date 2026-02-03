const { OPENAI_API_KEY, OPENAI_MODEL } = require('./config');

const DEFAULT_TIMEOUT_MS = 65000;
const DEFAULT_RETRIES = 0;

class OpenAIRequestError extends Error {
  constructor(message, { status, errorType, errorCode, bodyPreview } = {}) {
    super(message);
    this.name = 'OpenAIRequestError';
    this.status = status;
    this.errorType = errorType;
    this.errorCode = errorCode;
    this.bodyPreview = bodyPreview;
  }
}

function logOpenAIEvent(payload) {
  console.log(
    JSON.stringify({
      event: 'openai_request',
      ...payload,
    })
  );
}

function buildBodyPreview(text) {
  if (!text) {
    return '';
  }
  return text.slice(0, 300);
}

function extractErrorDetails(text) {
  try {
    const parsed = JSON.parse(text);
    const error = parsed?.error;
    return {
      errorType: error?.type ?? null,
      errorCode: error?.code ?? null,
      errorMessage: error?.message ?? null,
    };
  } catch (err) {
    return { errorType: null, errorCode: null, errorMessage: null };
  }
}

async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}

async function createChatCompletion(
  messages,
  { requestId, timeoutMs = DEFAULT_TIMEOUT_MS, retries = DEFAULT_RETRIES } = {}
) {
  if (!OPENAI_API_KEY) {
    throw new Error('Missing OPENAI_API_KEY');
  }

  const startTime = Date.now();
  let logged = false;

  try {
    const response = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: OPENAI_MODEL,
          messages,
          temperature: 0.7,
          response_format: { type: 'json_object' },
        }),
      },
      timeoutMs
    );

    const durationMs = Date.now() - startTime;

    if (!response.ok) {
      const text = await response.text();
      const bodyPreview = buildBodyPreview(text);
      const details = extractErrorDetails(text);
      const errorMessage = details.errorMessage || `OpenAI error ${response.status}`;

      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: false,
        status: response.status,
        errorType: details.errorType,
        errorCode: details.errorCode,
        errorName: 'OpenAIRequestError',
        errorMessage,
        bodyPreview,
      });
      logged = true;

      throw new OpenAIRequestError(errorMessage, {
        status: response.status,
        errorType: details.errorType,
        errorCode: details.errorCode,
        bodyPreview,
      });
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      const errorMessage = 'Empty OpenAI response';
      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: false,
        status: response.status,
        errorName: 'OpenAIRequestError',
        errorMessage,
      });
      logged = true;
      throw new OpenAIRequestError(errorMessage, { status: response.status });
    }

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (error) {
      const bodyPreview = buildBodyPreview(content);
      const errorMessage = 'Invalid JSON response from OpenAI';
      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: false,
        status: response.status,
        errorName: 'OpenAIRequestError',
        errorMessage,
        bodyPreview,
      });
      logged = true;
      throw new OpenAIRequestError(errorMessage, {
        status: response.status,
        bodyPreview,
      });
    }

    logOpenAIEvent({
      requestId,
      model: OPENAI_MODEL,
      timeout_ms: timeoutMs,
      retries,
      duration_ms: durationMs,
      ok: true,
    });
    logged = true;

    return parsed;
  } catch (error) {
    if (!logged) {
      const durationMs = Date.now() - startTime;
      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: false,
        errorName: error.name,
        errorMessage: error.message,
      });
    }
    throw error;
  }
}

async function listModels({
  requestId,
  timeoutMs = 10000,
  retries = DEFAULT_RETRIES,
} = {}) {
  if (!OPENAI_API_KEY) {
    return {
      ok: false,
      status: null,
      errorType: 'MissingOpenAIKey',
      errorMessage: 'Missing OPENAI_API_KEY',
      bodyPreview: '',
      model: OPENAI_MODEL,
    };
  }

  const startTime = Date.now();
  let logged = false;

  try {
    const response = await fetchWithTimeout(
      'https://api.openai.com/v1/models',
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
      },
      timeoutMs
    );

    const durationMs = Date.now() - startTime;
    const text = await response.text();
    const bodyPreview = buildBodyPreview(text);

    if (!response.ok) {
      const details = extractErrorDetails(text);
      const errorMessage = details.errorMessage || `OpenAI error ${response.status}`;
      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: false,
        status: response.status,
        errorType: details.errorType,
        errorCode: details.errorCode,
        errorName: 'OpenAIRequestError',
        errorMessage,
        bodyPreview,
      });
      logged = true;
      return {
        ok: false,
        status: response.status,
        errorType: details.errorType || 'OpenAIRequestError',
        errorMessage,
        bodyPreview,
        model: OPENAI_MODEL,
      };
    }

    let modelFound = true;
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed?.data)) {
        modelFound = parsed.data.some((item) => item?.id === OPENAI_MODEL);
      }
    } catch (_) {
      modelFound = true;
    }

    const ok = modelFound;
    const errorType = modelFound ? null : 'ModelNotFound';
    const errorMessage = modelFound
      ? null
      : `Model ${OPENAI_MODEL} not found in OpenAI account`;

    logOpenAIEvent({
      requestId,
      model: OPENAI_MODEL,
      timeout_ms: timeoutMs,
      retries,
      duration_ms: durationMs,
      ok,
      status: response.status,
      errorType,
      errorMessage,
    });
    logged = true;

    return {
      ok,
      status: response.status,
      errorType,
      errorMessage,
      bodyPreview,
      model: OPENAI_MODEL,
    };
  } catch (error) {
    if (!logged) {
      const durationMs = Date.now() - startTime;
      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: false,
        errorName: error.name,
        errorMessage: error.message,
      });
    }

    return {
      ok: false,
      status: null,
      errorType: error.name,
      errorMessage: error.message,
      bodyPreview: '',
      model: OPENAI_MODEL,
    };
  }
}

module.exports = { createChatCompletion, listModels };
