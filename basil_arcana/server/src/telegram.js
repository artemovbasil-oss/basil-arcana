const crypto = require('crypto');

const MAX_AUTH_AGE_SECONDS = 60 * 60 * 24;

function validateTelegramInitData(initData, botToken) {
  if (!initData || typeof initData !== 'string') {
    return { ok: false, error: 'missing_init_data' };
  }
  if (!botToken) {
    return { ok: false, error: 'missing_bot_token' };
  }
  const params = new URLSearchParams(initData);
  const receivedHash = params.get('hash');
  if (!receivedHash) {
    return { ok: false, error: 'missing_hash' };
  }
  const authDateRaw = params.get('auth_date');
  params.delete('hash');
  const dataCheckString = [...params.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');
  const secretKey = crypto
    .createHmac('sha256', 'WebAppData')
    .update(botToken)
    .digest();
  const calculatedHash = crypto
    .createHmac('sha256', secretKey)
    .update(dataCheckString)
    .digest('hex');

  const receivedBuffer = Buffer.from(receivedHash, 'hex');
  const calculatedBuffer = Buffer.from(calculatedHash, 'hex');
  const isValid =
    receivedBuffer.length === calculatedBuffer.length &&
    crypto.timingSafeEqual(receivedBuffer, calculatedBuffer);

  if (!isValid) {
    return { ok: false, error: 'invalid_hash' };
  }

  const authDate = Number(authDateRaw);
  if (!Number.isFinite(authDate) || authDate <= 0) {
    return { ok: false, error: 'invalid_auth_date' };
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (nowSeconds - authDate > MAX_AUTH_AGE_SECONDS) {
    return { ok: false, error: 'expired_auth_date' };
  }
  return {
    ok: true,
    data: Object.fromEntries(params.entries()),
  };
}

module.exports = { validateTelegramInitData };
