import crypto from "node:crypto";
import express from "express";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import pg from "pg";

const { Pool } = pg;
const require = createRequire(import.meta.url);
const { Origin, Horoscope } = require("circular-natal-horoscope-js/dist/index.js");

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();
const port = Number(process.env.PORT || 8080);
const publicDir = path.join(__dirname, "public");
const sessionCookieName = "astro_sid";
const databaseUrl = String(process.env.DATABASE_URL || "").trim();
const telegramBotToken = String(process.env.TELEGRAM_BOT_TOKEN || "").trim();
const telegramBotUsername = String(process.env.TELEGRAM_BOT_USERNAME || "").trim();
const telegramBotId = Number.parseInt(String(telegramBotToken.split(":")[0] || "").trim(), 10) || null;
const authRequired =
  String(process.env.AUTH_REQUIRED || "").trim() === "1" ||
  String(process.env.AUTH_REQUIRED || "").trim().toLowerCase() === "true" ||
  Boolean(telegramBotToken);
const MAX_TELEGRAM_AUTH_AGE_SECONDS = 60 * 60 * 24;

app.set("trust proxy", 1);

const sessionStore = new Map();
const geoCache = new Map();
const citySuggestCache = new Map();
const userStore = new Map();
let dbPool = null;
const allowedCityCountryCodes = new Set([
  "AL",
  "AD",
  "AM",
  "AT",
  "AZ",
  "BA",
  "BE",
  "BG",
  "BY",
  "CH",
  "CY",
  "CZ",
  "DE",
  "DK",
  "EE",
  "ES",
  "FI",
  "FR",
  "GB",
  "GE",
  "GR",
  "HR",
  "HU",
  "IE",
  "IS",
  "IT",
  "KZ",
  "KG",
  "LI",
  "LT",
  "LU",
  "LV",
  "MD",
  "ME",
  "MK",
  "MT",
  "NL",
  "NO",
  "PL",
  "PT",
  "RO",
  "RS",
  "RU",
  "SE",
  "SI",
  "SK",
  "SM",
  "TJ",
  "TM",
  "TR",
  "UA",
  "UZ",
  "VA",
  "XK"
]);

function defaultSessionData() {
  return {
    createdAt: Date.now(),
    auth: null,
    profile: null,
    friends: [],
    daily: {
      streak: 0,
      lastDayKey: "",
      history: []
    }
  };
}

function defaultUserData() {
  return {
    profile: null,
    friends: [],
    daily: {
      streak: 0,
      lastDayKey: "",
      history: []
    }
  };
}

function normalizeUserData(raw) {
  const source = raw && typeof raw === "object" ? raw : {};
  const profile = source.profile && typeof source.profile === "object" ? source.profile : null;
  const friends = Array.isArray(source.friends) ? source.friends : [];
  const dailySource = source.daily && typeof source.daily === "object" ? source.daily : {};
  return {
    profile,
    friends,
    daily: {
      streak: Number.isFinite(Number(dailySource.streak)) ? Number(dailySource.streak) : 0,
      lastDayKey: String(dailySource.lastDayKey || ""),
      history: Array.isArray(dailySource.history) ? dailySource.history : []
    }
  };
}

function normalizeSessionData(raw) {
  const source = raw && typeof raw === "object" ? raw : {};
  const profile = source.profile && typeof source.profile === "object" ? source.profile : null;
  const friends = Array.isArray(source.friends) ? source.friends : [];
  const dailySource = source.daily && typeof source.daily === "object" ? source.daily : {};
  const authSource = source.auth && typeof source.auth === "object" ? source.auth : null;

  const auth = authSource
    ? {
        provider: String(authSource.provider || ""),
        telegramUserId: String(authSource.telegramUserId || ""),
        telegramUser:
          authSource.telegramUser && typeof authSource.telegramUser === "object"
            ? authSource.telegramUser
            : null,
        authenticatedAt: Number.isFinite(Number(authSource.authenticatedAt))
          ? Number(authSource.authenticatedAt)
          : null,
        via: String(authSource.via || "")
      }
    : null;

  return {
    createdAt: Number.isFinite(Number(source.createdAt)) ? Number(source.createdAt) : Date.now(),
    auth,
    profile,
    friends,
    daily: {
      streak: Number.isFinite(Number(dailySource.streak)) ? Number(dailySource.streak) : 0,
      lastDayKey: String(dailySource.lastDayKey || ""),
      history: Array.isArray(dailySource.history) ? dailySource.history : []
    }
  };
}

function parseCookies(cookieHeader) {
  const result = {};
  if (!cookieHeader) {
    return result;
  }
  const pairs = cookieHeader.split(";");
  for (const pair of pairs) {
    const [rawKey, ...rawValue] = pair.split("=");
    const key = String(rawKey || "").trim();
    const value = rawValue.join("=").trim();
    if (key) {
      result[key] = decodeURIComponent(value || "");
    }
  }
  return result;
}

function buildSessionCookie(sid, req) {
  const forwardedProto = String(req.headers["x-forwarded-proto"] || "").toLowerCase();
  const shouldUseSecure = req.secure || forwardedProto.includes("https") || process.env.NODE_ENV === "production";
  const securePart = shouldUseSecure ? "; Secure" : "";
  return `${sessionCookieName}=${encodeURIComponent(sid)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000${securePart}`;
}

async function initDb() {
  if (!databaseUrl) {
    return;
  }
  dbPool = new Pool({ connectionString: databaseUrl });
  await dbPool.query(`
    CREATE TABLE IF NOT EXISTS astro_web_sessions (
      sid TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await dbPool.query(`
    CREATE TABLE IF NOT EXISTS astro_web_user_state (
      telegram_user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function loadSessionFromDb(sid) {
  if (!dbPool) {
    return null;
  }
  const result = await dbPool.query("SELECT data FROM astro_web_sessions WHERE sid = $1 LIMIT 1", [sid]);
  if (!result.rowCount) {
    return null;
  }
  return normalizeSessionData(result.rows[0].data);
}

async function createSessionInDb(sid, data) {
  if (!dbPool) {
    return;
  }
  await dbPool.query(
    `
      INSERT INTO astro_web_sessions (sid, data)
      VALUES ($1, $2::jsonb)
      ON CONFLICT (sid)
      DO NOTHING
    `,
    [sid, JSON.stringify(normalizeSessionData(data))]
  );
}

async function saveSessionToDb(sid, data) {
  if (!dbPool) {
    return;
  }
  const normalized = normalizeSessionData(data);
  await dbPool.query(
    `
      INSERT INTO astro_web_sessions (sid, data, updated_at)
      VALUES ($1, $2::jsonb, NOW())
      ON CONFLICT (sid)
      DO UPDATE SET data = EXCLUDED.data, updated_at = NOW()
    `,
    [sid, JSON.stringify(normalized)]
  );
}

async function loadUserDataFromDb(telegramUserId) {
  if (!dbPool) {
    return null;
  }
  const result = await dbPool.query(
    "SELECT data FROM astro_web_user_state WHERE telegram_user_id = $1 LIMIT 1",
    [telegramUserId]
  );
  if (!result.rowCount) {
    return null;
  }
  return normalizeUserData(result.rows[0].data);
}

async function saveUserDataToDb(telegramUserId, data) {
  if (!dbPool) {
    return;
  }
  const normalized = normalizeUserData(data);
  await dbPool.query(
    `
      INSERT INTO astro_web_user_state (telegram_user_id, data, updated_at)
      VALUES ($1, $2::jsonb, NOW())
      ON CONFLICT (telegram_user_id)
      DO UPDATE SET data = EXCLUDED.data, updated_at = NOW()
    `,
    [telegramUserId, JSON.stringify(normalized)]
  );
}

async function deleteAllUserData() {
  if (!dbPool) {
    userStore.clear();
    return;
  }
  await dbPool.query("DELETE FROM astro_web_user_state");
}

async function loadUserData(telegramUserId) {
  if (!telegramUserId) {
    return defaultUserData();
  }
  if (dbPool) {
    return (await loadUserDataFromDb(telegramUserId)) || defaultUserData();
  }
  return normalizeUserData(userStore.get(telegramUserId) || defaultUserData());
}

async function saveUserData(telegramUserId, data) {
  if (!telegramUserId) {
    return;
  }
  if (dbPool) {
    await saveUserDataToDb(telegramUserId, data);
    return;
  }
  userStore.set(telegramUserId, normalizeUserData(data));
}

async function deleteSessionBySid(sid) {
  if (!sid) {
    return;
  }
  if (dbPool) {
    await dbPool.query("DELETE FROM astro_web_sessions WHERE sid = $1", [sid]);
    return;
  }
  sessionStore.delete(sid);
}

async function getOrCreateSession(req, res) {
  const cookies = parseCookies(req.headers.cookie);
  const cookieSid = String(cookies[sessionCookieName] || "").trim();

  if (dbPool) {
    if (cookieSid) {
      const existing = await loadSessionFromDb(cookieSid);
      if (existing) {
        return { sid: cookieSid, data: existing };
      }
      const seeded = defaultSessionData();
      await createSessionInDb(cookieSid, seeded);
      return { sid: cookieSid, data: seeded };
    }

    const sid = crypto.randomUUID();
    const seeded = defaultSessionData();
    await createSessionInDb(sid, seeded);
    res.setHeader("Set-Cookie", buildSessionCookie(sid, req));
    return { sid, data: seeded };
  }

  if (cookieSid && sessionStore.has(cookieSid)) {
    return { sid: cookieSid, data: normalizeSessionData(sessionStore.get(cookieSid)) };
  }

  const sid = cookieSid || crypto.randomUUID();
  const session = defaultSessionData();
  sessionStore.set(sid, session);
  if (!cookieSid) {
    res.setHeader("Set-Cookie", buildSessionCookie(sid, req));
  }
  return { sid, data: session };
}

async function persistSession(sid, data) {
  if (dbPool) {
    await saveSessionToDb(sid, data);
    return;
  }
  sessionStore.set(sid, normalizeSessionData(data));
}

function pickProfile(body) {
  const profile = body?.profile;
  if (!profile || typeof profile !== "object") {
    return null;
  }
  const name = String(profile.name || "").trim();
  const birthDate = String(profile.birthDate || "").trim();
  const birthTime = String(profile.birthTime || "").trim();
  const birthCity = String(profile.birthCity || "").trim();
  const timezone = String(profile.timezone || "UTC").trim();
  const latitude = Number(profile.latitude);
  const longitude = Number(profile.longitude);
  const timezoneIana = String(profile.timezoneIana || "").trim();

  if (!name || !birthDate || !birthTime || !birthCity) {
    return null;
  }

  return {
    name,
    birthDate,
    birthTime,
    birthCity,
    timezone,
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null,
    timezoneIana: timezoneIana || null
  };
}

function signFromDate(dateText) {
  const date = new Date(`${dateText}T00:00:00Z`);
  const month = Number.isFinite(date.getUTCMonth()) ? date.getUTCMonth() : 0;
  const signs = [
    "Capricorn",
    "Aquarius",
    "Pisces",
    "Aries",
    "Taurus",
    "Gemini",
    "Cancer",
    "Leo",
    "Virgo",
    "Libra",
    "Scorpio",
    "Sagittarius"
  ];
  return signs[(month + 11) % 12];
}

function moonFromDate(dateText) {
  const date = new Date(`${dateText}T00:00:00Z`);
  const day = Number.isFinite(date.getUTCDate()) ? date.getUTCDate() : 1;
  const signs = [
    "Aries",
    "Taurus",
    "Gemini",
    "Cancer",
    "Leo",
    "Virgo",
    "Libra",
    "Scorpio",
    "Sagittarius",
    "Capricorn",
    "Aquarius",
    "Pisces"
  ];
  return signs[day % signs.length];
}

function risingFromTime(timeText) {
  const rawHour = Number(String(timeText).split(":")[0]);
  const hour = Number.isFinite(rawHour) ? rawHour : 0;
  const signs = [
    "Aries",
    "Taurus",
    "Gemini",
    "Cancer",
    "Leo",
    "Virgo",
    "Libra",
    "Scorpio",
    "Sagittarius",
    "Capricorn",
    "Aquarius",
    "Pisces"
  ];
  return signs[Math.floor(hour / 2) % signs.length];
}

const zodiacElements = {
  Aries: "fire",
  Leo: "fire",
  Sagittarius: "fire",
  Taurus: "earth",
  Virgo: "earth",
  Capricorn: "earth",
  Gemini: "air",
  Libra: "air",
  Aquarius: "air",
  Cancer: "water",
  Scorpio: "water",
  Pisces: "water"
};

function signElement(sign) {
  return zodiacElements[String(sign || "").trim()] || "neutral";
}

function monthDayCount(now) {
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}

function buildRealEnergySeries(profile, period, now, natalCore) {
  if (!Number.isFinite(profile.latitude) || !Number.isFinite(profile.longitude)) {
    return null;
  }
  const count = period === "year" ? 12 : period === "month" ? monthDayCount(now) : 7;
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  const labels = [];
  const values = [];
  const transits = [];
  for (let idx = 0; idx < count; idx += 1) {
    let pointDate;
    if (period === "year") {
      pointDate = new Date(Date.UTC(year, idx, 1, 12, 0, 0));
      labels.push(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][idx]);
    } else if (period === "month") {
      pointDate = new Date(Date.UTC(year, month, idx + 1, 12, 0, 0));
      labels.push(String(idx + 1));
    } else {
      const mondayBased = now.getUTCDay() === 0 ? 6 : now.getUTCDay() - 1;
      const monday = new Date(Date.UTC(year, month, now.getUTCDate() - mondayBased, 12, 0, 0));
      pointDate = new Date(monday.getTime() + idx * 86400000);
      labels.push(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][idx]);
    }
    try {
      const origin = new Origin({
        year: pointDate.getUTCFullYear(),
        month: pointDate.getUTCMonth(),
        date: pointDate.getUTCDate(),
        hour: pointDate.getUTCHours(),
        minute: pointDate.getUTCMinutes(),
        latitude: profile.latitude,
        longitude: profile.longitude
      });
      const horoscope = new Horoscope({
        origin,
        houseSystem: "placidus",
        zodiac: "tropical",
        language: "en"
      });
      const transitSun = horoscope?.CelestialBodies?.sun?.Sign?.label || "Unknown";
      const transitMoon = horoscope?.CelestialBodies?.moon?.Sign?.label || "Unknown";
      const transitRising = horoscope?.Ascendant?.Sign?.label || "Unknown";
      const bodyAngle = (body) => {
        const raw = Number(body?.ChartPosition?.Ecliptic?.DecimalDegrees);
        if (!Number.isFinite(raw)) {
          return null;
        }
        const normalized = ((raw % 360) + 360) % 360;
        return Number(normalized.toFixed(3));
      };
      transits.push({
        label: labels[labels.length - 1],
        sun: { sign: transitSun, angle: bodyAngle(horoscope?.CelestialBodies?.sun) },
        moon: { sign: transitMoon, angle: bodyAngle(horoscope?.CelestialBodies?.moon) },
        rising: { sign: transitRising, angle: bodyAngle(horoscope?.Ascendant) },
        mercury: {
          sign: horoscope?.CelestialBodies?.mercury?.Sign?.label || "Unknown",
          angle: bodyAngle(horoscope?.CelestialBodies?.mercury)
        },
        venus: {
          sign: horoscope?.CelestialBodies?.venus?.Sign?.label || "Unknown",
          angle: bodyAngle(horoscope?.CelestialBodies?.venus)
        },
        mars: {
          sign: horoscope?.CelestialBodies?.mars?.Sign?.label || "Unknown",
          angle: bodyAngle(horoscope?.CelestialBodies?.mars)
        }
      });
      const natalSun = natalCore?.sun || "Unknown";
      const natalMoon = natalCore?.moon || "Unknown";
      const natalRising = natalCore?.rising || "Unknown";
      let score = 48;
      if (transitSun === natalSun) score += 16;
      if (transitMoon === natalMoon) score += 12;
      if (transitRising === natalRising) score += 9;
      if (signElement(transitSun) === signElement(natalSun)) score += 6;
      if (signElement(transitMoon) === signElement(natalMoon)) score += 7;
      const phaseNoise = (hashStringToInt(`${transitSun}:${transitMoon}:${idx}:${period}`) % 9) - 4;
      score += phaseNoise;
      values.push(Math.max(8, Math.min(96, Math.round(score))));
    } catch {
      values.push(50);
      transits.push({
        label: labels[labels.length - 1],
        sun: { sign: "Unknown", angle: null },
        moon: { sign: "Unknown", angle: null },
        rising: { sign: "Unknown", angle: null },
        mercury: { sign: "Unknown", angle: null },
        venus: { sign: "Unknown", angle: null },
        mars: { sign: "Unknown", angle: null }
      });
    }
  }
  const peak = Math.max(...values);
  const dip = Math.min(...values);
  return {
    period,
    values,
    labels,
    peakIndex: values.indexOf(peak),
    dipIndex: values.indexOf(dip),
    source: "transit-derived",
    transits
  };
}

function resolveSessionProfile(reqProfile, session) {
  const bodyProfile = pickProfile({ profile: reqProfile });
  if (bodyProfile) {
    return bodyProfile;
  }
  return pickProfile({ profile: session.profile });
}

function pushDailyHistory(dailyState, entry) {
  const history = Array.isArray(dailyState.history) ? dailyState.history : [];
  dailyState.history = [entry, ...history.filter((item) => item.dayKey !== entry.dayKey)].slice(0, 7);
}

function hashStringToInt(value) {
  const source = String(value || "");
  let hash = 0;
  for (let i = 0; i < source.length; i += 1) {
    hash = (hash * 31 + source.charCodeAt(i)) >>> 0;
  }
  return hash;
}

function buildPeriodForecast(period, profile, now, natalCore) {
  const normalizedPeriod = ["week", "month", "year"].includes(period) ? period : "week";
  const daySeed = Number(now.toISOString().slice(0, 10).replaceAll("-", ""));
  const sign = signFromDate(profile.birthDate);
  const base = hashStringToInt(`${profile.name}:${sign}:${normalizedPeriod}:${daySeed}`);
  const intensity = 45 + (base % 51);

  const messageByPeriod = {
    week: `For this week, stabilize execution tempo: one strategic move per day beats reactive bursts.`,
    month: `For this month, build structural momentum: reduce context switching and protect recurring focus windows.`,
    year: `For this year, your best outcomes come from long-range consistency and explicit partnership boundaries.`
  };

  const series = buildRealEnergySeries(profile, normalizedPeriod, now, natalCore);
  return {
    period: normalizedPeriod,
    intensity,
    summary: messageByPeriod[normalizedPeriod],
    series
  };
}

function buildCompatibilityDetail({ userSign, friendSign, friendName = "Friend", dayKey, period = "week", seedKey = "" }) {
  const seed = hashStringToInt(`${seedKey}:${friendSign}:${dayKey}:${userSign}:${period}`);
  const score = 52 + (seed % 47);
  const trend = score >= 75 ? "high" : score >= 62 ? "stable" : "fragile";
  const note =
    score >= 75
      ? "Easy dialogue window today. Good day for co-planning."
      : score >= 62
        ? "Neutral dynamic. Keep communication explicit."
        : "Sensitivity elevated. Clarify intent early.";
  const syncScore = Math.max(35, Math.min(96, score + ((seed % 9) - 4)));
  const emotionalScore = Math.max(30, Math.min(95, score + ((seed % 13) - 6)));
  const frictionScore = Math.max(22, Math.min(90, 100 - score + ((seed % 7) - 3)));
  const archetypeBySign = {
    Aries: "initiative-heavy",
    Taurus: "stability-first",
    Gemini: "information-dense",
    Cancer: "care-driven",
    Leo: "expressive",
    Virgo: "precision-first",
    Libra: "agreement-seeking",
    Scorpio: "intensity-driven",
    Sagittarius: "expansion-oriented",
    Capricorn: "structure-led",
    Aquarius: "systems-oriented",
    Pisces: "intuition-led"
  };
  const userElement = signElement(userSign);
  const friendElement = signElement(friendSign);
  const elementMessage =
    userElement === friendElement
      ? `${userElement[0].toUpperCase()}${userElement.slice(1)}-element overlap amplifies natural rapport and shared pacing.`
      : userElement === "fire" && friendElement === "air"
        ? "Fire + Air pairing tends to accelerate ideation and execution when priorities are explicit."
        : userElement === "earth" && friendElement === "water"
          ? "Earth + Water pairing supports dependable progress through emotional trust and practical follow-through."
          : "Cross-element pairing can be highly productive, but benefits from explicit protocols and shared definitions.";
  const highlights = [
    `${userSign} x ${friendSign}: interaction style is ${archetypeBySign[userSign] || "distinct"} meeting ${archetypeBySign[friendSign] || "distinct"} patterns.`,
    elementMessage,
    score >= 72
      ? "Coordination potential is above baseline for planning, commitments and shared deadlines."
      : "Alignment improves when goals are decomposed into short, observable checkpoints.",
    score <= 60
      ? "Friction risk increases if assumptions stay implicit, especially under time pressure."
      : "Repair cycles remain short when feedback is immediate and behavior-specific."
  ];
  const advice = score >= 72
    ? `With ${friendName}, assign ownership early and run a weekly 10-minute sync to preserve momentum.`
    : score >= 62
      ? `With ${friendName}, define one weekly objective and one explicit communication rule for updates.`
      : `With ${friendName}, reduce ambiguity: confirm intent, timeline and decision owner in one message.`;
  const rationale =
    score >= 76
      ? `High score reflects strong behavioral resonance between ${userSign} and ${friendSign}: tempo, response timing and decision framing are naturally compatible.`
      : score >= 62
        ? `Balanced score reflects selective resonance: some dimensions align well, while others require deliberate communication structure.`
        : `Lower score reflects elevated coordination friction between ${userSign} and ${friendSign}: stable outcomes require tighter protocol and pacing discipline.`;
  return {
    score,
    trend,
    note,
    highlights,
    advice,
    rationale,
    domains: [
      {
        key: "sync",
        label: "Communication Sync",
        score: syncScore,
        comment: syncScore >= 70 ? "Fast understanding with little clarification overhead." : "Needs explicit framing to avoid ambiguity."
      },
      {
        key: "emotional",
        label: "Emotional Stability",
        score: emotionalScore,
        comment: emotionalScore >= 70 ? "Repair cycles are typically short and constructive." : "Emotional timing can drift without clear checkpoints."
      },
      {
        key: "friction",
        label: "Friction Load",
        score: frictionScore,
        comment: frictionScore <= 35 ? "Low conflict pressure in routine interactions." : "Potential tension rises under stress or unclear boundaries."
      }
    ],
    userSign,
    friendSign,
    period
  };
}

function buildDynamicCompatibility(profile, friend, dayKey, period, userSign) {
  const normalizedUserSign = String(userSign || "").trim() || (profile ? signFromDate(profile.birthDate) : "Unknown");
  const detail = buildCompatibilityDetail({
    userSign: normalizedUserSign,
    friendSign: friend.friendSign,
    friendName: friend.friendName,
    dayKey,
    period,
    seedKey: friend.id || friend.friendName
  });
  return {
    id: friend.id,
    friendName: friend.friendName,
    friendSign: friend.friendSign,
    ...detail
  };
}

function buildNatalDetail(profile) {
  const fallbackSun = signFromDate(profile.birthDate);
  const fallbackMoon = moonFromDate(profile.birthDate);
  const fallbackRising = risingFromTime(profile.birthTime);
  const base = {
    core: { sun: fallbackSun, moon: fallbackMoon, rising: fallbackRising },
    summary: `${profile.name}, your chart emphasizes ${fallbackSun} identity with ${fallbackMoon} emotional tone and ${fallbackRising} outward style.`,
    blocks: {
      strength: `${fallbackSun} supports long-range identity coherence. You can sustain direction through pressure.`,
      blindSpot: `${fallbackMoon} can overreact to relational uncertainty when signals are mixed.`,
      action: `Use ${fallbackRising} visibility intentionally: one clear priority and one explicit boundary today.`
    },
    aspects: [],
    planets: [],
    housesFocus: [],
    housesAll: [],
    growthPlan: [
      "Define one non-negotiable boundary for the week.",
      "Convert one emotional reaction into a measurable action.",
      "Review one long-term commitment every Sunday."
    ],
    calculation: {
      mode: "fallback",
      houseSystem: "placidus",
      zodiac: "tropical"
    }
  };

  if (!Number.isFinite(profile.latitude) || !Number.isFinite(profile.longitude)) {
    return base;
  }

  try {
    const [year, monthRaw, day] = String(profile.birthDate).split("-").map((v) => Number(v));
    const [hour, minute] = String(profile.birthTime).split(":").map((v) => Number(v));
    if (![year, monthRaw, day, hour, minute].every((v) => Number.isFinite(v))) {
      return base;
    }

    const origin = new Origin({
      year,
      month: monthRaw - 1,
      date: day,
      hour,
      minute,
      latitude: profile.latitude,
      longitude: profile.longitude
    });
    const horoscope = new Horoscope({
      origin,
      houseSystem: "placidus",
      zodiac: "tropical",
      aspectPoints: ["bodies", "points", "angles"],
      aspectWithPoints: ["bodies", "points", "angles"],
      aspectTypes: ["major"],
      language: "en"
    });

    const bodyList = Array.isArray(horoscope?.CelestialBodies?.all) ? horoscope.CelestialBodies.all : [];
    const planets = bodyList
      .filter((body) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"].includes(String(body?.key || "").toLowerCase()))
      .map((body) => ({
        key: body?.label || body?.key || "Planet",
        sign: body?.Sign?.label || "Unknown",
        house: Number(body?.House?.id) || null,
        retrograde: Boolean(body?.isRetrograde)
      }));

    const housesAll = Array.isArray(horoscope?.Houses)
      ? horoscope.Houses.map((house) => ({
          house: Number(house?.id) || null,
          sign: house?.Sign?.label || "Unknown",
          label: house?.label || `House ${house?.id || ""}`.trim()
        }))
      : [];

    const aspectsAll = Array.isArray(horoscope?.Aspects?.all) ? horoscope.Aspects.all : [];
    const aspects = aspectsAll.slice(0, 10).map((aspect) => {
      const p1 = aspect?.point1Label || aspect?.point1Key || "Point";
      const p2 = aspect?.point2Label || aspect?.point2Key || "Point";
      const label = aspect?.label || "Aspect";
      const orb = Number(aspect?.orb);
      const orbLabel = Number.isFinite(orb) ? `${orb.toFixed(2)}°` : "";
      return `${p1} ${label} ${p2}${orbLabel ? ` (orb ${orbLabel})` : ""}.`;
    });

    const core = {
      sun: horoscope?.CelestialBodies?.sun?.Sign?.label || fallbackSun,
      moon: horoscope?.CelestialBodies?.moon?.Sign?.label || fallbackMoon,
      rising: horoscope?.Ascendant?.Sign?.label || fallbackRising
    };

    const dominantHouse = planets
      .filter((planet) => Number.isFinite(planet.house))
      .reduce((acc, planet) => {
        const key = String(planet.house);
        acc[key] = (acc[key] || 0) + 1;
        return acc;
      }, {});
    const dominantHouseId = Number(
      Object.entries(dominantHouse).sort((a, b) => b[1] - a[1])[0]?.[0] || 1
    );
    const houseSign = housesAll.find((house) => house.house === dominantHouseId)?.sign || "Unknown";

    const housesFocus = [
      {
        house: dominantHouseId,
        theme: `House ${dominantHouseId}`,
        meaning: `Primary concentration around house ${dominantHouseId} in ${houseSign}.`
      },
      {
        house: ((dominantHouseId + 3 - 1) % 12) + 1,
        theme: `House ${((dominantHouseId + 3 - 1) % 12) + 1}`,
        meaning: "Secondary growth zone through structural discipline."
      },
      {
        house: ((dominantHouseId + 7 - 1) % 12) + 1,
        theme: `House ${((dominantHouseId + 7 - 1) % 12) + 1}`,
        meaning: "Relational alignment amplifies outcomes."
      }
    ];

    const lifeAreas = {
      relationships: `Venus in ${planets.find((p) => p.key === "Venus")?.sign || "Unknown"} with focus on explicit emotional agreements.`,
      career: `Midheaven in ${horoscope?.Midheaven?.Sign?.label || "Unknown"} favors strategic reputation over short-term bursts.`,
      money: `House 2 in ${housesAll.find((h) => h.house === 2)?.sign || "Unknown"} rewards consistency and measured risk.`,
      energy: `Mars in ${planets.find((p) => p.key === "Mars")?.sign || "Unknown"} indicates best output in structured sprints.`
    };

    return {
      ...base,
      core,
      summary: `${profile.name}, this chart is calculated from ${profile.birthDate} ${profile.birthTime} at (${profile.latitude.toFixed(3)}, ${profile.longitude.toFixed(3)}).`,
      aspects,
      planets,
      housesFocus,
      housesAll,
      lifeAreas,
      growthPlan: [
        "Set one weekly relationship boundary and communicate it early.",
        "Define one measurable career milestone for the next 30 days.",
        "Track energy in fixed blocks and remove one recurring drain."
      ],
      calculation: {
        mode: "astronomical",
        houseSystem: "placidus",
        zodiac: "tropical"
      }
    };
  } catch {
    return base;
  }
}

async function geocodeCity(cityName) {
  const key = String(cityName || "").trim().toLowerCase();
  if (!key) {
    return null;
  }
  if (geoCache.has(key)) {
    return geoCache.get(key);
  }
  const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(
    cityName
  )}&count=1&language=en&format=json`;
  const response = await fetch(url);
  if (!response.ok) {
    return null;
  }
  const payload = await response.json();
  const first = Array.isArray(payload?.results) ? payload.results[0] : null;
  if (!first) {
    return null;
  }
  const latitude = Number(first.latitude);
  const longitude = Number(first.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  const result = {
    latitude,
    longitude,
    timezoneIana: String(first.timezone || "").trim() || null,
    country: String(first.country || "").trim() || null,
    admin1: String(first.admin1 || "").trim() || null,
    resolvedName: String(first.name || "").trim() || cityName
  };
  geoCache.set(key, result);
  return result;
}

async function suggestCities(query, limit = 12) {
  const normalized = String(query || "").trim().toLowerCase();
  if (!normalized || normalized.length < 2) {
    return [];
  }
  const key = `${normalized}:${limit}`;
  if (citySuggestCache.has(key)) {
    return citySuggestCache.get(key);
  }

  const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(
    query
  )}&count=30&language=en&format=json`;
  const response = await fetch(url);
  if (!response.ok) {
    return [];
  }
  const payload = await response.json();
  const results = Array.isArray(payload?.results) ? payload.results : [];
  const filtered = results
    .filter((item) => allowedCityCountryCodes.has(String(item?.country_code || "").toUpperCase()))
    .slice(0, Math.max(1, Math.min(30, Number(limit) || 12)))
    .map((item) => {
      const name = String(item?.name || "").trim();
      const admin1 = String(item?.admin1 || "").trim();
      const country = String(item?.country || "").trim();
      const latitude = Number(item?.latitude);
      const longitude = Number(item?.longitude);
      const timezoneIana = String(item?.timezone || "").trim() || null;
      const parts = [name, admin1, country].filter(Boolean);
      return {
        name,
        admin1,
        country,
        countryCode: String(item?.country_code || "").toUpperCase(),
        latitude: Number.isFinite(latitude) ? latitude : null,
        longitude: Number.isFinite(longitude) ? longitude : null,
        timezoneIana,
        displayName: parts.join(", ")
      };
    });

  citySuggestCache.set(key, filtered);
  if (citySuggestCache.size > 400) {
    const firstKey = citySuggestCache.keys().next().value;
    citySuggestCache.delete(firstKey);
  }
  return filtered;
}

async function ensureProfileCoordinates(profile) {
  if (Number.isFinite(profile.latitude) && Number.isFinite(profile.longitude)) {
    return profile;
  }
  const geo = await geocodeCity(profile.birthCity);
  if (!geo) {
    return profile;
  }
  return {
    ...profile,
    latitude: geo.latitude,
    longitude: geo.longitude,
    timezoneIana: profile.timezoneIana || geo.timezoneIana || null
  };
}

function buildDashboardPayload(sessionData, period = "week") {
  const profile = resolveSessionProfile(null, sessionData);
  if (!profile) {
    return null;
  }

  const now = new Date();
  const dayKey = now.toISOString().slice(0, 10);
  const dateLabel = now.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric"
  });
  const weekday = now.toLocaleDateString("en-US", { weekday: "long" });

  const natalDetail = buildNatalDetail(profile);
  const natalCore = natalDetail?.core || {
    sun: signFromDate(profile.birthDate),
    moon: moonFromDate(profile.birthDate),
    rising: risingFromTime(profile.birthTime)
  };

  const daily = {
    dateLabel,
    focus: "Prioritize one conversation that prevents future misunderstanding.",
    advice: "Before noon, send one clear note: goal, boundary, and next checkpoint.",
    horoscopeToday: `${profile.name}, ${weekday} rewards disciplined pacing and clean boundaries in communication.`
  };

  const periodForecast = buildPeriodForecast(period, profile, now, natalCore);
  const friendsDynamic = (sessionData.friends || []).map((friend) => buildDynamicCompatibility(profile, friend, dayKey, period, natalCore.sun));

  return {
    profile,
    natalCore,
    daily,
    periodForecast,
    friendsDynamic
  };
}

function isAuthenticated(sessionData) {
  return Boolean(sessionData?.auth?.provider === "telegram" && sessionData?.auth?.telegramUserId);
}

function requestUserId(req) {
  if (!authRequired) {
    return "dev-local-user";
  }
  return String(req.sessionData?.auth?.telegramUserId || "").trim();
}

async function requireAuth(req, res, next) {
  try {
    if (authRequired && !isAuthenticated(req.sessionData)) {
      return res.status(401).json({ error: "unauthorized", reason: "auth_required" });
    }
    const userId = requestUserId(req);
    req.userId = userId;
    req.userData = await loadUserData(userId);
    return next();
  } catch (error) {
    return next(error);
  }
}

function mergeSessionIntoUserData(userData, sessionData) {
  const merged = normalizeUserData(userData);
  const sessionProfile = pickProfile({ profile: sessionData?.profile });
  if (sessionProfile && !merged.profile) {
    merged.profile = sessionProfile;
  }
  const sessionFriends = Array.isArray(sessionData?.friends) ? sessionData.friends : [];
  if (sessionFriends.length) {
    const map = new Map();
    [...merged.friends, ...sessionFriends].forEach((friend) => {
      if (!friend?.id) {
        return;
      }
      map.set(String(friend.id), friend);
    });
    merged.friends = Array.from(map.values()).slice(0, 20);
  }
  const sessionDaily = sessionData?.daily;
  if (sessionDaily && typeof sessionDaily === "object") {
    const currentStreak = Number(merged.daily?.streak || 0);
    const nextStreak = Number(sessionDaily.streak || 0);
    if (nextStreak > currentStreak) {
      merged.daily.streak = nextStreak;
    }
    if (String(sessionDaily.lastDayKey || "") > String(merged.daily?.lastDayKey || "")) {
      merged.daily.lastDayKey = String(sessionDaily.lastDayKey || "");
    }
    const history = Array.isArray(merged.daily?.history) ? merged.daily.history : [];
    const incoming = Array.isArray(sessionDaily.history) ? sessionDaily.history : [];
    merged.daily.history = [...incoming, ...history]
      .filter((item, index, arr) => item?.dayKey && arr.findIndex((x) => x.dayKey === item.dayKey) === index)
      .slice(0, 14);
  }
  return merged;
}

function timingSafeEqualHex(a, b) {
  try {
    const bufA = Buffer.from(a, "hex");
    const bufB = Buffer.from(b, "hex");
    return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
  } catch {
    return false;
  }
}

function validateTelegramWidgetAuth(authData, botToken) {
  if (!authData || typeof authData !== "object") {
    return { ok: false, error: "missing_payload" };
  }
  if (!botToken) {
    return { ok: false, error: "missing_bot_token" };
  }

  const hash = String(authData.hash || "").trim();
  const authDate = Number(authData.auth_date);
  if (!hash) {
    return { ok: false, error: "missing_hash" };
  }
  if (!Number.isFinite(authDate) || authDate <= 0) {
    return { ok: false, error: "invalid_auth_date" };
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (nowSeconds - authDate > MAX_TELEGRAM_AUTH_AGE_SECONDS) {
    return { ok: false, error: "expired_auth_date" };
  }

  const pairs = Object.entries(authData)
    .filter(([key, value]) => key !== "hash" && value !== undefined && value !== null && String(value) !== "")
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`);
  const dataCheckString = pairs.join("\n");
  const secretKey = crypto.createHash("sha256").update(botToken).digest();
  const calculatedHash = crypto.createHmac("sha256", secretKey).update(dataCheckString).digest("hex");

  if (!timingSafeEqualHex(hash, calculatedHash)) {
    return { ok: false, error: "invalid_hash" };
  }

  const user = {
    id: Number(authData.id),
    first_name: String(authData.first_name || "").trim(),
    last_name: String(authData.last_name || "").trim(),
    username: String(authData.username || "").trim(),
    photo_url: String(authData.photo_url || "").trim()
  };

  if (!Number.isFinite(user.id) || user.id <= 0) {
    return { ok: false, error: "invalid_user_id" };
  }

  return { ok: true, user };
}

function validateTelegramInitData(initData, botToken) {
  if (!initData || typeof initData !== "string") {
    return { ok: false, error: "missing_init_data" };
  }
  if (!botToken) {
    return { ok: false, error: "missing_bot_token" };
  }
  const params = new URLSearchParams(initData);
  const receivedHash = params.get("hash");
  if (!receivedHash) {
    return { ok: false, error: "missing_hash" };
  }
  const authDateRaw = params.get("auth_date");
  params.delete("hash");
  const dataCheckString = [...params.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");
  const secretKey = crypto.createHmac("sha256", "WebAppData").update(botToken).digest();
  const calculatedHash = crypto.createHmac("sha256", secretKey).update(dataCheckString).digest("hex");

  if (!timingSafeEqualHex(receivedHash, calculatedHash)) {
    return { ok: false, error: "invalid_hash" };
  }

  const authDate = Number(authDateRaw);
  if (!Number.isFinite(authDate) || authDate <= 0) {
    return { ok: false, error: "invalid_auth_date" };
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (nowSeconds - authDate > MAX_TELEGRAM_AUTH_AGE_SECONDS) {
    return { ok: false, error: "expired_auth_date" };
  }

  const userRaw = params.get("user");
  if (!userRaw) {
    return { ok: false, error: "missing_user" };
  }

  try {
    const parsedUser = JSON.parse(userRaw);
    const id = Number(parsedUser?.id);
    if (!Number.isFinite(id) || id <= 0) {
      return { ok: false, error: "invalid_user_id" };
    }
    return {
      ok: true,
      user: {
        id,
        first_name: String(parsedUser?.first_name || "").trim(),
        last_name: String(parsedUser?.last_name || "").trim(),
        username: String(parsedUser?.username || "").trim(),
        photo_url: String(parsedUser?.photo_url || "").trim()
      }
    };
  } catch {
    return { ok: false, error: "invalid_user_payload" };
  }
}

function sanitizeAuthUser(sessionData) {
  const user = sessionData?.auth?.telegramUser;
  if (!user || typeof user !== "object") {
    return null;
  }
  return {
    id: Number(user.id),
    firstName: String(user.first_name || ""),
    lastName: String(user.last_name || ""),
    username: String(user.username || ""),
    photoUrl: String(user.photo_url || "")
  };
}

const contracts = {
  auth: {
    status: "GET /api/auth/status",
    loginWidget: "POST /api/auth/telegram-widget",
    loginInitData: "POST /api/auth/telegram-init-data",
    logout: "POST /api/auth/logout"
  },
  session_profile: {
    get: "GET /api/profile",
    put: "PUT /api/profile",
    response: {
      profile: "nullable profile",
      profileReady: "boolean"
    }
  },
  friends: {
    list: "GET /api/friends",
    create: "POST /api/friends",
    response: {
      friends: [{ id: "string", friendName: "string", friendSign: "string", createdAt: "number" }]
    }
  },
  natal_report: {
    request: { profile: "optional (fallback to session profile)" },
    response: {
      core: { sun: "string", moon: "string", rising: "string" },
      summary: "string",
      blocks: { strength: "string", blindSpot: "string", action: "string" },
      aspects: ["string"],
      planets: [{ key: "string", sign: "string", house: "number", retrograde: "boolean" }],
      housesFocus: [{ house: "number", theme: "string", meaning: "string" }],
      housesAll: [{ house: "number", sign: "string", label: "string" }],
      lifeAreas: {
        relationships: "string",
        career: "string",
        money: "string",
        energy: "string"
      },
      growthPlan: ["string"],
      calculation: {
        mode: "astronomical|fallback",
        houseSystem: "string",
        zodiac: "string"
      }
    }
  },
  daily_insight: {
    request: { profile: "optional (fallback to session profile)" },
    response: {
      dateLabel: "string",
      intro: "string",
      focus: "string",
      risk: "string",
      step: "string",
      streakLabel: "string",
      streak: "number",
      history: [{ dayKey: "YYYY-MM-DD", focus: "string", step: "string" }]
    }
  },
  compatibility_report: {
    request: {
      profile: "optional profile",
      friend: {
        friendName: "string",
        friendSign: "string"
      }
    },
    response: {
      score: "number",
      highlights: ["string"],
      advice: "string"
    }
  },
  dashboard: {
    get: "GET /api/dashboard?period=week|month|year",
    response: {
      profile: "profile",
      natalCore: { sun: "string", moon: "string", rising: "string" },
      daily: {
        dateLabel: "string",
        focus: "string",
        advice: "string",
        horoscopeToday: "string"
      },
      periodForecast: {
        period: "week|month|year",
        intensity: "number",
        summary: "string"
      },
      friendsDynamic: [
        {
          id: "string",
          friendName: "string",
          friendSign: "string",
          score: "number",
          trend: "high|stable|fragile",
          note: "string"
        }
      ]
    }
  }
};

app.use(express.json({ limit: "256kb" }));
app.use(async (req, res, next) => {
  try {
    const session = await getOrCreateSession(req, res);
    req.sessionId = session.sid;
    req.sessionData = normalizeSessionData(session.data);
    next();
  } catch (error) {
    next(error);
  }
});
app.use(
  express.static(publicDir, {
    setHeaders: (res, filePath) => {
      if (filePath.endsWith("index.html")) {
        res.setHeader("Cache-Control", "no-store");
        return;
      }
      res.setHeader("Cache-Control", "public, max-age=300");
    }
  })
);

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "astro-web", dbEnabled: Boolean(dbPool), authRequired });
});

app.get("/api/contracts", (_req, res) => {
  res.json({ ok: true, contracts, dbEnabled: Boolean(dbPool), authRequired });
});

app.get("/api/auth/status", (req, res) => {
  const authenticated = isAuthenticated(req.sessionData);
  res.json({
    ok: true,
    authRequired,
    authenticated,
    provider: authenticated ? "telegram" : null,
    user: authenticated ? sanitizeAuthUser(req.sessionData) : null,
    telegramLoginEnabled: Boolean(telegramBotToken && telegramBotUsername),
    telegramBotUsername: telegramBotUsername || null,
    telegramBotId
  });
});

app.post("/api/auth/telegram-widget", async (req, res) => {
  const validation = validateTelegramWidgetAuth(req.body?.telegramAuth, telegramBotToken);
  if (!validation.ok) {
    return res.status(401).json({ error: "unauthorized", reason: validation.error });
  }

  req.sessionData.auth = {
    provider: "telegram",
    telegramUserId: String(validation.user.id),
    telegramUser: validation.user,
    authenticatedAt: Date.now(),
    via: "widget"
  };
  await persistSession(req.sessionId, req.sessionData);
  const userId = String(validation.user.id);
  const userData = await loadUserData(userId);
  const mergedUserData = mergeSessionIntoUserData(userData, req.sessionData);
  await saveUserData(userId, mergedUserData);

  return res.json({ ok: true, authenticated: true, user: sanitizeAuthUser(req.sessionData) });
});

app.post("/api/auth/telegram-init-data", async (req, res) => {
  const initData = String(req.body?.initData || "").trim();
  const validation = validateTelegramInitData(initData, telegramBotToken);
  if (!validation.ok) {
    return res.status(401).json({ error: "unauthorized", reason: validation.error });
  }

  req.sessionData.auth = {
    provider: "telegram",
    telegramUserId: String(validation.user.id),
    telegramUser: validation.user,
    authenticatedAt: Date.now(),
    via: "webapp"
  };
  await persistSession(req.sessionId, req.sessionData);
  const userId = String(validation.user.id);
  const userData = await loadUserData(userId);
  const mergedUserData = mergeSessionIntoUserData(userData, req.sessionData);
  await saveUserData(userId, mergedUserData);

  return res.json({ ok: true, authenticated: true, user: sanitizeAuthUser(req.sessionData) });
});

app.post("/api/auth/logout", async (req, res) => {
  const oldSid = req.sessionId;
  const sid = crypto.randomUUID();
  const freshSession = defaultSessionData();
  await persistSession(sid, freshSession);
  await deleteSessionBySid(oldSid);
  res.setHeader("Set-Cookie", buildSessionCookie(sid, req));
  res.json({ ok: true, authenticated: false });
});

app.get("/api/profile", requireAuth, (req, res) => {
  const profile = pickProfile({ profile: req.userData.profile });
  res.json({ ok: true, profile, profileReady: Boolean(profile) });
});

app.get("/api/cities", requireAuth, async (req, res) => {
  const query = String(req.query?.query || "").trim();
  const limit = Math.max(1, Math.min(20, Number(req.query?.limit) || 12));
  if (!query || query.length < 2) {
    return res.json({ ok: true, cities: [] });
  }
  try {
    const cities = await suggestCities(query, limit);
    return res.json({ ok: true, cities });
  } catch {
    return res.json({ ok: true, cities: [] });
  }
});

app.put("/api/profile", requireAuth, async (req, res) => {
  const rawProfile = pickProfile(req.body);
  if (!rawProfile) {
    return res.status(400).json({
      error: "invalid_profile",
      message: "name, birthDate, birthTime and birthCity are required"
    });
  }
  const profile = await ensureProfileCoordinates(rawProfile);
  req.userData.profile = profile;
  await saveUserData(req.userId, req.userData);
  return res.json({ ok: true, profile, profileReady: true });
});

app.get("/api/friends", requireAuth, (req, res) => {
  res.json({ ok: true, friends: req.userData.friends || [] });
});

app.post("/api/friends", requireAuth, async (req, res) => {
  const friendName = String(req.body?.friendName || "").trim();
  const friendSign = String(req.body?.friendSign || "").trim();
  if (!friendName || !friendSign) {
    return res.status(400).json({
      error: "invalid_friend",
      message: "friendName and friendSign are required"
    });
  }
  const friend = {
    id: crypto.randomUUID(),
    friendName,
    friendSign,
    createdAt: Date.now()
  };
  req.userData.friends = [friend, ...(req.userData.friends || [])].slice(0, 20);
  await saveUserData(req.userId, req.userData);
  return res.json({ ok: true, friend, friends: req.userData.friends });
});

app.post("/api/natal-report", requireAuth, (req, res) => {
  const profile = resolveSessionProfile(req.body?.profile, req.userData);
  if (!profile) {
    return res.status(400).json({ error: "invalid_profile", message: "profile is required" });
  }

  return res.json(buildNatalDetail(profile));
});

app.post("/api/daily-insight", requireAuth, async (req, res) => {
  const profile = resolveSessionProfile(req.body?.profile, req.userData);
  if (!profile) {
    return res.status(400).json({
      error: "invalid_profile",
      message: "profile is required for daily insight"
    });
  }

  const now = new Date();
  const dayKey = now.toISOString().slice(0, 10);
  const weekday = now.toLocaleDateString("en-US", { weekday: "long" });
  const dateLabel = now.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric"
  });

  const sessionDaily = req.userData.daily || { streak: 0, lastDayKey: "", history: [] };
  if (sessionDaily.lastDayKey !== dayKey) {
    const previous = sessionDaily.lastDayKey ? new Date(`${sessionDaily.lastDayKey}T00:00:00Z`) : null;
    const current = new Date(`${dayKey}T00:00:00Z`);
    const gapDays = previous ? Math.round((current - previous) / 86400000) : 0;
    sessionDaily.streak = gapDays === 1 ? sessionDaily.streak + 1 : 1;
    sessionDaily.lastDayKey = dayKey;
  }

  const focus = "Prioritize one conversation that prevents future misunderstanding.";
  const risk = "Reactive messaging can escalate small ambiguity into unnecessary conflict.";
  const step = "Before noon, send one clear note: goal, boundary, and next checkpoint.";

  pushDailyHistory(sessionDaily, { dayKey, focus, step });
  req.userData.daily = sessionDaily;
  await saveUserData(req.userId, req.userData);

  return res.json({
    dateLabel,
    intro: `${profile.name}, ${weekday} works best when you reduce context switching and protect one strategic block of deep work.`,
    focus,
    risk,
    step,
    streak: sessionDaily.streak,
    streakLabel: `Current streak: ${sessionDaily.streak} day${sessionDaily.streak === 1 ? "" : "s"}.`,
    history: sessionDaily.history
  });
});

app.post("/api/compatibility-report", requireAuth, (req, res) => {
  const friend = req.body?.friend;
  const friendName = String(friend?.friendName || "").trim();
  const friendSign = String(friend?.friendSign || "").trim();

  if (!friendName || !friendSign) {
    return res.status(400).json({
      error: "invalid_friend",
      message: "friendName and friendSign are required"
    });
  }

  const profile = resolveSessionProfile(req.body?.profile, req.userData);
  const natal = profile ? buildNatalDetail(profile) : null;
  const userSign = natal?.core?.sun || (profile ? signFromDate(profile.birthDate) : "Unknown");
  const dayKey = new Date().toISOString().slice(0, 10);
  const detail = buildCompatibilityDetail({
    userSign,
    friendSign,
    friendName,
    dayKey,
    period: "week",
    seedKey: friendName
  });

  return res.json({
    ...detail
  });
});

app.get("/api/dashboard", requireAuth, (req, res) => {
  const requestedPeriod = String(req.query?.period || "week").trim().toLowerCase();
  const period = ["week", "month", "year"].includes(requestedPeriod) ? requestedPeriod : "week";
  const payload = buildDashboardPayload(req.userData, period);
  if (!payload) {
    return res.status(400).json({ error: "profile_required", message: "Complete profile first." });
  }
  return res.json({ ok: true, dashboard: payload });
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(publicDir, "index.html"));
});

app.use((error, req, res, next) => {
  if (res.headersSent) {
    return next(error);
  }
  console.error("astro-web error", error);
  if (String(req.path || "").startsWith("/api/")) {
    return res.status(500).json({ error: "internal_error" });
  }
  return res.status(500).send("Internal Server Error");
});

initDb()
  .then(() => {
    if (dbPool) {
      console.log("astro-web db enabled");
    } else {
      console.log("astro-web db disabled (DATABASE_URL missing)");
    }
    console.log(`astro-web authRequired=${authRequired}`);
    app.listen(port, "0.0.0.0", () => {
      console.log(`astro-web listening on :${port}`);
    });
  })
  .catch((error) => {
    console.error("Failed to initialize astro-web", error);
    process.exit(1);
  });
