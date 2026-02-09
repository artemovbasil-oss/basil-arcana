const { OPENAI_API_KEY, OPENAI_MODEL } = require('./config');

const DEFAULT_TIMEOUT_MS = 30000;
const DEFAULT_RETRIES = 2;
const RETRY_DELAYS_MS = [800, 2000];

class OpenAIRequestError extends Error {
  constructor(
    message,
    { status, errorType, errorCode, bodyPreview, durationMs } = {}
  ) {
    super(message);
    this.name = 'OpenAIRequestError';
    this.status = status;
    this.errorType = errorType;
    this.errorCode = errorCode;
    this.bodyPreview = bodyPreview;
    this.durationMs = durationMs;
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

function buildResponseInput(messages) {
  return messages.map((message) => ({
    role: message.role,
    content: [{ type: 'input_text', text: String(message.content) }],
  }));
}

function buildChatMessages(messages) {
  return messages.map((message) => ({
    role: message.role,
    content: String(message.content),
  }));
}

function extractResponsePayload(data) {
  const outputs = Array.isArray(data?.output) ? data.output : [];
  for (const output of outputs) {
    const contents = Array.isArray(output?.content) ? output.content : [];
    for (const content of contents) {
      if (content?.json && typeof content.json === 'object') {
        return { json: content.json };
      }
      if (typeof content?.text === 'string' && content.text.trim()) {
        return { text: content.text };
      }
    }
  }

  if (typeof data?.output_text === 'string' && data.output_text.trim()) {
    return { text: data.output_text };
  }

  return null;
}

function extractResponseText(data) {
  const payload = extractResponsePayload(data);
  if (payload?.text) {
    return payload.text;
  }
  if (payload?.json) {
    return JSON.stringify(payload.json);
  }
  return null;
}

function extractChatCompletionText(data) {
  const message = data?.choices?.[0]?.message?.content;
  if (typeof message === 'string' && message.trim()) {
    return message;
  }
  return null;
}

function shouldRetry(status) {
  return status === 429 || (status >= 500 && status <= 599);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function createResponse(
  messages,
  { requestId, timeoutMs = DEFAULT_TIMEOUT_MS, retries = DEFAULT_RETRIES } = {}
) {
  if (!OPENAI_API_KEY) {
    throw new Error('Missing OPENAI_API_KEY');
  }

  const startTime = Date.now();
  let logged = false;
  let attempt = 0;

  while (attempt <= retries) {
    attempt += 1;
    try {
      const response = await fetchWithTimeout(
        'https://api.openai.com/v1/responses',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: OPENAI_MODEL,
            input: buildResponseInput(messages),
            temperature: 0,
            text: {
              format: {
                type: 'json_object',
              },
            },
          }),
        },
        timeoutMs
      );

      const durationMs = Date.now() - startTime;

      if (!response.ok) {
        const text = await response.text();
        const bodyPreview = buildBodyPreview(text);
        const details = extractErrorDetails(text);
        const errorMessage =
          details.errorMessage || `OpenAI error ${response.status}`;

        const canFallback =
          response.status === 404 || details.errorType === 'invalid_request_error';

        if (canFallback) {
          return await createChatResponse(messages, {
            requestId,
            timeoutMs,
            retries,
            fallbackDurationMs: durationMs,
          });
        }

        if (shouldRetry(response.status) && attempt <= retries) {
          await sleep(RETRY_DELAYS_MS[Math.min(attempt - 1, RETRY_DELAYS_MS.length - 1)]);
          continue;
        }

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
          attempt,
        });
        logged = true;

        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          errorType: details.errorType,
          errorCode: details.errorCode,
          bodyPreview,
          durationMs,
        });
      }

      const data = await response.json();
      const payload = extractResponsePayload(data);
      if (!payload) {
        return await createChatResponse(messages, {
          requestId,
          timeoutMs,
          retries,
          fallbackDurationMs: durationMs,
        });
      }

      let parsed;
      try {
        parsed =
          payload.json && typeof payload.json === 'object'
            ? payload.json
            : JSON.parse(payload.text);
      } catch (error) {
        return await createChatResponse(messages, {
          requestId,
          timeoutMs,
          retries,
          fallbackDurationMs: durationMs,
        });
      }

      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: true,
        status: response.status,
        attempt,
      });
      logged = true;

      return { parsed, meta: { status: response.status, durationMs } };
    } catch (error) {
      if (error instanceof OpenAIRequestError) {
        throw error;
      }

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
          attempt,
        });
      }
      throw error;
    }
  }
}

async function createTextResponse(
  messages,
  { requestId, timeoutMs = DEFAULT_TIMEOUT_MS, retries = DEFAULT_RETRIES } = {}
) {
  if (!OPENAI_API_KEY) {
    throw new Error('Missing OPENAI_API_KEY');
  }

  const startTime = Date.now();
  let logged = false;
  let attempt = 0;

  while (attempt <= retries) {
    attempt += 1;
    try {
      const response = await fetchWithTimeout(
        'https://api.openai.com/v1/responses',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: OPENAI_MODEL,
            input: buildResponseInput(messages),
            temperature: 0,
            text: {
              format: {
                type: 'text',
              },
            },
          }),
        },
        timeoutMs
      );

      const durationMs = Date.now() - startTime;

      if (!response.ok) {
        const text = await response.text();
        const bodyPreview = buildBodyPreview(text);
        const details = extractErrorDetails(text);
        const errorMessage =
          details.errorMessage || `OpenAI error ${response.status}`;

        const canFallback =
          response.status === 404 || details.errorType === 'invalid_request_error';

        if (canFallback) {
          return await createChatTextResponse(messages, {
            requestId,
            timeoutMs,
            retries,
            fallbackDurationMs: durationMs,
          });
        }

        if (shouldRetry(response.status) && attempt <= retries) {
          await sleep(RETRY_DELAYS_MS[Math.min(attempt - 1, RETRY_DELAYS_MS.length - 1)]);
          continue;
        }

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
          attempt,
        });
        logged = true;

        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          errorType: details.errorType,
          errorCode: details.errorCode,
          bodyPreview,
          durationMs,
        });
      }

      const data = await response.json();
      const content = extractResponseText(data);
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
          attempt,
        });
        logged = true;
        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          durationMs,
        });
      }

      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: true,
        status: response.status,
        attempt,
      });
      logged = true;

      return { text: content, meta: { status: response.status, durationMs } };
    } catch (error) {
      if (error instanceof OpenAIRequestError) {
        throw error;
      }

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
          attempt,
        });
      }
      throw error;
    }
  }
}

async function createChatResponse(
  messages,
  { requestId, timeoutMs, retries, fallbackDurationMs = null } = {}
) {
  const startTime = Date.now();
  let logged = false;
  let attempt = 0;

  while (attempt <= retries) {
    attempt += 1;
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
            messages: buildChatMessages(messages),
            temperature: 0,
            response_format: { type: 'json_object' },
          }),
        },
        timeoutMs
      );

      const durationMs = Date.now() - startTime + (fallbackDurationMs || 0);

      if (!response.ok) {
        const text = await response.text();
        const bodyPreview = buildBodyPreview(text);
        const details = extractErrorDetails(text);
        const errorMessage =
          details.errorMessage || `OpenAI error ${response.status}`;

        if (shouldRetry(response.status) && attempt <= retries) {
          await sleep(RETRY_DELAYS_MS[Math.min(attempt - 1, RETRY_DELAYS_MS.length - 1)]);
          continue;
        }

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
          attempt,
        });
        logged = true;

        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          errorType: details.errorType,
          errorCode: details.errorCode,
          bodyPreview,
          durationMs,
        });
      }

      const data = await response.json();
      const content = extractChatCompletionText(data);
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
          attempt,
        });
        logged = true;
        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          durationMs,
        });
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
          attempt,
        });
        logged = true;
        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          bodyPreview,
          durationMs,
        });
      }

      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: true,
        status: response.status,
        attempt,
      });
      logged = true;

      return { parsed, meta: { status: response.status, durationMs } };
    } catch (error) {
      if (error instanceof OpenAIRequestError) {
        throw error;
      }

      if (!logged) {
        const durationMs = Date.now() - startTime + (fallbackDurationMs || 0);
        logOpenAIEvent({
          requestId,
          model: OPENAI_MODEL,
          timeout_ms: timeoutMs,
          retries,
          duration_ms: durationMs,
          ok: false,
          errorName: error.name,
          errorMessage: error.message,
          attempt,
        });
      }
      throw error;
    }
  }
}

async function createChatTextResponse(
  messages,
  { requestId, timeoutMs, retries, fallbackDurationMs = null } = {}
) {
  const startTime = Date.now();
  let logged = false;
  let attempt = 0;

  while (attempt <= retries) {
    attempt += 1;
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
            messages: buildChatMessages(messages),
            temperature: 0,
          }),
        },
        timeoutMs
      );

      const durationMs = Date.now() - startTime + (fallbackDurationMs || 0);

      if (!response.ok) {
        const text = await response.text();
        const bodyPreview = buildBodyPreview(text);
        const details = extractErrorDetails(text);
        const errorMessage =
          details.errorMessage || `OpenAI error ${response.status}`;

        if (shouldRetry(response.status) && attempt <= retries) {
          await sleep(RETRY_DELAYS_MS[Math.min(attempt - 1, RETRY_DELAYS_MS.length - 1)]);
          continue;
        }

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
          attempt,
        });
        logged = true;

        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          errorType: details.errorType,
          errorCode: details.errorCode,
          bodyPreview,
          durationMs,
        });
      }

      const data = await response.json();
      const content = extractChatCompletionText(data);
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
          attempt,
        });
        logged = true;
        throw new OpenAIRequestError(errorMessage, {
          status: response.status,
          durationMs,
        });
      }

      logOpenAIEvent({
        requestId,
        model: OPENAI_MODEL,
        timeout_ms: timeoutMs,
        retries,
        duration_ms: durationMs,
        ok: true,
        status: response.status,
        attempt,
      });
      logged = true;

      return { text: content, meta: { status: response.status, durationMs } };
    } catch (error) {
      if (error instanceof OpenAIRequestError) {
        throw error;
      }

      if (!logged) {
        const durationMs = Date.now() - startTime + (fallbackDurationMs || 0);
        logOpenAIEvent({
          requestId,
          model: OPENAI_MODEL,
          timeout_ms: timeoutMs,
          retries,
          duration_ms: durationMs,
          ok: false,
          errorName: error.name,
          errorMessage: error.message,
          attempt,
        });
      }
      throw error;
    }
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

module.exports = {
  createResponse,
  createTextResponse,
  listModels,
  OpenAIRequestError,
};
