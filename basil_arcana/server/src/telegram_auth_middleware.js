const { v4: uuidv4 } = require('uuid');

const { TELEGRAM_BOT_TOKEN } = require('./config');
const { validateTelegramInitData } = require('./telegram');

function extractInitData(req) {
  const headerValue = req.get('x-telegram-initdata');
  if (typeof headerValue === 'string' && headerValue.trim()) {
    return headerValue.trim();
  }
  const bodyInitData =
    typeof req.body?.initData === 'string' ? req.body.initData.trim() : '';
  if (bodyInitData) {
    return bodyInitData;
  }
  const bodyInitDataRaw =
    typeof req.body?.initDataRaw === 'string'
      ? req.body.initDataRaw.trim()
      : '';
  if (bodyInitDataRaw) {
    return bodyInitDataRaw;
  }
  return '';
}

function telegramAuthMiddleware(req, res, next) {
  const requestId = req.requestId || uuidv4();
  if (!req.requestId) {
    req.requestId = requestId;
    res.setHeader('x-request-id', requestId);
  }

  const initData = extractInitData(req);
  if (!initData) {
    console.warn(
      JSON.stringify({
        event: 'telegram_auth_failed',
        requestId,
        reason: 'missing_initData',
        initData_length: 0
      })
    );
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'missing_initData',
      requestId
    });
  }

  if (!TELEGRAM_BOT_TOKEN) {
    console.warn('TELEGRAM_BOT_TOKEN missing/empty');
  }

  const validation = validateTelegramInitData(initData, TELEGRAM_BOT_TOKEN);
  if (!validation.ok) {
    console.warn(
      JSON.stringify({
        event: 'telegram_auth_failed',
        requestId,
        reason: 'invalid_initData',
        initData_length: initData.length
      })
    );
    return res.status(401).json({
      error: 'unauthorized',
      reason: 'invalid_initData',
      requestId
    });
  }

  let userId = null;
  if (validation.data?.user) {
    try {
      const parsedUser = JSON.parse(validation.data.user);
      if (parsedUser && parsedUser.id != null) {
        userId = parsedUser.id;
      }
    } catch (_) {}
  }

  req.telegram = {
    ok: true,
    initDataLength: initData.length,
    userId
  };

  console.log(
    JSON.stringify({
      event: 'telegram_auth_ok',
      requestId,
      initData_length: initData.length,
      userId
    })
  );

  return next();
}

module.exports = { telegramAuthMiddleware };
