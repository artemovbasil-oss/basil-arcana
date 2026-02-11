const { Pool } = require('pg');

let pool = null;

function initDb(databaseUrl) {
  if (!databaseUrl || !databaseUrl.trim()) {
    return null;
  }
  if (pool) {
    return pool;
  }
  pool = new Pool({
    connectionString: databaseUrl,
    ssl:
      databaseUrl.includes('localhost') || databaseUrl.includes('127.0.0.1')
        ? false
        : { rejectUnauthorized: false }
  });
  return pool;
}

function hasDb() {
  return Boolean(pool);
}

function getDb() {
  if (!pool) {
    throw new Error('Database is not initialized');
  }
  return pool;
}

async function ensureSchema() {
  if (!pool) {
    return;
  }
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      telegram_user_id BIGINT PRIMARY KEY,
      username TEXT,
      first_name TEXT,
      last_name TEXT,
      locale TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS sofia_consent_state (
      telegram_user_id BIGINT PRIMARY KEY REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      decision TEXT NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CHECK (decision IN ('accepted','rejected','revoked'))
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS sofia_consent_events (
      id BIGSERIAL PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      decision TEXT NOT NULL,
      previous_decision TEXT,
      source TEXT NOT NULL DEFAULT 'api',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CHECK (decision IN ('accepted','rejected','revoked')),
      CHECK (previous_decision IS NULL OR previous_decision IN ('accepted','rejected','revoked'))
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS energy_payment_invoices (
      payload TEXT PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      pack_id TEXT NOT NULL,
      grant_type TEXT NOT NULL,
      energy_amount INTEGER NOT NULL DEFAULT 0,
      stars_amount INTEGER NOT NULL,
      invoice_link TEXT,
      status TEXT NOT NULL DEFAULT 'created',
      grant_applied_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_energy_state (
      telegram_user_id BIGINT PRIMARY KEY REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      total_energy_granted INTEGER NOT NULL DEFAULT 0,
      unlimited_until TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS energy_ledger (
      id BIGSERIAL PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      delta_energy INTEGER NOT NULL DEFAULT 0,
      operation TEXT NOT NULL,
      payload TEXT,
      metadata JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(
    "CREATE INDEX IF NOT EXISTS idx_energy_ledger_user_created ON energy_ledger (telegram_user_id, created_at DESC);"
  );
}

function normalizeText(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function mapTelegramUser(telegramUser) {
  return {
    username: normalizeText(telegramUser?.username),
    firstName: normalizeText(telegramUser?.firstName),
    lastName: normalizeText(telegramUser?.lastName)
  };
}

async function upsertUserProfile({ telegramUserId, telegramUser, locale = null }) {
  if (!pool || !telegramUserId) {
    return;
  }
  const user = mapTelegramUser(telegramUser);
  const normalizedLocale = normalizeText(locale);
  await pool.query(
    `
    INSERT INTO users (telegram_user_id, username, first_name, last_name, locale)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (telegram_user_id)
    DO UPDATE SET
      username = COALESCE(EXCLUDED.username, users.username),
      first_name = COALESCE(EXCLUDED.first_name, users.first_name),
      last_name = COALESCE(EXCLUDED.last_name, users.last_name),
      locale = COALESCE(EXCLUDED.locale, users.locale),
      updated_at = NOW();
    `,
    [telegramUserId, user.username, user.firstName, user.lastName, normalizedLocale]
  );
}

async function recordSofiaConsent({ telegramUserId, decision }) {
  const client = await getDb().connect();
  try {
    await client.query('BEGIN');

    const stateRes = await client.query(
      'SELECT decision FROM sofia_consent_state WHERE telegram_user_id = $1 FOR UPDATE;',
      [telegramUserId]
    );
    const previousDecision = stateRes.rows[0]?.decision || '';

    if (previousDecision === decision) {
      const totalRes = await client.query('SELECT COUNT(*)::int AS count FROM sofia_consent_state;');
      await client.query('COMMIT');
      return {
        duplicate: true,
        previousDecision,
        totalUsers: Number(totalRes.rows[0]?.count || 0)
      };
    }

    await client.query(
      `
      INSERT INTO sofia_consent_state (telegram_user_id, decision, updated_at)
      VALUES ($1, $2, NOW())
      ON CONFLICT (telegram_user_id)
      DO UPDATE SET decision = EXCLUDED.decision, updated_at = NOW();
      `,
      [telegramUserId, decision]
    );

    await client.query(
      `
      INSERT INTO sofia_consent_events (telegram_user_id, decision, previous_decision, source)
      VALUES ($1, $2, $3, 'api');
      `,
      [telegramUserId, decision, previousDecision || null]
    );

    const totalRes = await client.query('SELECT COUNT(*)::int AS count FROM sofia_consent_state;');
    await client.query('COMMIT');
    return {
      duplicate: false,
      previousDecision,
      totalUsers: Number(totalRes.rows[0]?.count || 0)
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function saveCreatedInvoice({
  telegramUserId,
  packId,
  grantType,
  energyAmount,
  starsAmount,
  payload,
  invoiceLink
}) {
  await getDb().query(
    `
    INSERT INTO energy_payment_invoices (
      payload,
      telegram_user_id,
      pack_id,
      grant_type,
      energy_amount,
      stars_amount,
      invoice_link,
      status,
      updated_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, 'created', NOW())
    ON CONFLICT (payload)
    DO UPDATE SET
      invoice_link = EXCLUDED.invoice_link,
      stars_amount = EXCLUDED.stars_amount,
      energy_amount = EXCLUDED.energy_amount,
      updated_at = NOW();
    `,
    [payload, telegramUserId, packId, grantType, energyAmount, starsAmount, invoiceLink]
  );
}

async function confirmInvoiceStatus({ telegramUserId, payload, status }) {
  const client = await getDb().connect();
  try {
    await client.query('BEGIN');

    const existingRes = await client.query(
      `
      SELECT
        payload,
        telegram_user_id,
        pack_id,
        grant_type,
        energy_amount,
        stars_amount,
        status,
        grant_applied_at
      FROM energy_payment_invoices
      WHERE payload = $1
      FOR UPDATE;
      `,
      [payload]
    );

    const row = existingRes.rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return { ok: false, reason: 'invoice_not_found' };
    }
    if (Number(row.telegram_user_id) !== Number(telegramUserId)) {
      await client.query('ROLLBACK');
      return { ok: false, reason: 'invoice_user_mismatch' };
    }

    const alreadyApplied = Boolean(row.grant_applied_at);

    if (status !== row.status) {
      await client.query(
        'UPDATE energy_payment_invoices SET status = $2, updated_at = NOW() WHERE payload = $1;',
        [payload, status]
      );
    }

    let grantApplied = false;
    if (status === 'paid' && !alreadyApplied) {
      const grantType = String(row.grant_type || 'energy');
      const energyAmount = Number(row.energy_amount || 0);

      await client.query(
        `
        INSERT INTO user_energy_state (telegram_user_id, total_energy_granted, unlimited_until, updated_at)
        VALUES ($1, $2, NULL, NOW())
        ON CONFLICT (telegram_user_id)
        DO UPDATE SET
          total_energy_granted = user_energy_state.total_energy_granted + EXCLUDED.total_energy_granted,
          updated_at = NOW();
        `,
        [telegramUserId, Math.max(0, energyAmount)]
      );

      if (grantType === 'unlimited_year') {
        await client.query(
          `
          UPDATE user_energy_state
          SET
            unlimited_until = (
              GREATEST(COALESCE(unlimited_until, NOW()), NOW()) + INTERVAL '365 days'
            ),
            updated_at = NOW()
          WHERE telegram_user_id = $1;
          `,
          [telegramUserId]
        );
      }

      await client.query(
        `
        INSERT INTO energy_ledger (
          telegram_user_id,
          delta_energy,
          operation,
          payload,
          metadata
        ) VALUES ($1, $2, $3, $4, $5::jsonb);
        `,
        [
          telegramUserId,
          Math.max(0, energyAmount),
          grantType === 'unlimited_year' ? 'grant_unlimited_year' : 'grant_energy_topup',
          payload,
          JSON.stringify({
            grantType,
            packId: row.pack_id,
            starsAmount: Number(row.stars_amount || 0)
          })
        ]
      );

      await client.query(
        `
        UPDATE energy_payment_invoices
        SET grant_applied_at = NOW(), updated_at = NOW()
        WHERE payload = $1;
        `,
        [payload]
      );
      grantApplied = true;
    }

    const stateRes = await client.query(
      `
      SELECT total_energy_granted, unlimited_until
      FROM user_energy_state
      WHERE telegram_user_id = $1;
      `,
      [telegramUserId]
    );
    const state = stateRes.rows[0] || null;

    await client.query('COMMIT');
    return {
      ok: true,
      grantApplied,
      packId: row.pack_id,
      grantType: row.grant_type,
      energyAmount: Number(row.energy_amount || 0),
      starsAmount: Number(row.stars_amount || 0),
      totalEnergyGranted: Number(state?.total_energy_granted || 0),
      unlimitedUntil: state?.unlimited_until ? new Date(state.unlimited_until).toISOString() : null
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  initDb,
  hasDb,
  ensureSchema,
  upsertUserProfile,
  recordSofiaConsent,
  saveCreatedInvoice,
  confirmInvoiceStatus
};
