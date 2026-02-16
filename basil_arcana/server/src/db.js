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
      photo_url TEXT,
      locale TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS photo_url TEXT;
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

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_query_history (
      id BIGSERIAL PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      query_type TEXT NOT NULL,
      question TEXT NOT NULL,
      locale TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query(
    "CREATE INDEX IF NOT EXISTS idx_query_history_user_created ON user_query_history (telegram_user_id, created_at DESC);"
  );

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_daily_activity (
      id BIGSERIAL PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      activity_date DATE NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (telegram_user_id, activity_date)
    );
  `);
  await pool.query(
    "CREATE INDEX IF NOT EXISTS idx_user_daily_activity_user_date ON user_daily_activity (telegram_user_id, activity_date DESC);"
  );

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_perks_state (
      telegram_user_id BIGINT PRIMARY KEY REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      free_five_cards_credits INTEGER NOT NULL DEFAULT 0,
      total_referral_credits_granted INTEGER NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS referral_events (
      id BIGSERIAL PRIMARY KEY,
      referrer_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      referred_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      start_param TEXT,
      bonus_credits INTEGER NOT NULL DEFAULT 20,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (referrer_user_id, referred_user_id)
    );
  `);

  await pool.query(
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_referral_events_referred_user ON referral_events (referred_user_id);"
  );

  await pool.query(
    "CREATE INDEX IF NOT EXISTS idx_referral_events_referrer_created ON referral_events (referrer_user_id, created_at DESC);"
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
    lastName: normalizeText(telegramUser?.lastName),
    photoUrl: normalizeText(telegramUser?.photoUrl)
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
    INSERT INTO users (telegram_user_id, username, first_name, last_name, photo_url, locale)
    VALUES ($1, $2, $3, $4, $5, $6)
    ON CONFLICT (telegram_user_id)
    DO UPDATE SET
      username = COALESCE(EXCLUDED.username, users.username),
      first_name = COALESCE(EXCLUDED.first_name, users.first_name),
      last_name = COALESCE(EXCLUDED.last_name, users.last_name),
      photo_url = COALESCE(EXCLUDED.photo_url, users.photo_url),
      locale = COALESCE(EXCLUDED.locale, users.locale),
      updated_at = NOW();
    `,
    [
      telegramUserId,
      user.username,
      user.firstName,
      user.lastName,
      user.photoUrl,
      normalizedLocale
    ]
  );
}

async function claimReferralBonus({
  referredUserId,
  referrerUserId,
  startParam,
  bonusCredits = 20
}) {
  if (!referredUserId || !referrerUserId) {
    return { claimed: false, reason: 'invalid_user' };
  }
  if (Number(referredUserId) === Number(referrerUserId)) {
    return { claimed: false, reason: 'self_referral' };
  }
  const safeBonus = Math.max(0, Number(bonusCredits) || 0);
  if (safeBonus <= 0) {
    return { claimed: false, reason: 'invalid_bonus' };
  }

  const client = await getDb().connect();
  try {
    await client.query('BEGIN');

    const referrerRes = await client.query(
      'SELECT telegram_user_id FROM users WHERE telegram_user_id = $1 LIMIT 1;',
      [referrerUserId]
    );
    if (!referrerRes.rows[0]) {
      await client.query('ROLLBACK');
      return { claimed: false, reason: 'referrer_not_found' };
    }

    const insertRes = await client.query(
      `
      INSERT INTO referral_events (
        referrer_user_id,
        referred_user_id,
        start_param,
        bonus_credits,
        created_at
      )
      VALUES ($1, $2, $3, $4, NOW())
      ON CONFLICT (referred_user_id) DO NOTHING
      RETURNING id;
      `,
      [referrerUserId, referredUserId, normalizeText(startParam), safeBonus]
    );
    const inserted = Boolean(insertRes.rows[0]?.id);
    if (!inserted) {
      await client.query('ROLLBACK');
      return { claimed: false, reason: 'already_claimed' };
    }

    await client.query(
      `
      INSERT INTO user_perks_state (
        telegram_user_id,
        free_five_cards_credits,
        total_referral_credits_granted,
        updated_at
      )
      VALUES ($1, $2, $2, NOW())
      ON CONFLICT (telegram_user_id)
      DO UPDATE SET
        free_five_cards_credits = user_perks_state.free_five_cards_credits + EXCLUDED.free_five_cards_credits,
        total_referral_credits_granted = user_perks_state.total_referral_credits_granted + EXCLUDED.total_referral_credits_granted,
        updated_at = NOW();
      `,
      [referrerUserId, safeBonus]
    );

    await client.query(
      `
      INSERT INTO energy_ledger (
        telegram_user_id,
        delta_energy,
        operation,
        payload,
        metadata
      )
      VALUES ($1, 0, 'grant_referral_five_cards_credits', NULL, $2::jsonb);
      `,
      [
        referrerUserId,
        JSON.stringify({
          referredUserId: Number(referredUserId),
          bonusCredits: safeBonus,
          startParam: normalizeText(startParam)
        })
      ]
    );

    const stateRes = await client.query(
      `
      SELECT free_five_cards_credits
      FROM user_perks_state
      WHERE telegram_user_id = $1;
      `,
      [referrerUserId]
    );
    await client.query('COMMIT');
    return {
      claimed: true,
      referrerUserId: Number(referrerUserId),
      freeFiveCardsCredits: Number(stateRes.rows[0]?.free_five_cards_credits || 0),
      bonusCredits: safeBonus
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function consumeFreeFiveCardsCredit({ telegramUserId, reason = null }) {
  if (!telegramUserId) {
    return {
      ok: false,
      consumed: false,
      remaining: 0,
      reason: 'invalid_user'
    };
  }
  const client = await getDb().connect();
  try {
    await client.query('BEGIN');
    const decRes = await client.query(
      `
      UPDATE user_perks_state
      SET
        free_five_cards_credits = free_five_cards_credits - 1,
        updated_at = NOW()
      WHERE telegram_user_id = $1
        AND free_five_cards_credits > 0
      RETURNING free_five_cards_credits;
      `,
      [telegramUserId]
    );
    if (!decRes.rows[0]) {
      const balanceRes = await client.query(
        `
        SELECT free_five_cards_credits
        FROM user_perks_state
        WHERE telegram_user_id = $1;
        `,
        [telegramUserId]
      );
      const remaining = Number(balanceRes.rows[0]?.free_five_cards_credits || 0);
      await client.query('COMMIT');
      return { ok: true, consumed: false, remaining };
    }
    const remaining = Number(decRes.rows[0].free_five_cards_credits || 0);
    await client.query(
      `
      INSERT INTO energy_ledger (
        telegram_user_id,
        delta_energy,
        operation,
        payload,
        metadata
      )
      VALUES ($1, 0, 'consume_referral_five_cards_credit', NULL, $2::jsonb);
      `,
      [
        telegramUserId,
        JSON.stringify({
          reason: normalizeText(reason) || 'five_cards_access',
          remaining
        })
      ]
    );
    await client.query('COMMIT');
    return { ok: true, consumed: true, remaining };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function getUserDashboard({ telegramUserId }) {
  const client = await getDb().connect();
  try {
    const profileRes = await client.query(
      `
      SELECT telegram_user_id, username, first_name, last_name, photo_url, locale
      FROM users
      WHERE telegram_user_id = $1
      LIMIT 1;
      `,
      [telegramUserId]
    );
    const perksRes = await client.query(
      `
      SELECT
        free_five_cards_credits,
        total_referral_credits_granted
      FROM user_perks_state
      WHERE telegram_user_id = $1
      LIMIT 1;
      `,
      [telegramUserId]
    );
    const referralRes = await client.query(
      `
      SELECT COUNT(*)::int AS total
      FROM referral_events
      WHERE referrer_user_id = $1;
      `,
      [telegramUserId]
    );
    const energyRes = await client.query(
      `
      SELECT total_energy_granted, unlimited_until
      FROM user_energy_state
      WHERE telegram_user_id = $1
      LIMIT 1;
      `,
      [telegramUserId]
    );

    const profile = profileRes.rows[0] || {};
    const perks = perksRes.rows[0] || {};
    const energy = energyRes.rows[0] || {};

    const services = [];
    if (energy.unlimited_until && new Date(energy.unlimited_until).getTime() > Date.now()) {
      services.push({
        id: 'unlimited',
        type: 'unlimited',
        status: 'active',
        expiresAt: new Date(energy.unlimited_until).toISOString()
      });
    }

    return {
      profile: {
        telegramUserId: Number(profile.telegram_user_id || telegramUserId),
        username: profile.username ? String(profile.username) : '',
        firstName: profile.first_name ? String(profile.first_name) : '',
        lastName: profile.last_name ? String(profile.last_name) : '',
        photoUrl: profile.photo_url ? String(profile.photo_url) : '',
        locale: profile.locale ? String(profile.locale) : ''
      },
      perks: {
        freeFiveCardsCredits: Number(perks.free_five_cards_credits || 0),
        totalReferralCreditsGranted: Number(perks.total_referral_credits_granted || 0)
      },
      referrals: {
        totalInvited: Number(referralRes.rows[0]?.total || 0)
      },
      services
    };
  } finally {
    client.release();
  }
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
      const energyAmount = Math.max(0, Number(row.energy_amount || 0));
      const isUnlimitedGrant =
        grantType === 'unlimited_week' ||
        grantType === 'unlimited_month' ||
        grantType === 'unlimited_year';
      const updatesEnergyState = grantType === 'energy' || isUnlimitedGrant;

      if (updatesEnergyState) {
        await client.query(
          `
          INSERT INTO user_energy_state (telegram_user_id, total_energy_granted, unlimited_until, updated_at)
          VALUES ($1, $2, NULL, NOW())
          ON CONFLICT (telegram_user_id)
          DO UPDATE SET
            total_energy_granted = user_energy_state.total_energy_granted + EXCLUDED.total_energy_granted,
            updated_at = NOW();
          `,
          [telegramUserId, energyAmount]
        );
      }

      if (isUnlimitedGrant && updatesEnergyState) {
        const intervalDays =
          grantType === 'unlimited_week'
            ? 7
            : grantType === 'unlimited_month'
            ? 30
            : 365;
        await client.query(
          `
          UPDATE user_energy_state
          SET
            unlimited_until = (
              GREATEST(COALESCE(unlimited_until, NOW()), NOW()) + ($2 || ' days')::interval
            ),
            updated_at = NOW()
          WHERE telegram_user_id = $1;
          `,
          [telegramUserId, String(intervalDays)]
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
          updatesEnergyState ? energyAmount : 0,
          grantType === 'unlimited_week'
            ? 'grant_unlimited_week'
            : grantType === 'unlimited_month'
            ? 'grant_unlimited_month'
            : grantType === 'unlimited_year'
            ? 'grant_unlimited_year'
            : grantType === 'five_cards_single'
            ? 'grant_five_cards_single'
            : 'grant_energy_topup',
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

async function logUserQuery({
  telegramUserId,
  queryType,
  question,
  locale = null
}) {
  if (!telegramUserId || !queryType) {
    return;
  }
  const normalizedQuestion =
    typeof question === 'string' && question.trim() ? question.trim() : '';
  if (!normalizedQuestion) {
    return;
  }
  await getDb().query(
    `
    INSERT INTO user_query_history (telegram_user_id, query_type, question, locale)
    VALUES ($1, $2, $3, $4);
    `,
    [telegramUserId, queryType, normalizedQuestion.slice(0, 1000), normalizeText(locale)]
  );
}

async function listRecentUserQueries({ telegramUserId, limit = 20 }) {
  const safeLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const { rows } = await getDb().query(
    `
    SELECT query_type, question, locale, created_at
    FROM user_query_history
    WHERE telegram_user_id = $1
    ORDER BY created_at DESC
    LIMIT $2;
    `,
    [telegramUserId, safeLimit]
  );
  return rows.map((row) => ({
    queryType: String(row.query_type || ''),
    question: String(row.question || ''),
    locale: row.locale ? String(row.locale) : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null
  }));
}

async function clearUserQueryHistory({ telegramUserId }) {
  if (!telegramUserId) {
    return { deletedCount: 0 };
  }
  const result = await getDb().query(
    `
    DELETE FROM user_query_history
    WHERE telegram_user_id = $1;
    `,
    [telegramUserId]
  );
  return {
    deletedCount: Number(result.rowCount || 0)
  };
}

async function recordUserDailyActivity({ telegramUserId, occurredAt = new Date() }) {
  if (!telegramUserId) {
    return;
  }
  const date = new Date(occurredAt);
  if (!Number.isFinite(date.getTime())) {
    return;
  }
  const utcDate = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
  );
  const isoDate = utcDate.toISOString().slice(0, 10);
  await getDb().query(
    `
    INSERT INTO user_daily_activity (telegram_user_id, activity_date)
    VALUES ($1, $2::date)
    ON CONFLICT (telegram_user_id, activity_date) DO NOTHING;
    `,
    [telegramUserId, isoDate]
  );
}

async function getUserVisitStreak({ telegramUserId }) {
  if (!telegramUserId) {
    return {
      currentStreakDays: 0,
      longestStreakDays: 0,
      activeDays: 0,
      awarenessPercent: 30,
      awarenessLocked: false,
      lastActiveAt: null
    };
  }

  const [dailyRowsRes, awarenessRes, premiumRes] = await Promise.all([
    getDb().query(
      `
      WITH all_days AS (
        SELECT activity_date AS day, created_at
        FROM user_daily_activity
        WHERE telegram_user_id = $1
        UNION ALL
        SELECT (created_at AT TIME ZONE 'UTC')::date AS day, created_at
        FROM user_query_history
        WHERE telegram_user_id = $1
          AND query_type LIKE 'reading_%'
      )
      SELECT day::text AS activity_date, MAX(created_at) AS last_created_at
      FROM all_days
      GROUP BY day
      ORDER BY day DESC;
      `,
      [telegramUserId]
    ),
    getDb().query(
      `
      SELECT
        COALESCE(SUM(
          CASE
            WHEN query_type = 'natal_chart' THEN 4
            WHEN query_type = 'compatibility' THEN 4
            WHEN query_type = 'reading_daily_card' THEN 2
            WHEN query_type LIKE 'reading_%' THEN 3
            ELSE 0
          END
        ), 0)::int AS awareness_points,
        MAX(created_at) AS last_action_at
      FROM user_query_history
      WHERE telegram_user_id = $1;
      `,
      [telegramUserId]
    ),
    getDb().query(
      `
      SELECT
        EXISTS (
          SELECT 1
          FROM user_energy_state ues
          WHERE ues.telegram_user_id = $1
            AND ues.unlimited_until IS NOT NULL
            AND ues.unlimited_until > NOW()
        ) AS has_active_unlimited,
        EXISTS (
          SELECT 1
          FROM energy_payment_invoices epi
          WHERE epi.telegram_user_id = $1
            AND epi.grant_type = 'unlimited_year'
            AND epi.status = 'paid'
            AND epi.grant_applied_at IS NOT NULL
            AND epi.grant_applied_at > NOW() - INTERVAL '400 days'
        ) AS has_year_purchase;
      `,
      [telegramUserId]
    )
  ]);

  const rows = dailyRowsRes.rows || [];
  const awarenessRow = awarenessRes.rows[0] || {};
  const premiumRow = premiumRes.rows[0] || {};
  const awarenessPoints = Number(awarenessRow.awareness_points || 0);
  const lastActionAt = awarenessRow.last_action_at
    ? new Date(awarenessRow.last_action_at)
    : null;
  const premiumLocked = Boolean(
    premiumRow.has_active_unlimited && premiumRow.has_year_purchase
  );

  let awarenessPercent = 30;
  if (premiumLocked) {
    awarenessPercent = 100;
  } else {
    const base = 30 + awarenessPoints;
    let decayDays = 0;
    if (lastActionAt && Number.isFinite(lastActionAt.getTime())) {
      const now = new Date();
      const todayUtc = new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
      );
      const actionUtc = new Date(
        Date.UTC(
          lastActionAt.getUTCFullYear(),
          lastActionAt.getUTCMonth(),
          lastActionAt.getUTCDate()
        )
      );
      decayDays = Math.max(
        0,
        Math.floor((todayUtc.getTime() - actionUtc.getTime()) / (24 * 60 * 60 * 1000))
      );
    }
    awarenessPercent = Math.max(30, Math.min(100, base - decayDays * 10));
  }

  if (rows.length === 0) {
    return {
      currentStreakDays: 1,
      longestStreakDays: 1,
      activeDays: 1,
      awarenessPercent,
      awarenessLocked: premiumLocked,
      lastActiveAt: new Date().toISOString()
    };
  }

  const dayValues = rows
    .map((row) => {
      const raw = row.activity_date;
      if (!raw) {
        return null;
      }
      const isoDate = String(raw).slice(0, 10);
      const date = new Date(`${isoDate}T00:00:00.000Z`);
      return Number.isFinite(date.getTime()) ? date : null;
    })
    .filter(Boolean);

  const activeDays = dayValues.length;
  const today = new Date();
  const todayUtc = new Date(
    Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate())
  );
  const latestDay = dayValues[0];
  const dayMs = 24 * 60 * 60 * 1000;
  const diffFromToday = Math.floor((todayUtc - latestDay) / dayMs);

  let currentStreakDays = 0;
  if (diffFromToday === 0) {
    currentStreakDays = 1;
    for (let i = 1; i < dayValues.length; i += 1) {
      const expected = dayValues[i - 1].getTime() - dayMs;
      if (dayValues[i].getTime() !== expected) {
        break;
      }
      currentStreakDays += 1;
    }
  }

  let longestStreakDays = 1;
  let running = 1;
  for (let i = 1; i < dayValues.length; i += 1) {
    const expected = dayValues[i - 1].getTime() - dayMs;
    if (dayValues[i].getTime() === expected) {
      running += 1;
      if (running > longestStreakDays) {
        longestStreakDays = running;
      }
      continue;
    }
    running = 1;
  }

  const lastActiveAtRaw = rows[0]?.last_created_at;
  const lastActiveAt = lastActiveAtRaw
    ? new Date(lastActiveAtRaw).toISOString()
    : null;

  return {
    currentStreakDays: Math.max(1, currentStreakDays),
    longestStreakDays,
    activeDays,
    awarenessPercent,
    awarenessLocked: premiumLocked,
    lastActiveAt
  };
}

module.exports = {
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
  clearUserQueryHistory,
  recordUserDailyActivity,
  getUserVisitStreak
};
