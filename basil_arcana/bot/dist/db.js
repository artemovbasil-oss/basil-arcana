"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.initDb = initDb;
exports.ensureSchema = ensureSchema;
exports.upsertUserProfile = upsertUserProfile;
exports.getUserLocale = getUserLocale;
exports.getUserSubscription = getUserSubscription;
exports.saveUserSubscription = saveUserSubscription;
exports.paymentExists = paymentExists;
exports.insertPayment = insertPayment;
exports.listActiveSubscriptions = listActiveSubscriptions;
exports.completeConsultation = completeConsultation;
exports.listRecentUserQueriesForUser = listRecentUserQueriesForUser;
exports.listRecentOracleQueries = listRecentOracleQueries;
exports.listUsersForBroadcast = listUsersForBroadcast;
exports.listUsersForSofia = listUsersForSofia;
exports.listUsersCreatedTodayForSofia = listUsersCreatedTodayForSofia;
exports.insertFunnelEvent = insertFunnelEvent;
exports.createSofiaAgentTask = createSofiaAgentTask;
exports.claimNextSofiaAgentTask = claimNextSofiaAgentTask;
exports.saveSofiaAgentDraft = saveSofiaAgentDraft;
exports.markSofiaAgentTaskFailed = markSofiaAgentTaskFailed;
exports.listSofiaAgentDrafts = listSofiaAgentDrafts;
exports.markSofiaAgentTaskApproved = markSofiaAgentTaskApproved;
exports.markSofiaAgentTaskSent = markSofiaAgentTaskSent;
exports.getLatestDraftForTask = getLatestDraftForTask;
exports.listSofiaAgentTasksByStatus = listSofiaAgentTasksByStatus;
exports.findSofiaTaskByDedupKey = findSofiaTaskByDedupKey;
exports.upsertSofiaAgentThread = upsertSofiaAgentThread;
exports.createSofiaAgentMessage = createSofiaAgentMessage;
exports.listRecentInboundSofiaMessages = listRecentInboundSofiaMessages;
exports.createSofiaSearchTarget = createSofiaSearchTarget;
exports.listSofiaSearchTargets = listSofiaSearchTargets;
exports.listDueSofiaSearchTargets = listDueSofiaSearchTargets;
exports.markSofiaSearchTargetChecked = markSofiaSearchTargetChecked;
const pg_1 = require("pg");
let pool = null;
function requirePool() {
    if (!pool) {
        throw new Error("DB pool is not initialized");
    }
    return pool;
}
function toMillis(value) {
    if (!value) {
        return null;
    }
    return value.getTime();
}
function mapSubscriptionRow(row) {
    return {
        telegramUserId: Number(row.telegram_user_id),
        subscriptionEndsAt: toMillis(row.subscription_ends_at ?? null),
        unspentSingleReadings: Number(row.unspent_single_readings ?? 0),
        purchasedSingle: Number(row.purchased_single ?? 0),
        purchasedWeek: Number(row.purchased_week ?? 0),
        purchasedMonth: Number(row.purchased_month ?? 0),
        purchasedYear: Number(row.purchased_year ?? 0),
    };
}
function initDb(databaseUrl) {
    if (pool) {
        return;
    }
    pool = new pg_1.Pool({
        connectionString: databaseUrl,
        ssl: databaseUrl.includes("localhost") || databaseUrl.includes("127.0.0.1")
            ? false
            : { rejectUnauthorized: false },
    });
}
async function ensureSchema() {
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
    await db.query("CREATE INDEX IF NOT EXISTS subscriptions_active_idx ON subscriptions (subscription_ends_at, unspent_single_readings);");
    await db.query(`
    CREATE TABLE IF NOT EXISTS user_query_history (
      id BIGSERIAL PRIMARY KEY,
      telegram_user_id BIGINT NOT NULL REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      query_type TEXT NOT NULL,
      question TEXT NOT NULL,
      locale TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
    await db.query("CREATE INDEX IF NOT EXISTS idx_query_history_user_created ON user_query_history (telegram_user_id, created_at DESC);");
    await db.query(`
    CREATE TABLE IF NOT EXISTS bot_funnel_events (
      id BIGSERIAL PRIMARY KEY,
      telegram_user_id BIGINT REFERENCES users(telegram_user_id) ON DELETE CASCADE,
      event_name TEXT NOT NULL,
      locale TEXT,
      plan_id TEXT,
      source TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
    await db.query("CREATE INDEX IF NOT EXISTS idx_bot_funnel_events_user_created ON bot_funnel_events (telegram_user_id, created_at DESC);");
    await db.query("CREATE INDEX IF NOT EXISTS idx_bot_funnel_events_event_created ON bot_funnel_events (event_name, created_at DESC);");
    await db.query(`
    CREATE TABLE IF NOT EXISTS sofia_agent_tasks (
      id BIGSERIAL PRIMARY KEY,
      task_type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      title TEXT NOT NULL,
      source_channel TEXT,
      target_chat TEXT,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      claimed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
    await db.query(`
    CREATE TABLE IF NOT EXISTS sofia_agent_drafts (
      id BIGSERIAL PRIMARY KEY,
      task_id BIGINT NOT NULL REFERENCES sofia_agent_tasks(id) ON DELETE CASCADE,
      draft_text TEXT NOT NULL,
      model TEXT,
      notes TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
    await db.query(`
    CREATE TABLE IF NOT EXISTS sofia_agent_threads (
      id BIGSERIAL PRIMARY KEY,
      platform TEXT NOT NULL DEFAULT 'telegram',
      external_thread_id TEXT NOT NULL,
      user_label TEXT,
      topic TEXT,
      last_inbound_text TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (platform, external_thread_id)
    );
  `);
    await db.query(`
    CREATE TABLE IF NOT EXISTS sofia_agent_messages (
      id BIGSERIAL PRIMARY KEY,
      thread_id BIGINT NOT NULL REFERENCES sofia_agent_threads(id) ON DELETE CASCADE,
      platform_message_id TEXT NOT NULL,
      direction TEXT NOT NULL,
      sender_label TEXT,
      message_text TEXT NOT NULL,
      sent_at TIMESTAMPTZ NOT NULL,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (thread_id, platform_message_id)
    );
  `);
    await db.query(`
    CREATE TABLE IF NOT EXISTS sofia_agent_search_targets (
      id BIGSERIAL PRIMARY KEY,
      platform TEXT NOT NULL DEFAULT 'telegram',
      label TEXT NOT NULL,
      query TEXT NOT NULL,
      target_chat TEXT,
      cadence_minutes INTEGER NOT NULL DEFAULT 180,
      enabled BOOLEAN NOT NULL DEFAULT TRUE,
      last_checked_at TIMESTAMPTZ,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
    await db.query("CREATE INDEX IF NOT EXISTS idx_sofia_agent_tasks_status_created ON sofia_agent_tasks (status, created_at ASC);");
    await db.query("CREATE INDEX IF NOT EXISTS idx_sofia_agent_drafts_task_created ON sofia_agent_drafts (task_id, created_at DESC);");
    await db.query("CREATE INDEX IF NOT EXISTS idx_sofia_agent_messages_thread_sent ON sofia_agent_messages (thread_id, sent_at DESC);");
    await db.query("CREATE INDEX IF NOT EXISTS idx_sofia_agent_search_targets_enabled_checked ON sofia_agent_search_targets (enabled, last_checked_at ASC);");
}
async function upsertUserProfile(telegramUserId, username, firstName, lastName, locale) {
    const db = requirePool();
    await db.query(`
    INSERT INTO users (telegram_user_id, username, first_name, last_name, locale)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (telegram_user_id)
    DO UPDATE SET
      username = EXCLUDED.username,
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name,
      locale = COALESCE(EXCLUDED.locale, users.locale),
      updated_at = NOW();
    `, [telegramUserId, username, firstName, lastName, locale]);
}
async function getUserLocale(telegramUserId) {
    const db = requirePool();
    const { rows } = await db.query("SELECT locale FROM users WHERE telegram_user_id = $1 LIMIT 1;", [telegramUserId]);
    if (rows.length === 0) {
        return null;
    }
    const value = rows[0]?.locale ?? null;
    if (value === "ru" || value === "en" || value === "kk") {
        return value;
    }
    return null;
}
async function getUserSubscription(telegramUserId) {
    const db = requirePool();
    const { rows } = await db.query(`
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
    `, [telegramUserId]);
    if (rows.length === 0) {
        return null;
    }
    return mapSubscriptionRow(rows[0]);
}
async function saveUserSubscription(record) {
    const db = requirePool();
    await db.query(`
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
    `, [
        record.telegramUserId,
        record.subscriptionEndsAt ? new Date(record.subscriptionEndsAt) : null,
        record.unspentSingleReadings,
        record.purchasedSingle,
        record.purchasedWeek,
        record.purchasedMonth,
        record.purchasedYear,
    ]);
}
async function paymentExists(telegramPaymentChargeId) {
    const db = requirePool();
    const { rows } = await db.query("SELECT 1 FROM payments WHERE telegram_payment_charge_id = $1 LIMIT 1;", [telegramPaymentChargeId]);
    return rows.length > 0;
}
async function insertPayment(telegramPaymentChargeId, telegramUserId, planId, currency, totalAmount, purchaseCode, expiresAtMillis) {
    const db = requirePool();
    await db.query(`
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
    `, [
        telegramPaymentChargeId,
        telegramUserId,
        planId,
        currency,
        totalAmount,
        purchaseCode,
        expiresAtMillis ? new Date(expiresAtMillis) : null,
    ]);
}
async function listActiveSubscriptions() {
    const db = requirePool();
    const { rows } = await db.query(`
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
    `);
    return rows.map((row) => ({
        telegramUserId: Number(row.telegram_user_id),
        username: row.username ?? null,
        firstName: row.first_name ?? null,
        lastName: row.last_name ?? null,
        locale: row.locale ?? null,
        subscriptionEndsAt: toMillis(row.subscription_ends_at ?? null),
        unspentSingleReadings: Number(row.unspent_single_readings ?? 0),
        purchasedSingle: Number(row.purchased_single ?? 0),
        purchasedWeek: Number(row.purchased_week ?? 0),
        purchasedMonth: Number(row.purchased_month ?? 0),
        purchasedYear: Number(row.purchased_year ?? 0),
    }));
}
async function completeConsultation(telegramUserId) {
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
            await client.query(`
        UPDATE subscriptions
        SET
          unspent_single_readings = $2,
          updated_at = NOW()
        WHERE telegram_user_id = $1;
        `, [telegramUserId, nextSingle]);
            await client.query("COMMIT");
            return "single";
        }
        const now = Date.now();
        if ((sub.subscriptionEndsAt ?? 0) > now) {
            await client.query(`
        UPDATE subscriptions
        SET
          subscription_ends_at = NOW(),
          updated_at = NOW()
        WHERE telegram_user_id = $1;
        `, [telegramUserId]);
            await client.query("COMMIT");
            return "timed";
        }
        await client.query("COMMIT");
        return "none";
    }
    catch (error) {
        await client.query("ROLLBACK");
        throw error;
    }
    finally {
        client.release();
    }
}
async function listRecentUserQueriesForUser(telegramUserId, limit = 10) {
    const db = requirePool();
    const safeLimit = Math.max(1, Math.min(50, Number(limit) || 10));
    const { rows } = await db.query(`
    SELECT query_type, question, locale, created_at
    FROM user_query_history
    WHERE telegram_user_id = $1
    ORDER BY created_at DESC
    LIMIT $2;
    `, [telegramUserId, safeLimit]);
    return rows.map((row) => ({
        queryType: String(row.query_type ?? ""),
        question: String(row.question ?? ""),
        locale: row.locale ?? null,
        createdAt: toMillis(row.created_at ?? null),
    }));
}
async function listRecentOracleQueries(limit = 20, offset = 0) {
    const db = requirePool();
    const safeLimit = Math.max(1, Math.min(100, Number(limit) || 20));
    const safeOffset = Math.max(0, Number(offset) || 0);
    const { rows } = await db.query(`
    SELECT telegram_user_id, query_type, question, locale, created_at
    FROM user_query_history
    ORDER BY created_at DESC, id DESC
    OFFSET $1
    LIMIT $2;
    `, [safeOffset, safeLimit + 1]);
    const hasMore = rows.length > safeLimit;
    const sliced = hasMore ? rows.slice(0, safeLimit) : rows;
    return {
        rows: sliced.map((row) => ({
            telegramUserId: Number(row.telegram_user_id),
            queryType: String(row.query_type ?? ""),
            question: String(row.question ?? ""),
            locale: row.locale ?? null,
            createdAt: toMillis(row.created_at ?? null),
        })),
        hasMore,
    };
}
async function listUsersForBroadcast() {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT telegram_user_id, locale
    FROM users
    ORDER BY telegram_user_id ASC;
    `);
    return rows.map((row) => ({
        telegramUserId: Number(row.telegram_user_id),
        locale: row.locale ?? null,
    }));
}
async function listUsersForSofia() {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT telegram_user_id, username, first_name, last_name, locale, created_at
    FROM users
    ORDER BY created_at DESC, telegram_user_id DESC;
    `);
    return rows.map((row) => ({
        telegramUserId: Number(row.telegram_user_id),
        username: row.username ?? null,
        firstName: row.first_name ?? null,
        lastName: row.last_name ?? null,
        locale: row.locale ?? null,
        createdAt: toMillis(row.created_at ?? null),
    }));
}
async function listUsersCreatedTodayForSofia() {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT telegram_user_id, username, first_name, last_name, locale, created_at
    FROM users
    WHERE created_at >= date_trunc('day', NOW())
      AND created_at < date_trunc('day', NOW()) + INTERVAL '1 day'
    ORDER BY created_at DESC, telegram_user_id DESC;
    `);
    return rows.map((row) => ({
        telegramUserId: Number(row.telegram_user_id),
        username: row.username ?? null,
        firstName: row.first_name ?? null,
        lastName: row.last_name ?? null,
        locale: row.locale ?? null,
        createdAt: toMillis(row.created_at ?? null),
    }));
}
async function insertFunnelEvent(input) {
    const db = requirePool();
    await db.query(`
    INSERT INTO bot_funnel_events (
      telegram_user_id,
      event_name,
      locale,
      plan_id,
      source
    )
    VALUES ($1, $2, $3, $4, $5);
    `, [
        input.telegramUserId,
        input.eventName,
        input.locale ?? null,
        input.planId ?? null,
        input.source ?? null,
    ]);
}
async function getSubscriptionForUpdate(client, telegramUserId) {
    const { rows } = await client.query(`
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
    `, [telegramUserId]);
    if (rows.length === 0) {
        return null;
    }
    return mapSubscriptionRow(rows[0]);
}
function mapSofiaAgentTaskRow(row) {
    return {
        id: Number(row.id),
        taskType: String(row.task_type ?? ""),
        status: String(row.status ?? "pending"),
        title: String(row.title ?? ""),
        sourceChannel: row.source_channel ?? null,
        targetChat: row.target_chat ?? null,
        payload: row.payload ?? {},
        claimedAt: toMillis(row.claimed_at ?? null),
        createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
        updatedAt: toMillis(row.updated_at ?? null) ?? Date.now(),
    };
}
function mapSofiaAgentThreadRow(row) {
    return {
        id: Number(row.id),
        platform: String(row.platform ?? "telegram"),
        externalThreadId: String(row.external_thread_id ?? ""),
        userLabel: row.user_label ?? null,
        topic: row.topic ?? null,
        lastInboundText: row.last_inbound_text ?? null,
        metadata: row.metadata ?? {},
        createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
        updatedAt: toMillis(row.updated_at ?? null) ?? Date.now(),
    };
}
function mapSofiaAgentSearchTargetRow(row) {
    return {
        id: Number(row.id),
        platform: String(row.platform ?? "telegram"),
        label: String(row.label ?? ""),
        query: String(row.query ?? ""),
        targetChat: row.target_chat ?? null,
        cadenceMinutes: Number(row.cadence_minutes ?? 180),
        enabled: Boolean(row.enabled),
        lastCheckedAt: toMillis(row.last_checked_at ?? null),
        metadata: row.metadata ?? {},
        createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
        updatedAt: toMillis(row.updated_at ?? null) ?? Date.now(),
    };
}
async function createSofiaAgentTask(input) {
    const db = requirePool();
    const { rows } = await db.query(`
    INSERT INTO sofia_agent_tasks (
      task_type,
      title,
      source_channel,
      target_chat,
      payload
    )
    VALUES ($1, $2, $3, $4, $5::jsonb)
    RETURNING *;
    `, [
        input.taskType,
        input.title,
        input.sourceChannel,
        input.targetChat,
        JSON.stringify(input.payload ?? {}),
    ]);
    return mapSofiaAgentTaskRow(rows[0]);
}
async function claimNextSofiaAgentTask() {
    const db = requirePool();
    const client = await db.connect();
    try {
        await client.query("BEGIN");
        const { rows } = await client.query(`
      SELECT *
      FROM sofia_agent_tasks
      WHERE status = 'pending'
      ORDER BY created_at ASC, id ASC
      LIMIT 1
      FOR UPDATE SKIP LOCKED;
      `);
        if (rows.length === 0) {
            await client.query("COMMIT");
            return null;
        }
        const row = rows[0];
        await client.query(`
      UPDATE sofia_agent_tasks
      SET status = 'in_progress', claimed_at = NOW(), updated_at = NOW()
      WHERE id = $1;
      `, [row.id]);
        await client.query("COMMIT");
        return {
            ...mapSofiaAgentTaskRow(row),
            status: "in_progress",
            claimedAt: Date.now(),
            updatedAt: Date.now(),
        };
    }
    catch (error) {
        await client.query("ROLLBACK");
        throw error;
    }
    finally {
        client.release();
    }
}
async function saveSofiaAgentDraft(input) {
    const db = requirePool();
    const client = await db.connect();
    try {
        await client.query("BEGIN");
        const { rows } = await client.query(`
      INSERT INTO sofia_agent_drafts (task_id, draft_text, model, notes)
      VALUES ($1, $2, $3, $4)
      RETURNING *;
      `, [input.taskId, input.draftText, input.model ?? null, input.notes ?? null]);
        await client.query(`
      UPDATE sofia_agent_tasks
      SET status = 'draft_ready', updated_at = NOW()
      WHERE id = $1;
      `, [input.taskId]);
        await client.query("COMMIT");
        const row = rows[0];
        return {
            id: Number(row.id),
            taskId: Number(row.task_id),
            draftText: String(row.draft_text ?? ""),
            model: row.model ?? null,
            notes: row.notes ?? null,
            createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
        };
    }
    catch (error) {
        await client.query("ROLLBACK");
        throw error;
    }
    finally {
        client.release();
    }
}
async function markSofiaAgentTaskFailed(taskId, notes) {
    const db = requirePool();
    await db.query(`
    UPDATE sofia_agent_tasks
    SET status = 'failed',
        updated_at = NOW(),
        payload = jsonb_set(COALESCE(payload, '{}'::jsonb), '{lastError}', to_jsonb($2::text), true)
    WHERE id = $1;
    `, [taskId, notes]);
}
async function listSofiaAgentDrafts(limit = 20) {
    const db = requirePool();
    const safeLimit = Math.max(1, Math.min(100, Number(limit) || 20));
    const { rows } = await db.query(`
    SELECT id, task_id, draft_text, model, notes, created_at
    FROM sofia_agent_drafts
    ORDER BY created_at DESC, id DESC
    LIMIT $1;
    `, [safeLimit]);
    return rows.map((row) => ({
        id: Number(row.id),
        taskId: Number(row.task_id),
        draftText: String(row.draft_text ?? ""),
        model: row.model ?? null,
        notes: row.notes ?? null,
        createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
    }));
}
async function markSofiaAgentTaskApproved(taskId) {
    const db = requirePool();
    await db.query(`
    UPDATE sofia_agent_tasks
    SET status = 'approved', updated_at = NOW()
    WHERE id = $1;
    `, [taskId]);
}
async function markSofiaAgentTaskSent(taskId, sendNotes) {
    const db = requirePool();
    await db.query(`
    UPDATE sofia_agent_tasks
    SET status = 'sent',
        updated_at = NOW(),
        payload = CASE
          WHEN $2::text IS NULL THEN payload
          ELSE jsonb_set(COALESCE(payload, '{}'::jsonb), '{sendNotes}', to_jsonb($2::text), true)
        END
    WHERE id = $1;
    `, [taskId, sendNotes ?? null]);
}
async function getLatestDraftForTask(taskId) {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT id, task_id, draft_text, model, notes, created_at
    FROM sofia_agent_drafts
    WHERE task_id = $1
    ORDER BY created_at DESC, id DESC
    LIMIT 1;
    `, [taskId]);
    if (rows.length === 0) {
        return null;
    }
    const row = rows[0];
    return {
        id: Number(row.id),
        taskId: Number(row.task_id),
        draftText: String(row.draft_text ?? ""),
        model: row.model ?? null,
        notes: row.notes ?? null,
        createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
    };
}
async function listSofiaAgentTasksByStatus(status, limit = 20) {
    const db = requirePool();
    const safeLimit = Math.max(1, Math.min(100, Number(limit) || 20));
    const { rows } = await db.query(`
    SELECT *
    FROM sofia_agent_tasks
    WHERE status = $1
    ORDER BY created_at ASC, id ASC
    LIMIT $2;
    `, [status, safeLimit]);
    return rows.map((row) => mapSofiaAgentTaskRow(row));
}
async function findSofiaTaskByDedupKey(dedupKey) {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT *
    FROM sofia_agent_tasks
    WHERE payload->>'dedupKey' = $1
    ORDER BY created_at DESC, id DESC
    LIMIT 1;
    `, [dedupKey]);
    if (rows.length === 0) {
        return null;
    }
    return mapSofiaAgentTaskRow(rows[0]);
}
async function upsertSofiaAgentThread(input) {
    const db = requirePool();
    const { rows } = await db.query(`
    INSERT INTO sofia_agent_threads (
      platform,
      external_thread_id,
      user_label,
      topic,
      last_inbound_text,
      metadata
    )
    VALUES ('telegram', $1, $2, $3, $4, $5::jsonb)
    ON CONFLICT (platform, external_thread_id)
    DO UPDATE SET
      user_label = COALESCE(EXCLUDED.user_label, sofia_agent_threads.user_label),
      topic = COALESCE(EXCLUDED.topic, sofia_agent_threads.topic),
      last_inbound_text = COALESCE(EXCLUDED.last_inbound_text, sofia_agent_threads.last_inbound_text),
      metadata = COALESCE(sofia_agent_threads.metadata, '{}'::jsonb) || EXCLUDED.metadata,
      updated_at = NOW()
    RETURNING *;
    `, [
        input.externalThreadId,
        input.userLabel ?? null,
        input.topic ?? null,
        input.lastInboundText ?? null,
        JSON.stringify(input.metadata ?? {}),
    ]);
    return mapSofiaAgentThreadRow(rows[0]);
}
async function createSofiaAgentMessage(input) {
    const db = requirePool();
    const { rows } = await db.query(`
    INSERT INTO sofia_agent_messages (
      thread_id,
      platform_message_id,
      direction,
      sender_label,
      message_text,
      sent_at,
      metadata
    )
    VALUES ($1, $2, $3, $4, $5, to_timestamp($6 / 1000.0), $7::jsonb)
    ON CONFLICT (thread_id, platform_message_id)
    DO NOTHING
    RETURNING *;
    `, [
        input.threadId,
        input.platformMessageId,
        input.direction,
        input.senderLabel ?? null,
        input.messageText,
        input.sentAt,
        JSON.stringify(input.metadata ?? {}),
    ]);
    if (rows.length > 0) {
        const row = rows[0];
        return {
            inserted: true,
            row: {
                id: Number(row.id),
                threadId: Number(row.thread_id),
                platformMessageId: String(row.platform_message_id ?? ""),
                direction: String(row.direction ?? "inbound"),
                senderLabel: row.sender_label ?? null,
                messageText: String(row.message_text ?? ""),
                sentAt: toMillis(row.sent_at ?? null) ?? Date.now(),
                metadata: row.metadata ?? {},
                createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
            },
        };
    }
    const existing = await db.query(`
    SELECT *
    FROM sofia_agent_messages
    WHERE thread_id = $1 AND platform_message_id = $2
    LIMIT 1;
    `, [input.threadId, input.platformMessageId]);
    const row = existing.rows[0];
    return {
        inserted: false,
        row: {
            id: Number(row.id),
            threadId: Number(row.thread_id),
            platformMessageId: String(row.platform_message_id ?? ""),
            direction: String(row.direction ?? "inbound"),
            senderLabel: row.sender_label ?? null,
            messageText: String(row.message_text ?? ""),
            sentAt: toMillis(row.sent_at ?? null) ?? Date.now(),
            metadata: row.metadata ?? {},
            createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
        },
    };
}
async function listRecentInboundSofiaMessages(limit = 20) {
    const db = requirePool();
    const safeLimit = Math.max(1, Math.min(200, Number(limit) || 20));
    const { rows } = await db.query(`
    SELECT *
    FROM sofia_agent_messages
    WHERE direction = 'inbound'
    ORDER BY sent_at DESC, id DESC
    LIMIT $1;
    `, [safeLimit]);
    return rows.map((row) => ({
        id: Number(row.id),
        threadId: Number(row.thread_id),
        platformMessageId: String(row.platform_message_id ?? ""),
        direction: String(row.direction ?? "inbound"),
        senderLabel: row.sender_label ?? null,
        messageText: String(row.message_text ?? ""),
        sentAt: toMillis(row.sent_at ?? null) ?? Date.now(),
        metadata: row.metadata ?? {},
        createdAt: toMillis(row.created_at ?? null) ?? Date.now(),
    }));
}
async function createSofiaSearchTarget(input) {
    const db = requirePool();
    const { rows } = await db.query(`
    INSERT INTO sofia_agent_search_targets (
      platform,
      label,
      query,
      target_chat,
      cadence_minutes,
      metadata
    )
    VALUES ('telegram', $1, $2, $3, $4, $5::jsonb)
    RETURNING *;
    `, [
        input.label,
        input.query,
        input.targetChat,
        input.cadenceMinutes ?? 180,
        JSON.stringify(input.metadata ?? {}),
    ]);
    return mapSofiaAgentSearchTargetRow(rows[0]);
}
async function listSofiaSearchTargets(enabledOnly = false) {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT *
    FROM sofia_agent_search_targets
    ${enabledOnly ? "WHERE enabled = TRUE" : ""}
    ORDER BY created_at ASC, id ASC;
    `);
    return rows.map((row) => mapSofiaAgentSearchTargetRow(row));
}
async function listDueSofiaSearchTargets(now = Date.now()) {
    const db = requirePool();
    const { rows } = await db.query(`
    SELECT *
    FROM sofia_agent_search_targets
    WHERE enabled = TRUE
      AND (
        last_checked_at IS NULL
        OR last_checked_at <= to_timestamp($1 / 1000.0) - make_interval(mins => cadence_minutes)
      )
    ORDER BY COALESCE(last_checked_at, to_timestamp(0)) ASC, id ASC;
    `, [now]);
    return rows.map((row) => mapSofiaAgentSearchTargetRow(row));
}
async function markSofiaSearchTargetChecked(targetId) {
    const db = requirePool();
    await db.query(`
    UPDATE sofia_agent_search_targets
    SET last_checked_at = NOW(), updated_at = NOW()
    WHERE id = $1;
    `, [targetId]);
}
