import { Pool, type PoolClient } from "pg";

export type DbLocale = "ru" | "en" | "kk";
export type DbPlanId = "single" | "week" | "month" | "year";

export interface UserSubscriptionRecord {
  telegramUserId: number;
  subscriptionEndsAt: number | null;
  unspentSingleReadings: number;
  purchasedSingle: number;
  purchasedWeek: number;
  purchasedMonth: number;
  purchasedYear: number;
}

export interface ActiveSubscriptionRow {
  telegramUserId: number;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
  locale: DbLocale | null;
  subscriptionEndsAt: number | null;
  unspentSingleReadings: number;
  purchasedSingle: number;
  purchasedWeek: number;
  purchasedMonth: number;
  purchasedYear: number;
}

let pool: Pool | null = null;

function requirePool(): Pool {
  if (!pool) {
    throw new Error("DB pool is not initialized");
  }
  return pool;
}

function toMillis(value: Date | null): number | null {
  if (!value) {
    return null;
  }
  return value.getTime();
}

function mapSubscriptionRow(row: Record<string, unknown>): UserSubscriptionRecord {
  return {
    telegramUserId: Number(row.telegram_user_id),
    subscriptionEndsAt: toMillis((row.subscription_ends_at as Date | null) ?? null),
    unspentSingleReadings: Number(row.unspent_single_readings ?? 0),
    purchasedSingle: Number(row.purchased_single ?? 0),
    purchasedWeek: Number(row.purchased_week ?? 0),
    purchasedMonth: Number(row.purchased_month ?? 0),
    purchasedYear: Number(row.purchased_year ?? 0),
  };
}

export function initDb(databaseUrl: string): void {
  if (pool) {
    return;
  }
  pool = new Pool({
    connectionString: databaseUrl,
    ssl:
      databaseUrl.includes("localhost") || databaseUrl.includes("127.0.0.1")
        ? false
        : { rejectUnauthorized: false },
  });
}

export async function ensureSchema(): Promise<void> {
  const db = requirePool();
  await db.query(`
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

  await db.query(`
    CREATE TABLE IF NOT EXISTS subscriptions (
      telegram_user_id BIGINT PRIMARY KEY REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      subscription_ends_at TIMESTAMPTZ,
      unspent_single_readings INTEGER NOT NULL DEFAULT 0,
      purchased_single INTEGER NOT NULL DEFAULT 0,
      purchased_week INTEGER NOT NULL DEFAULT 0,
      purchased_month INTEGER NOT NULL DEFAULT 0,
      purchased_year INTEGER NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS payments (
      telegram_payment_charge_id TEXT PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      plan_id TEXT NOT NULL,
      currency TEXT NOT NULL,
      total_amount INTEGER NOT NULL,
      purchase_code TEXT NOT NULL UNIQUE,
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await db.query(
    "CREATE INDEX IF NOT EXISTS subscriptions_active_idx ON subscriptions (subscription_ends_at, unspent_single_readings);",
  );
}

export async function upsertUserProfile(
  telegramUserId: number,
  username: string | null,
  firstName: string | null,
  lastName: string | null,
  locale: DbLocale | null,
): Promise<void> {
  const db = requirePool();
  await db.query(
    `
    INSERT INTO users (telegram_user_id, username, first_name, last_name, locale)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (telegram_user_id)
    DO UPDATE SET
      username = EXCLUDED.username,
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name,
      locale = COALESCE(EXCLUDED.locale, users.locale),
      updated_at = NOW();
    `,
    [telegramUserId, username, firstName, lastName, locale],
  );
}

export async function getUserLocale(telegramUserId: number): Promise<DbLocale | null> {
  const db = requirePool();
  const { rows } = await db.query(
    "SELECT locale FROM users WHERE telegram_user_id = $1 LIMIT 1;",
    [telegramUserId],
  );
  if (rows.length === 0) {
    return null;
  }
  const value = (rows[0]?.locale as string | null) ?? null;
  if (value === "ru" || value === "en" || value === "kk") {
    return value;
  }
  return null;
}

export async function getUserSubscription(
  telegramUserId: number,
): Promise<UserSubscriptionRecord | null> {
  const db = requirePool();
  const { rows } = await db.query(
    `
    SELECT
      telegram_user_id,
      subscription_ends_at,
      unspent_single_readings,
      purchased_single,
      purchased_week,
      purchased_month,
      purchased_year
    FROM subscriptions
    WHERE telegram_user_id = $1;
    `,
    [telegramUserId],
  );
  if (rows.length === 0) {
    return null;
  }
  return mapSubscriptionRow(rows[0] as Record<string, unknown>);
}

export async function saveUserSubscription(record: UserSubscriptionRecord): Promise<void> {
  const db = requirePool();
  await db.query(
    `
    INSERT INTO subscriptions (
      telegram_user_id,
      subscription_ends_at,
      unspent_single_readings,
      purchased_single,
      purchased_week,
      purchased_month,
      purchased_year,
      updated_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
    ON CONFLICT (telegram_user_id)
    DO UPDATE SET
      subscription_ends_at = EXCLUDED.subscription_ends_at,
      unspent_single_readings = EXCLUDED.unspent_single_readings,
      purchased_single = EXCLUDED.purchased_single,
      purchased_week = EXCLUDED.purchased_week,
      purchased_month = EXCLUDED.purchased_month,
      purchased_year = EXCLUDED.purchased_year,
      updated_at = NOW();
    `,
    [
      record.telegramUserId,
      record.subscriptionEndsAt ? new Date(record.subscriptionEndsAt) : null,
      record.unspentSingleReadings,
      record.purchasedSingle,
      record.purchasedWeek,
      record.purchasedMonth,
      record.purchasedYear,
    ],
  );
}

export async function paymentExists(telegramPaymentChargeId: string): Promise<boolean> {
  const db = requirePool();
  const { rows } = await db.query(
    "SELECT 1 FROM payments WHERE telegram_payment_charge_id = $1 LIMIT 1;",
    [telegramPaymentChargeId],
  );
  return rows.length > 0;
}

export async function insertPayment(
  telegramPaymentChargeId: string,
  telegramUserId: number,
  planId: DbPlanId,
  currency: string,
  totalAmount: number,
  purchaseCode: string,
  expiresAtMillis: number | null,
): Promise<void> {
  const db = requirePool();
  await db.query(
    `
    INSERT INTO payments (
      telegram_payment_charge_id,
      telegram_user_id,
      plan_id,
      currency,
      total_amount,
      purchase_code,
      expires_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7);
    `,
    [
      telegramPaymentChargeId,
      telegramUserId,
      planId,
      currency,
      totalAmount,
      purchaseCode,
      expiresAtMillis ? new Date(expiresAtMillis) : null,
    ],
  );
}

export async function listActiveSubscriptions(): Promise<ActiveSubscriptionRow[]> {
  const db = requirePool();
  const { rows } = await db.query(
    `
    SELECT
      u.telegram_user_id,
      u.username,
      u.first_name,
      u.last_name,
      u.locale,
      s.subscription_ends_at,
      s.unspent_single_readings,
      s.purchased_single,
      s.purchased_week,
      s.purchased_month,
      s.purchased_year
    FROM subscriptions s
    JOIN users u ON u.telegram_user_id = s.telegram_user_id
    WHERE s.subscription_ends_at > NOW() OR s.unspent_single_readings > 0
    ORDER BY s.subscription_ends_at DESC NULLS LAST, u.telegram_user_id ASC;
    `,
  );

  return rows.map((row) => ({
    telegramUserId: Number(row.telegram_user_id),
    username: (row.username as string | null) ?? null,
    firstName: (row.first_name as string | null) ?? null,
    lastName: (row.last_name as string | null) ?? null,
    locale: (row.locale as DbLocale | null) ?? null,
    subscriptionEndsAt: toMillis((row.subscription_ends_at as Date | null) ?? null),
    unspentSingleReadings: Number(row.unspent_single_readings ?? 0),
    purchasedSingle: Number(row.purchased_single ?? 0),
    purchasedWeek: Number(row.purchased_week ?? 0),
    purchasedMonth: Number(row.purchased_month ?? 0),
    purchasedYear: Number(row.purchased_year ?? 0),
  }));
}

export async function completeConsultation(
  telegramUserId: number,
): Promise<"single" | "timed" | "none"> {
  const db = requirePool();
  const client = await db.connect();
  try {
    await client.query("BEGIN");

    const sub = await getSubscriptionForUpdate(client, telegramUserId);
    if (!sub) {
      await client.query("COMMIT");
      return "none";
    }

    if (sub.unspentSingleReadings > 0) {
      const nextSingle = sub.unspentSingleReadings - 1;
      const nextEnds = sub.subscriptionEndsAt
        ? Math.max(0, sub.subscriptionEndsAt - 24 * 60 * 60 * 1000)
        : null;
      await client.query(
        `
        UPDATE subscriptions
        SET
          unspent_single_readings = $2,
          subscription_ends_at = $3,
          updated_at = NOW()
        WHERE telegram_user_id = $1;
        `,
        [telegramUserId, nextSingle, nextEnds ? new Date(nextEnds) : null],
      );
      await client.query("COMMIT");
      return "single";
    }

    const now = Date.now();
    if ((sub.subscriptionEndsAt ?? 0) > now) {
      await client.query(
        `
        UPDATE subscriptions
        SET
          subscription_ends_at = NOW(),
          updated_at = NOW()
        WHERE telegram_user_id = $1;
        `,
        [telegramUserId],
      );
      await client.query("COMMIT");
      return "timed";
    }

    await client.query("COMMIT");
    return "none";
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function getSubscriptionForUpdate(
  client: PoolClient,
  telegramUserId: number,
): Promise<UserSubscriptionRecord | null> {
  const { rows } = await client.query(
    `
    SELECT
      telegram_user_id,
      subscription_ends_at,
      unspent_single_readings,
      purchased_single,
      purchased_week,
      purchased_month,
      purchased_year
    FROM subscriptions
    WHERE telegram_user_id = $1
    FOR UPDATE;
    `,
    [telegramUserId],
  );
  if (rows.length === 0) {
    return null;
  }
  return mapSubscriptionRow(rows[0] as Record<string, unknown>);
}
