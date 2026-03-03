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
const appBaseUrlEnvRaw = String(process.env.APP_BASE_URL || "").trim();
const googleClientId = String(process.env.GOOGLE_CLIENT_ID || "").trim();
const googleClientSecret = String(process.env.GOOGLE_CLIENT_SECRET || "").trim();
const githubClientId = String(process.env.GITHUB_CLIENT_ID || "").trim();
const githubClientSecret = String(process.env.GITHUB_CLIENT_SECRET || "").trim();
const googleLoginEnabled = Boolean(googleClientId && googleClientSecret);
const githubLoginEnabled = Boolean(githubClientId && githubClientSecret);
const authRequired =
  String(process.env.AUTH_REQUIRED || "").trim() === "1" ||
  String(process.env.AUTH_REQUIRED || "").trim().toLowerCase() === "true" ||
  Boolean(telegramBotToken || googleLoginEnabled || githubLoginEnabled);
const MAX_TELEGRAM_AUTH_AGE_SECONDS = 60 * 60 * 24;
const MAX_OAUTH_STATE_AGE_MS = 10 * 60 * 1000;

function normalizeBaseUrl(raw) {
  const value = String(raw || "").trim();
  if (!value) {
    return "";
  }
  const withScheme = /^https?:\/\//i.test(value) ? value : `https://${value}`;
  try {
    const parsed = new URL(withScheme);
    return `${parsed.protocol}//${parsed.host}`;
  } catch {
    return "";
  }
}

const appBaseUrlEnv = normalizeBaseUrl(appBaseUrlEnvRaw);

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

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

const historicalCelebrities = [
  { sign: "Aries", name: "Leonardo da Vinci", birthDate: "1452-04-15", birthTime: "22:30", birthCity: "Vinci, Italy", field: "Art / Science", years: "1452-1519", fact: "Renaissance polymath whose notebooks linked artistic anatomy with engineering systems." },
  { sign: "Aries", name: "Vincent van Gogh", birthDate: "1853-03-30", birthTime: "11:00", birthCity: "Zundert, Netherlands", field: "Art", years: "1853-1890", fact: "Post-Impressionist painter whose color language reshaped modern visual expression." },
  { sign: "Aries", name: "Charlie Chaplin", birthDate: "1889-04-16", birthTime: "20:00", birthCity: "London, England", field: "Film", years: "1889-1977", fact: "Created one of cinema's most enduring characters while building a global studio legacy." },
  { sign: "Aries", name: "Francisco Goya", birthDate: "1746-03-30", birthTime: "10:00", birthCity: "Fuendetodos, Spain", field: "Art", years: "1746-1828", fact: "Painter-printmaker whose work bridged court portraiture and modern political critique." },
  { sign: "Aries", name: "Johann Sebastian Bach", birthDate: "1685-03-31", birthTime: "08:00", birthCity: "Eisenach, Germany", field: "Music", years: "1685-1750", fact: "Composer whose harmonic architecture became a foundation for Western music training." },

  { sign: "Taurus", name: "William Shakespeare", birthDate: "1564-04-23", birthTime: "03:00", birthCity: "Stratford-upon-Avon, England", field: "Literature / Theatre", years: "1564-1616", fact: "Playwright whose language and character psychology still shape global storytelling." },
  { sign: "Taurus", name: "Karl Marx", birthDate: "1818-05-05", birthTime: "02:00", birthCity: "Trier, Germany", field: "Philosophy / Economics", years: "1818-1883", fact: "Political economist whose critique of industrial systems influenced modern social theory." },
  { sign: "Taurus", name: "Sigmund Freud", birthDate: "1856-05-06", birthTime: "18:30", birthCity: "Pribor, Czechia", field: "Psychology", years: "1856-1939", fact: "Founded psychoanalysis and introduced enduring models of motive and unconscious process." },
  { sign: "Taurus", name: "Salvador Dali", birthDate: "1904-05-11", birthTime: "08:45", birthCity: "Figueres, Spain", field: "Art", years: "1904-1989", fact: "Surrealist icon who fused theatrical self-branding with technical draftsmanship." },
  { sign: "Taurus", name: "Audrey Hepburn", birthDate: "1929-05-04", birthTime: "03:00", birthCity: "Brussels, Belgium", field: "Film / Humanitarian", years: "1929-1993", fact: "Actor and UNICEF ambassador recognized for both screen craft and global advocacy." },

  { sign: "Gemini", name: "Marilyn Monroe", birthDate: "1926-06-01", birthTime: "09:30", birthCity: "Los Angeles, California, USA", field: "Film", years: "1926-1962", fact: "Built one of the most recognizable media personas in twentieth-century cinema." },
  { sign: "Gemini", name: "John F. Kennedy", birthDate: "1917-05-29", birthTime: "15:00", birthCity: "Brookline, Massachusetts, USA", field: "Politics", years: "1917-1963", fact: "US president associated with Cold War crisis management and moonshot-era ambition." },
  { sign: "Gemini", name: "Federico Garcia Lorca", birthDate: "1898-06-05", birthTime: "06:00", birthCity: "Fuente Vaqueros, Spain", field: "Poetry / Theatre", years: "1898-1936", fact: "Poet-dramatist whose symbolic language transformed modern Spanish literature." },
  { sign: "Gemini", name: "Allen Ginsberg", birthDate: "1926-06-03", birthTime: "18:03", birthCity: "Newark, New Jersey, USA", field: "Poetry", years: "1926-1997", fact: "Beat poet who challenged postwar conformity through radical literary voice." },
  { sign: "Gemini", name: "Paul Gauguin", birthDate: "1848-06-07", birthTime: "06:00", birthCity: "Paris, France", field: "Art", years: "1848-1903", fact: "Painter who helped transition European art toward symbolic and modernist form." },

  { sign: "Cancer", name: "Frida Kahlo", birthDate: "1907-07-06", birthTime: "08:30", birthCity: "Coyoacan, Mexico", field: "Art", years: "1907-1954", fact: "Artist known for autobiographical symbolism and cross-cultural visual identity." },
  { sign: "Cancer", name: "Ernest Hemingway", birthDate: "1899-07-21", birthTime: "08:00", birthCity: "Oak Park, Illinois, USA", field: "Literature", years: "1899-1961", fact: "Nobel-winning novelist whose concise prose model influenced modern fiction." },
  { sign: "Cancer", name: "Nikola Tesla", birthDate: "1856-07-10", birthTime: "00:00", birthCity: "Smiljan, Croatia", field: "Engineering / Physics", years: "1856-1943", fact: "Inventor whose AC power systems became the backbone of modern electricity grids." },
  { sign: "Cancer", name: "Franz Kafka", birthDate: "1883-07-03", birthTime: "03:00", birthCity: "Prague, Czechia", field: "Literature", years: "1883-1924", fact: "Writer whose existential bureaucratic themes entered global political vocabulary." },
  { sign: "Cancer", name: "Gustav Mahler", birthDate: "1860-07-07", birthTime: "07:30", birthCity: "Kalischte, Czechia", field: "Music", years: "1860-1911", fact: "Composer-conductor who expanded symphonic scale and emotional orchestral narrative." },

  { sign: "Leo", name: "Napoleon Bonaparte", birthDate: "1769-08-15", birthTime: "11:30", birthCity: "Ajaccio, France", field: "Politics / Military", years: "1769-1821", fact: "State-builder and strategist whose legal reforms outlived imperial collapse." },
  { sign: "Leo", name: "Alfred Hitchcock", birthDate: "1899-08-13", birthTime: "13:20", birthCity: "London, England", field: "Film", years: "1899-1980", fact: "Director who operationalized suspense as a repeatable cinematic system." },
  { sign: "Leo", name: "Coco Chanel", birthDate: "1883-08-19", birthTime: "06:00", birthCity: "Saumur, France", field: "Fashion", years: "1883-1971", fact: "Designer who transformed luxury fashion into modern minimalist codes." },
  { sign: "Leo", name: "Benito Mussolini", birthDate: "1883-07-29", birthTime: "14:00", birthCity: "Predappio, Italy", field: "Politics", years: "1883-1945", fact: "Italian political leader whose regime became a key case in twentieth-century authoritarian history." },
  { sign: "Leo", name: "Alexander Fleming", birthDate: "1881-08-06", birthTime: "20:00", birthCity: "Lochfield, Scotland", field: "Medicine", years: "1881-1955", fact: "Discovered penicillin, catalyzing the antibiotic era in clinical medicine." },

  { sign: "Virgo", name: "Leo Tolstoy", birthDate: "1828-09-09", birthTime: "01:00", birthCity: "Yasnaya Polyana, Russia", field: "Literature", years: "1828-1910", fact: "Novelist whose social-scale narratives redefined psychological realism." },
  { sign: "Virgo", name: "Johann Wolfgang von Goethe", birthDate: "1749-08-28", birthTime: "12:00", birthCity: "Frankfurt, Germany", field: "Literature / Science", years: "1749-1832", fact: "Writer-scientist whose work bridged poetry, philosophy, and natural inquiry." },
  { sign: "Virgo", name: "Freddie Mercury", birthDate: "1946-09-05", birthTime: "08:45", birthCity: "Stone Town, Tanzania", field: "Music", years: "1946-1991", fact: "Frontman whose vocal range and stage architecture transformed arena performance." },
  { sign: "Virgo", name: "Agatha Christie", birthDate: "1890-09-15", birthTime: "04:00", birthCity: "Torquay, England", field: "Literature", years: "1890-1976", fact: "Detective novelist whose plotting structures became a genre benchmark." },
  { sign: "Virgo", name: "Queen Elizabeth I", birthDate: "1533-09-07", birthTime: "15:00", birthCity: "Greenwich, England", field: "Monarchy / Statecraft", years: "1533-1603", fact: "Monarch associated with administrative consolidation and cultural expansion." },

  { sign: "Libra", name: "Mahatma Gandhi", birthDate: "1869-10-02", birthTime: "07:11", birthCity: "Porbandar, India", field: "Political Ethics", years: "1869-1948", fact: "Led nonviolent mass mobilization and influenced civil resistance worldwide." },
  { sign: "Libra", name: "Oscar Wilde", birthDate: "1854-10-16", birthTime: "03:00", birthCity: "Dublin, Ireland", field: "Literature", years: "1854-1900", fact: "Playwright and critic whose wit and social satire endure in modern theatre." },
  { sign: "Libra", name: "Friedrich Nietzsche", birthDate: "1844-10-15", birthTime: "10:00", birthCity: "Rocken, Germany", field: "Philosophy", years: "1844-1900", fact: "Philosopher who challenged moral absolutism and influenced modern thought." },
  { sign: "Libra", name: "Eleanor Roosevelt", birthDate: "1884-10-11", birthTime: "11:00", birthCity: "New York City, USA", field: "Diplomacy / Human Rights", years: "1884-1962", fact: "UN delegate and public intellectual central to modern human-rights discourse." },
  { sign: "Libra", name: "Dmitri Shostakovich", birthDate: "1906-09-25", birthTime: "13:00", birthCity: "Saint Petersburg, Russia", field: "Music", years: "1906-1975", fact: "Composer whose symphonies encoded political tension and artistic resistance." },

  { sign: "Scorpio", name: "Marie Curie", birthDate: "1867-11-07", birthTime: "23:30", birthCity: "Warsaw, Poland", field: "Science", years: "1867-1934", fact: "Double Nobel laureate whose radioactivity research changed physics and medicine." },
  { sign: "Scorpio", name: "Fyodor Dostoevsky", birthDate: "1821-11-11", birthTime: "13:00", birthCity: "Moscow, Russia", field: "Literature", years: "1821-1881", fact: "Novelist of moral conflict whose characters shaped modern psychological fiction." },
  { sign: "Scorpio", name: "Pablo Picasso", birthDate: "1881-10-25", birthTime: "23:15", birthCity: "Malaga, Spain", field: "Art", years: "1881-1973", fact: "Painter and sculptor whose formal experimentation transformed modern art." },
  { sign: "Scorpio", name: "Indira Gandhi", birthDate: "1917-11-19", birthTime: "23:11", birthCity: "Allahabad, India", field: "Politics", years: "1917-1984", fact: "Indian prime minister known for centralized power and major geopolitical decisions." },
  { sign: "Scorpio", name: "George Eliot", birthDate: "1819-11-22", birthTime: "05:30", birthCity: "Nuneaton, England", field: "Literature", years: "1819-1880", fact: "Novelist whose social realism and moral complexity expanded the English novel." },

  { sign: "Sagittarius", name: "Ludwig van Beethoven", birthDate: "1770-12-16", birthTime: "06:00", birthCity: "Bonn, Germany", field: "Music", years: "1770-1827", fact: "Composer who pushed classical form toward romantic-scale emotional narrative." },
  { sign: "Sagittarius", name: "Winston Churchill", birthDate: "1874-11-30", birthTime: "01:30", birthCity: "Woodstock, England", field: "Politics", years: "1874-1965", fact: "British wartime leader whose rhetoric shaped alliance-era morale." },
  { sign: "Sagittarius", name: "Mark Twain", birthDate: "1835-11-30", birthTime: "00:30", birthCity: "Florida, Missouri, USA", field: "Literature", years: "1835-1910", fact: "American satirist whose vernacular style redefined literary voice." },
  { sign: "Sagittarius", name: "Walt Disney", birthDate: "1901-12-05", birthTime: "00:35", birthCity: "Chicago, Illinois, USA", field: "Animation / Media", years: "1901-1966", fact: "Built studio systems that industrialized character-driven storytelling." },
  { sign: "Sagittarius", name: "Jane Austen", birthDate: "1775-12-16", birthTime: "11:00", birthCity: "Steventon, England", field: "Literature", years: "1775-1817", fact: "Novelist whose social observation and irony remain core to English prose." },

  { sign: "Capricorn", name: "Isaac Newton", birthDate: "1643-01-04", birthTime: "01:45", birthCity: "Woolsthorpe, England", field: "Physics / Mathematics", years: "1643-1727", fact: "Formulated classical mechanics and calculus frameworks central to science." },
  { sign: "Capricorn", name: "Martin Luther King Jr.", birthDate: "1929-01-15", birthTime: "12:00", birthCity: "Atlanta, Georgia, USA", field: "Civil Rights", years: "1929-1968", fact: "Civil-rights leader whose nonviolent strategy transformed US law and culture." },
  { sign: "Capricorn", name: "Elvis Presley", birthDate: "1935-01-08", birthTime: "04:35", birthCity: "Tupelo, Mississippi, USA", field: "Music", years: "1935-1977", fact: "Recording artist who scaled rock-and-roll into mass global culture." },
  { sign: "Capricorn", name: "Edgar Allan Poe", birthDate: "1809-01-19", birthTime: "01:00", birthCity: "Boston, Massachusetts, USA", field: "Literature", years: "1809-1849", fact: "Writer whose horror and detective structures influenced modern genre fiction." },
  { sign: "Capricorn", name: "Simone de Beauvoir", birthDate: "1908-01-09", birthTime: "04:30", birthCity: "Paris, France", field: "Philosophy / Literature", years: "1908-1986", fact: "Existentialist thinker whose feminist analysis reshaped modern social theory." },

  { sign: "Aquarius", name: "Charles Darwin", birthDate: "1809-02-12", birthTime: "03:00", birthCity: "Shrewsbury, England", field: "Science", years: "1809-1882", fact: "Naturalist whose evolutionary model changed biology and modern worldview." },
  { sign: "Aquarius", name: "Thomas Edison", birthDate: "1847-02-11", birthTime: "02:57", birthCity: "Milan, Ohio, USA", field: "Engineering / Industry", years: "1847-1931", fact: "Inventor-entrepreneur who scaled industrial R&D and electrical productization." },
  { sign: "Aquarius", name: "Abraham Lincoln", birthDate: "1809-02-12", birthTime: "06:54", birthCity: "Hodgenville, Kentucky, USA", field: "Politics", years: "1809-1865", fact: "US president who led during Civil War and ended chattel slavery." },
  { sign: "Aquarius", name: "Jules Verne", birthDate: "1828-02-08", birthTime: "12:00", birthCity: "Nantes, France", field: "Literature", years: "1828-1905", fact: "Novelist whose speculative adventures anticipated modern science fiction motifs." },
  { sign: "Aquarius", name: "Galileo Galilei", birthDate: "1564-02-15", birthTime: "15:00", birthCity: "Pisa, Italy", field: "Astronomy / Physics", years: "1564-1642", fact: "Astronomer whose observations accelerated the scientific revolution." },

  { sign: "Pisces", name: "Albert Einstein", birthDate: "1879-03-14", birthTime: "11:30", birthCity: "Ulm, Germany", field: "Physics", years: "1879-1955", fact: "Physicist whose relativity framework changed modern space-time models." },
  { sign: "Pisces", name: "Michelangelo", birthDate: "1475-03-06", birthTime: "04:00", birthCity: "Caprese, Italy", field: "Art / Architecture", years: "1475-1564", fact: "Renaissance master across sculpture, painting, and monumental design." },
  { sign: "Pisces", name: "Frederic Chopin", birthDate: "1810-03-01", birthTime: "18:00", birthCity: "Zelazowa Wola, Poland", field: "Music", years: "1810-1849", fact: "Composer-pianist whose harmonic nuance transformed piano repertoire." },
  { sign: "Pisces", name: "Victor Hugo", birthDate: "1802-02-26", birthTime: "22:00", birthCity: "Besancon, France", field: "Literature", years: "1802-1885", fact: "French writer and statesman whose novels shaped European social imagination." },
  { sign: "Pisces", name: "Rudolf Steiner", birthDate: "1861-02-27", birthTime: "23:15", birthCity: "Donji Kraljevec, Croatia", field: "Philosophy / Education", years: "1861-1925", fact: "Public intellectual whose lectures influenced education, agriculture, and alternative medicine movements." }
].map((item) => ({
  id: slugify(`${item.name}-${item.birthDate}`),
  ...item
}));

const historicalCelebritiesById = new Map(historicalCelebrities.map((item) => [item.id, item]));

function defaultSessionData() {
  return {
    createdAt: Date.now(),
    auth: null,
    oauthFlow: null,
    referralContext: null,
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
    firstSeenAt: Date.now(),
    metrics: {
      invitesSent: 0,
      invitedRegistrations: 0
    },
    referral: {
      code: "",
      referredByCode: "",
      referredByUserKey: "",
      shareBirthDataConsent: true,
      socialConnectionCompleted: false
    },
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
  const metricsSource = source.metrics && typeof source.metrics === "object" ? source.metrics : {};
  const referralSource = source.referral && typeof source.referral === "object" ? source.referral : {};
  return {
    firstSeenAt: Number.isFinite(Number(source.firstSeenAt)) ? Number(source.firstSeenAt) : Date.now(),
    metrics: {
      invitesSent: Number.isFinite(Number(metricsSource.invitesSent)) ? Number(metricsSource.invitesSent) : 0,
      invitedRegistrations: Number.isFinite(Number(metricsSource.invitedRegistrations)) ? Number(metricsSource.invitedRegistrations) : 0
    },
    referral: {
      code: String(referralSource.code || ""),
      referredByCode: String(referralSource.referredByCode || ""),
      referredByUserKey: String(referralSource.referredByUserKey || ""),
      shareBirthDataConsent: referralSource.shareBirthDataConsent !== false,
      socialConnectionCompleted: toBoolean(referralSource.socialConnectionCompleted)
    },
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
  const oauthFlowSource = source.oauthFlow && typeof source.oauthFlow === "object" ? source.oauthFlow : null;
  const referralContextSource = source.referralContext && typeof source.referralContext === "object" ? source.referralContext : null;

  const auth = authSource
    ? {
        provider: String(authSource.provider || ""),
        userKey: String(
          authSource.userKey
          || (authSource.provider && authSource.externalUserId ? `${authSource.provider}:${authSource.externalUserId}` : "")
          || (authSource.provider === "telegram" && authSource.telegramUserId ? `telegram:${authSource.telegramUserId}` : "")
        ),
        externalUserId: String(authSource.externalUserId || authSource.telegramUserId || ""),
        telegramUserId: String(authSource.telegramUserId || ""),
        user:
          authSource.user && typeof authSource.user === "object"
            ? authSource.user
            : null,
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
  const oauthFlow = oauthFlowSource
    ? {
        provider: String(oauthFlowSource.provider || ""),
        state: String(oauthFlowSource.state || ""),
        createdAt: Number.isFinite(Number(oauthFlowSource.createdAt)) ? Number(oauthFlowSource.createdAt) : Date.now(),
        returnTo: String(oauthFlowSource.returnTo || "/")
      }
    : null;
  const referralContext = referralContextSource
    ? {
        code: String(referralContextSource.code || "").toUpperCase().trim(),
        shareBirthDataConsent: referralContextSource.shareBirthDataConsent !== false,
        capturedAt: Number.isFinite(Number(referralContextSource.capturedAt)) ? Number(referralContextSource.capturedAt) : Date.now()
      }
    : null;

  return {
    createdAt: Number.isFinite(Number(source.createdAt)) ? Number(source.createdAt) : Date.now(),
    auth,
    oauthFlow,
    referralContext,
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

async function deleteUserData(telegramUserId) {
  if (!telegramUserId) {
    return;
  }
  if (dbPool) {
    await dbPool.query("DELETE FROM astro_web_user_state WHERE telegram_user_id = $1", [telegramUserId]);
    return;
  }
  userStore.delete(telegramUserId);
}

function generateReferralCode(userKey) {
  const digest = crypto.createHash("sha1").update(String(userKey || "").trim()).digest("hex").toUpperCase();
  return `ASTRO-${digest.slice(0, 8)}`;
}

async function findUserKeyByReferralCode(code) {
  const normalizedCode = String(code || "").toUpperCase().trim();
  if (!normalizedCode) {
    return "";
  }
  if (dbPool) {
    const result = await dbPool.query(
      `SELECT telegram_user_id FROM astro_web_user_state WHERE UPPER(COALESCE(data->'referral'->>'code', '')) = $1 LIMIT 1`,
      [normalizedCode]
    );
    if (result.rowCount) {
      return String(result.rows[0].telegram_user_id || "");
    }
    return "";
  }
  for (const [userKey, raw] of userStore.entries()) {
    const data = normalizeUserData(raw);
    if (String(data?.referral?.code || "").toUpperCase() === normalizedCode) {
      return String(userKey || "");
    }
  }
  return "";
}

async function buildFriendRecordFromProfile(profile, fallbackName = "Friend", sourceUserKey = "") {
  if (!profile || typeof profile !== "object") {
    return null;
  }
  const friendName = String(profile.name || fallbackName).trim() || fallbackName;
  const friendBirthDate = String(profile.birthDate || "").trim();
  const friendBirthTime = String(profile.birthTime || "").trim();
  const friendBirthCity = String(profile.birthCity || "").trim();
  if (!friendBirthDate) {
    return null;
  }
  const natalMini = await buildFriendNatalMini({
    friendName,
    friendBirthDate,
    friendBirthTime,
    friendBirthCity
  });
  return {
    id: crypto.randomUUID(),
    sourceUserKey: String(sourceUserKey || "").trim() || null,
    friendName,
    friendBirthDate,
    friendBirthTime: friendBirthTime || null,
    friendBirthCity: friendBirthCity || null,
    friendSign: natalMini?.core?.sun || signFromDate(friendBirthDate),
    friendTelegram: "",
    friendEmail: "",
    noShareData: false,
    natalMini,
    createdAt: Date.now()
  };
}

async function ensureMutualFriendLink(userAKey, userAData, userBKey, userBData) {
  if (!userAKey || !userBKey || userAKey === userBKey) {
    return;
  }
  const a = normalizeUserData(userAData);
  const b = normalizeUserData(userBData);
  const aName = String(a?.profile?.name || "").trim();
  const bName = String(b?.profile?.name || "").trim();
  if (!a.profile || !b.profile || !aName || !bName) {
    return;
  }
  const aHasB = (a.friends || []).some((friend) => String(friend?.friendName || "").trim() === bName);
  const bHasA = (b.friends || []).some((friend) => String(friend?.friendName || "").trim() === aName);

  if (!aHasB) {
    const friendB = await buildFriendRecordFromProfile(b.profile, bName, userBKey);
    if (friendB) {
      a.friends = [friendB, ...(a.friends || [])].slice(0, 50);
    }
  }
  if (!bHasA) {
    const friendA = await buildFriendRecordFromProfile(a.profile, aName, userAKey);
    if (friendA) {
      b.friends = [friendA, ...(b.friends || [])].slice(0, 50);
    }
  }
  await saveUserData(userAKey, a);
  await saveUserData(userBKey, b);
}

async function listAllUserStateEntries() {
  if (dbPool) {
    const result = await dbPool.query("SELECT telegram_user_id, data FROM astro_web_user_state");
    return (result.rows || []).map((row) => ({
      userKey: String(row.telegram_user_id || "").trim(),
      data: normalizeUserData(row.data)
    })).filter((entry) => entry.userKey);
  }
  return Array.from(userStore.entries()).map(([userKey, raw]) => ({
    userKey: String(userKey || "").trim(),
    data: normalizeUserData(raw)
  })).filter((entry) => entry.userKey);
}

function shouldRemoveFriendLink(friend, deletedUserKey, deletedName, deletedBirthDate) {
  if (!friend || typeof friend !== "object") {
    return false;
  }
  const sourceUserKey = String(friend?.sourceUserKey || "").trim();
  if (sourceUserKey && sourceUserKey === deletedUserKey) {
    return true;
  }
  const friendName = String(friend?.friendName || "").trim().toLowerCase();
  const friendBirthDate = String(friend?.friendBirthDate || "").trim();
  if (!deletedName || friendName !== deletedName) {
    return false;
  }
  if (!deletedBirthDate || !friendBirthDate) {
    return true;
  }
  return friendBirthDate === deletedBirthDate;
}

async function removeDeletedUserFromSocialGraph(deletedUserKey, deletedUserData) {
  const userKey = String(deletedUserKey || "").trim();
  if (!userKey) {
    return;
  }
  const profile = deletedUserData?.profile && typeof deletedUserData.profile === "object"
    ? deletedUserData.profile
    : null;
  const deletedName = String(profile?.name || "").trim().toLowerCase();
  const deletedBirthDate = String(profile?.birthDate || "").trim();
  const allUsers = await listAllUserStateEntries();
  for (const entry of allUsers) {
    if (!entry.userKey || entry.userKey === userKey) {
      continue;
    }
    const data = normalizeUserData(entry.data);
    const friends = Array.isArray(data.friends) ? data.friends : [];
    const nextFriends = friends.filter((friend) => !shouldRemoveFriendLink(friend, userKey, deletedName, deletedBirthDate));
    let changed = nextFriends.length !== friends.length;

    const referral = data.referral && typeof data.referral === "object" ? data.referral : null;
    if (referral && String(referral.referredByUserKey || "").trim() === userKey) {
      data.referral = {
        ...referral,
        referredByCode: "",
        referredByUserKey: "",
        socialConnectionCompleted: false
      };
      changed = true;
    }

    if (!changed) {
      continue;
    }
    data.friends = nextFriends;
    await saveUserData(entry.userKey, data);
  }
}

async function recomputeInvitedRegistrationsForUser(referrerUserKey) {
  const userKey = String(referrerUserKey || "").trim();
  if (!userKey) {
    return;
  }
  const allUsers = await listAllUserStateEntries();
  const invitedCount = allUsers.reduce((acc, entry) => {
    const referredBy = String(entry?.data?.referral?.referredByUserKey || "").trim();
    return acc + (referredBy === userKey ? 1 : 0);
  }, 0);
  const referrerData = await loadUserData(userKey);
  if (!referrerData.metrics || typeof referrerData.metrics !== "object") {
    referrerData.metrics = { invitesSent: 0, invitedRegistrations: 0 };
  }
  referrerData.metrics.invitedRegistrations = invitedCount;
  await saveUserData(userKey, referrerData);
}

async function finalizeReferralSocialConnectionIfReady(userKey, userData) {
  if (!userKey) {
    return normalizeUserData(userData);
  }
  const normalized = normalizeUserData(userData);
  const referral = normalized?.referral && typeof normalized.referral === "object" ? normalized.referral : null;
  if (!referral || referral.shareBirthDataConsent === false || referral.socialConnectionCompleted || !normalized.profile) {
    return normalized;
  }
  let referrerUserKey = String(referral.referredByUserKey || "").trim();
  if (!referrerUserKey) {
    const fallbackCode = String(referral.referredByCode || "").trim();
    if (fallbackCode) {
      referrerUserKey = await findUserKeyByReferralCode(fallbackCode);
      if (referrerUserKey && referrerUserKey !== userKey) {
        normalized.referral.referredByUserKey = referrerUserKey;
      }
    }
  }
  if (!referrerUserKey || referrerUserKey === userKey) {
    return normalized;
  }
  const referrerData = await loadUserData(referrerUserKey);
  if (!referrerData?.profile) {
    return normalized;
  }
  await ensureMutualFriendLink(userKey, normalized, referrerUserKey, referrerData);
  const refreshed = normalizeUserData(await loadUserData(userKey));
  refreshed.referral = refreshed.referral && typeof refreshed.referral === "object"
    ? refreshed.referral
    : {
        code: "",
        referredByCode: "",
        referredByUserKey: "",
        shareBirthDataConsent: true,
        socialConnectionCompleted: false
      };
  refreshed.referral.socialConnectionCompleted = true;
  await saveUserData(userKey, refreshed);
  return refreshed;
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
  const latitude = toOptionalFiniteNumber(profile.latitude);
  const longitude = toOptionalFiniteNumber(profile.longitude);
  const timezoneIana = String(profile.timezoneIana || "").trim();
  const selectedCelebrityIdsRaw = Array.isArray(profile.selectedCelebrityIds)
    ? profile.selectedCelebrityIds
    : typeof profile.selectedCelebrityIds === "string"
      ? profile.selectedCelebrityIds.split(",")
      : [];
  const selectedCelebrityIds = selectedCelebrityIdsRaw
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .slice(0, 3);

  if (!name || !birthDate || !birthTime || !birthCity) {
    return null;
  }

  const normalizedLatitude = latitude === 0 && longitude === 0 ? null : latitude;
  const normalizedLongitude = latitude === 0 && longitude === 0 ? null : longitude;

  return {
    name,
    birthDate,
    birthTime,
    birthCity,
    timezone,
    latitude: normalizedLatitude,
    longitude: normalizedLongitude,
    timezoneIana: timezoneIana || null,
    selectedCelebrityIds
  };
}

function toOptionalFiniteNumber(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string" && value.trim() === "") {
    return null;
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function hasUsableCoordinates(profile) {
  const latitude = Number(profile?.latitude);
  const longitude = Number(profile?.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return false;
  }
  return true;
}

function hasMeaningfulCoordinates(profile) {
  const latitude = Number(profile?.latitude);
  const longitude = Number(profile?.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return false;
  }
  return !(Math.abs(latitude) < 1e-9 && Math.abs(longitude) < 1e-9);
}

function signFromDate(dateText) {
  const [monthRaw, dayRaw] = String(dateText || "")
    .split("-")
    .slice(1, 3)
    .map((value) => Number(value));
  const month = Number.isFinite(monthRaw) ? monthRaw : null;
  const day = Number.isFinite(dayRaw) ? dayRaw : null;
  if (month && day) {
    return signFromMonthDay(month, day);
  }
  const fallback = new Date(`${dateText}T00:00:00Z`);
  const fallbackMonth = Number.isFinite(fallback.getUTCMonth()) ? fallback.getUTCMonth() + 1 : 1;
  const fallbackDay = Number.isFinite(fallback.getUTCDate()) ? fallback.getUTCDate() : 1;
  return signFromMonthDay(fallbackMonth, fallbackDay);
}

function signFromMonthDay(month, day) {
  const value = month * 100 + day;
  const ranges = [
    { sign: "Capricorn", from: 1222, to: 119, wrap: true },
    { sign: "Aquarius", from: 120, to: 218, wrap: false },
    { sign: "Pisces", from: 219, to: 320, wrap: false },
    { sign: "Aries", from: 321, to: 419, wrap: false },
    { sign: "Taurus", from: 420, to: 520, wrap: false },
    { sign: "Gemini", from: 521, to: 620, wrap: false },
    { sign: "Cancer", from: 621, to: 722, wrap: false },
    { sign: "Leo", from: 723, to: 822, wrap: false },
    { sign: "Virgo", from: 823, to: 922, wrap: false },
    { sign: "Libra", from: 923, to: 1022, wrap: false },
    { sign: "Scorpio", from: 1023, to: 1121, wrap: false },
    { sign: "Sagittarius", from: 1122, to: 1221, wrap: false }
  ];
  for (const item of ranges) {
    if (!item.wrap && value >= item.from && value <= item.to) {
      return item.sign;
    }
    if (item.wrap && (value >= item.from || value <= item.to)) {
      return item.sign;
    }
  }
  return "Capricorn";
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
  if (!hasUsableCoordinates(profile)) {
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

function toBoolean(value) {
  if (typeof value === "boolean") {
    return value;
  }
  const normalized = String(value || "").trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "on" || normalized === "yes";
}

function normalizeTelegramHandle(value) {
  const raw = String(value || "").trim();
  if (!raw) {
    return "";
  }
  const withoutUrl = raw.replace(/^https?:\/\/t\.me\//i, "");
  const withoutAt = withoutUrl.replace(/^@/, "");
  return withoutAt.replace(/[^a-zA-Z0-9_]/g, "");
}

function normalizeEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  if (!email) {
    return "";
  }
  const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  return isValid ? email : "";
}

async function buildFriendNatalMini(friendInput) {
  const name = String(friendInput?.friendName || "Friend").trim() || "Friend";
  const birthDate = String(friendInput?.friendBirthDate || "").trim();
  const birthTime = String(friendInput?.friendBirthTime || "").trim();
  const birthCity = String(friendInput?.friendBirthCity || "").trim();
  const hasDate = Boolean(birthDate);
  const hasTime = Boolean(birthTime);
  const hasCity = Boolean(birthCity);

  const sun = hasDate ? signFromDate(birthDate) : "Unknown";
  const moon = hasDate ? moonFromDate(birthDate) : "Unknown";
  const rising = hasTime ? risingFromTime(birthTime) : "Unknown";
  const completeness = Number(hasDate) + Number(hasTime) + Number(hasCity);
  const confidence = completeness === 3 ? "high" : completeness === 2 ? "medium" : "baseline";

  const base = {
    core: { sun, moon, rising },
    confidence,
    birthDate: birthDate || null,
    birthTime: birthTime || null,
    birthCity: birthCity || null,
    summary: hasDate
      ? `${name}: ${sun} core, ${moon} emotional profile${hasTime ? `, ${rising} rising pattern` : ""}.`
      : `${name}: add birth date to unlock sign-based mini natal profile.`,
    planets: []
  };

  if (!hasDate) {
    return base;
  }

  if (!hasTime || !hasCity) {
    return base;
  }

  const geo = await geocodeCity(birthCity);
  if (!geo || !Number.isFinite(geo.latitude) || !Number.isFinite(geo.longitude)) {
    return base;
  }

  try {
    const [year, monthRaw, day] = birthDate.split("-").map((value) => Number(value));
    const [hour, minute] = birthTime.split(":").map((value) => Number(value));
    if (![year, monthRaw, day, hour, minute].every((value) => Number.isFinite(value))) {
      return base;
    }
    const origin = new Origin({
      year,
      month: monthRaw - 1,
      date: day,
      hour,
      minute,
      latitude: geo.latitude,
      longitude: geo.longitude
    });
    const horoscope = new Horoscope({
      origin,
      houseSystem: "placidus",
      zodiac: "tropical",
      language: "en"
    });
    const planets = Array.isArray(horoscope?.CelestialBodies?.all)
      ? horoscope.CelestialBodies.all
        .filter((body) => ["sun", "moon", "mercury", "venus", "mars"].includes(String(body?.key || "").toLowerCase()))
        .map((body) => ({
          key: String(body?.label || body?.key || "Planet"),
          sign: String(body?.Sign?.label || "Unknown"),
          house: Number(body?.House?.id) || null
        }))
      : [];
    return {
      ...base,
      core: {
        sun: horoscope?.CelestialBodies?.sun?.Sign?.label || sun,
        moon: horoscope?.CelestialBodies?.moon?.Sign?.label || moon,
        rising: horoscope?.Ascendant?.Sign?.label || rising
      },
      confidence: "high",
      summary: `${name}: ${horoscope?.CelestialBodies?.sun?.Sign?.label || sun} Sun, ${horoscope?.CelestialBodies?.moon?.Sign?.label || moon} Moon, ${horoscope?.Ascendant?.Sign?.label || rising} Rising.`,
      planets
    };
  } catch {
    return base;
  }
}

function buildDynamicCompatibility(profile, friend, dayKey, period, userSign) {
  const normalizedUserSign = String(userSign || "").trim() || (profile ? signFromDate(profile.birthDate) : "Unknown");
  const natalMini = friend?.natalMini && typeof friend.natalMini === "object"
    ? friend.natalMini
    : {
        core: {
          sun: friend?.friendBirthDate ? signFromDate(friend.friendBirthDate) : String(friend?.friendSign || "Unknown"),
          moon: friend?.friendBirthDate ? moonFromDate(friend.friendBirthDate) : "Unknown",
          rising: friend?.friendBirthTime ? risingFromTime(friend.friendBirthTime) : "Unknown"
        },
        confidence: friend?.friendBirthDate ? "baseline" : "low",
        birthDate: friend?.friendBirthDate || null,
        birthTime: friend?.friendBirthTime || null,
        birthCity: friend?.friendBirthCity || null,
        summary: ""
      };
  const resolvedFriendSign = String(natalMini?.core?.sun || friend?.friendSign || "").trim() || "Unknown";
  const detail = buildCompatibilityDetail({
    userSign: normalizedUserSign,
    friendSign: resolvedFriendSign,
    friendName: friend.friendName,
    dayKey,
    period,
    seedKey: friend.id || friend.friendName
  });
  return {
    id: friend.id,
    friendName: friend.friendName,
    friendSign: resolvedFriendSign,
    friendTelegram: String(friend.friendTelegram || ""),
    friendEmail: String(friend.friendEmail || ""),
    noShareData: Boolean(friend.noShareData),
    friendBirthDate: String(friend.friendBirthDate || ""),
    friendBirthTime: String(friend.friendBirthTime || ""),
    friendBirthCity: String(friend.friendBirthCity || ""),
    natalMini,
    ...detail
  };
}

function dailyQuestPool() {
  return [
    { title: "Cognitive Reframe", task: "Catch one automatic negative thought and rewrite it into a testable neutral statement.", category: "psychology" },
    { title: "Boundary Micro-step", task: "Write one clear boundary sentence and use it in a real conversation today.", category: "self-development" },
    { title: "Attention Audit", task: "Track your context switches for one hour and remove one avoidable distraction.", category: "productivity" },
    { title: "Emotional Naming", task: "Name your top emotion every 3 hours and note what triggered it.", category: "psychology" },
    { title: "Relationship Repair", task: "Send one concise repair message where communication drifted this week.", category: "relationships" },
    { title: "Body Reset", task: "Take a 15-minute walk without phone and observe breathing rhythm changes.", category: "self-development" },
    { title: "Decision Hygiene", task: "Delay one non-urgent decision by 24h and collect one extra data point.", category: "psychology" },
    { title: "Values Alignment", task: "Pick one action that aligns with your long-term value instead of short-term mood.", category: "self-development" },
    { title: "Clarity Drill", task: "Rewrite one vague request into a concrete ask with owner and deadline.", category: "productivity" },
    { title: "Stress Buffer", task: "Insert two 5-minute pauses between high-load tasks and track effect on tone.", category: "self-development" }
  ];
}

function chooseDailyQuest(profile, natalCore, dayKey) {
  const pool = dailyQuestPool();
  const seed = hashStringToInt(`${profile?.name || "anon"}:${natalCore?.sun || "Unknown"}:${dayKey}`);
  const first = pool[seed % pool.length];
  const second = pool[(seed + 3) % pool.length];
  const third = pool[(seed + 7) % pool.length];
  return [first, second, third];
}

function dateAtUtcNoon(offsetDays = 0) {
  const now = new Date();
  const base = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 12, 0, 0));
  return new Date(base.getTime() + offsetDays * 86400000);
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

  if (!hasUsableCoordinates(profile)) {
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
  let result = null;
  const queries = buildGeocodeQueries(cityName);
  for (const query of queries) {
    result = await geocodeCityViaOpenMeteo(query);
    if (result) {
      break;
    }
  }
  if (!result) {
    result = await geocodeCityViaNominatim(cityName);
  }
  if (!result) {
    return null;
  }
  geoCache.set(key, result);
  return result;
}

function normalizeCityQuery(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function buildGeocodeQueries(cityName) {
  const raw = String(cityName || "").trim();
  const normalized = normalizeCityQuery(raw);
  const variants = new Set([raw, normalized]);
  const partsRaw = raw.split(",").map((item) => item.trim()).filter(Boolean);
  const partsNormalized = normalized.split(",").map((item) => item.trim()).filter(Boolean);
  if (partsRaw.length) {
    variants.add(partsRaw[0]);
    variants.add(partsRaw.slice(0, 2).join(", "));
  }
  if (partsNormalized.length) {
    variants.add(partsNormalized[0]);
    variants.add(partsNormalized.slice(0, 2).join(", "));
  }
  return Array.from(variants).filter(Boolean);
}

function mapOpenMeteoResult(first, fallbackName) {
  const latitude = Number(first?.latitude);
  const longitude = Number(first?.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  return {
    latitude,
    longitude,
    timezoneIana: String(first.timezone || "").trim() || null,
    country: String(first.country || "").trim() || null,
    admin1: String(first.admin1 || "").trim() || null,
    resolvedName: String(first.name || "").trim() || fallbackName
  };
}

async function geocodeCityViaOpenMeteo(query) {
  const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=5&language=en&format=json`;
  try {
    const response = await fetch(url);
    if (!response.ok) {
      return null;
    }
    const payload = await response.json();
    const results = Array.isArray(payload?.results) ? payload.results : [];
    for (const item of results) {
      const mapped = mapOpenMeteoResult(item, query);
      if (mapped) {
        return mapped;
      }
    }
    return null;
  } catch {
    return null;
  }
}

async function geocodeCityViaNominatim(cityName) {
  const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=${encodeURIComponent(cityName)}`;
  const response = await fetch(url, {
    headers: {
      "User-Agent": "Astronautica/1.0 (geocoding fallback)"
    }
  });
  if (!response.ok) {
    return null;
  }
  const payload = await response.json();
  const first = Array.isArray(payload) ? payload[0] : null;
  if (!first) {
    return null;
  }
  const latitude = Number(first.lat);
  const longitude = Number(first.lon);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  const displayName = String(first.display_name || "").trim();
  const parts = displayName.split(",").map((item) => item.trim()).filter(Boolean);
  return {
    latitude,
    longitude,
    timezoneIana: null,
    country: parts.at(-1) || null,
    admin1: parts.length > 2 ? parts[parts.length - 3] : null,
    resolvedName: parts[0] || cityName
  };
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
  if (hasMeaningfulCoordinates(profile)) {
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
    timezone: String(profile.timezone || "").trim() || String(geo.timezoneIana || "UTC"),
    timezoneIana: profile.timezoneIana || geo.timezoneIana || null
  };
}

async function hydrateAndPersistProfileCoordinates(req, profile, { persist = true } = {}) {
  if (!profile) {
    return null;
  }
  const hydrated = await ensureProfileCoordinates(profile);
  const changed =
    Number(hydrated.latitude) !== Number(profile.latitude) ||
    Number(hydrated.longitude) !== Number(profile.longitude) ||
    String(hydrated.timezoneIana || "") !== String(profile.timezoneIana || "");
  if (persist && changed && req?.userData && req?.userId) {
    req.userData.profile = hydrated;
    await saveUserData(req.userId, req.userData);
  }
  return hydrated;
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
  const selectedCelebrityIds = Array.isArray(profile.selectedCelebrityIds) ? profile.selectedCelebrityIds.slice(0, 3) : [];
  const celebrityComparisons = selectedCelebrityIds
    .map((id) => historicalCelebritiesById.get(String(id || "").trim()))
    .filter(Boolean)
    .map((celeb) => {
      const detail = buildCompatibilityDetail({
        userSign: natalCore.sun,
        friendSign: celeb.sign,
        friendName: celeb.name,
        dayKey,
        period,
        seedKey: celeb.id
      });
      return {
        id: celeb.id,
        name: celeb.name,
        sign: celeb.sign,
        field: celeb.field,
        years: celeb.years,
        fact: celeb.fact,
        score: detail.score,
        trend: detail.trend,
        note: detail.note
      };
    });
  const celebrityDynamic = celebrityComparisons.map((item) => ({
    id: `celeb:${item.id}`,
    celebrityId: item.id,
    isHistoricalCompanion: true,
    isVirtual: true,
    virtualSource: "celebrity",
    friendName: item.name,
    friendSign: item.sign,
    friendBirthDate: historicalCelebritiesById.get(item.id)?.birthDate || null,
    friendBirthTime: historicalCelebritiesById.get(item.id)?.birthTime || null,
    friendBirthCity: historicalCelebritiesById.get(item.id)?.birthCity || null,
    score: item.score,
    trend: item.trend,
    note: "",
    highlights: [],
    advice: "",
    rationale: item.fact,
    biography: item.fact,
    domains: [],
    noShareData: true,
    natalMini: {
      core: {
        sun: item.sign || "Unknown",
        moon: moonFromDate(historicalCelebritiesById.get(item.id)?.birthDate || "") || "Unknown",
        rising: risingFromTime(historicalCelebritiesById.get(item.id)?.birthTime || "") || "Unknown"
      },
      summary: ""
    },
    userSign: natalCore.sun,
    period
  }));

  return {
    profile,
    natalCore,
    daily,
    periodForecast,
    friendsDynamic: [...friendsDynamic, ...celebrityDynamic],
    celebrityComparisons
  };
}

function isAuthenticated(sessionData) {
  return Boolean(String(sessionData?.auth?.provider || "").trim() && String(sessionData?.auth?.userKey || "").trim());
}

function requestUserId(req) {
  if (!authRequired) {
    return "dev-local-user";
  }
  return String(req.sessionData?.auth?.userKey || "").trim();
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

function oauthCallbackUrl(req, provider) {
  const base =
    appBaseUrlEnv ||
    `${String(req.headers["x-forwarded-proto"] || "").toLowerCase().includes("https") ? "https" : req.protocol}://${req.get("host")}`;
  return `${base}/api/auth/${provider}/callback`;
}

function normalizeReturnToPath(value) {
  const text = String(value || "").trim();
  if (!text || !text.startsWith("/")) {
    return "/";
  }
  if (text.startsWith("//")) {
    return "/";
  }
  return text;
}

function upsertOauthFlow(sessionData, provider, returnTo = "/") {
  sessionData.oauthFlow = {
    provider,
    state: crypto.randomUUID(),
    createdAt: Date.now(),
    returnTo: normalizeReturnToPath(returnTo)
  };
  return sessionData.oauthFlow;
}

function consumeOauthFlow(sessionData, provider, state) {
  const flow = sessionData?.oauthFlow && typeof sessionData.oauthFlow === "object" ? sessionData.oauthFlow : null;
  sessionData.oauthFlow = null;
  if (!flow) {
    return { ok: false, reason: "missing_oauth_state" };
  }
  const age = Date.now() - Number(flow.createdAt || 0);
  if (age < 0 || age > MAX_OAUTH_STATE_AGE_MS) {
    return { ok: false, reason: "expired_oauth_state" };
  }
  if (String(flow.provider || "") !== String(provider || "")) {
    return { ok: false, reason: "provider_mismatch" };
  }
  if (String(flow.state || "") !== String(state || "")) {
    return { ok: false, reason: "invalid_oauth_state" };
  }
  return { ok: true, returnTo: normalizeReturnToPath(flow.returnTo || "/") };
}

async function finalizeAuthLogin(req, provider, profile, via) {
  const externalId = String(profile?.id || "").trim();
  if (!externalId) {
    throw new Error("missing_external_user_id");
  }
  const user = {
    id: externalId,
    first_name: String(profile?.first_name || "").trim(),
    last_name: String(profile?.last_name || "").trim(),
    username: String(profile?.username || "").trim(),
    email: String(profile?.email || "").trim().toLowerCase(),
    photo_url: String(profile?.photo_url || "").trim()
  };
  const userKey = `${provider}:${externalId}`;
  req.sessionData.auth = {
    provider,
    userKey,
    externalUserId: externalId,
    telegramUserId: provider === "telegram" ? externalId : "",
    user,
    telegramUser: provider === "telegram" ? user : null,
    authenticatedAt: Date.now(),
    via: String(via || "")
  };
  await persistSession(req.sessionId, req.sessionData);
  const existingUserData = await loadUserData(userKey);
  const mergedUserData = mergeSessionIntoUserData(existingUserData, req.sessionData);
  if (!mergedUserData.referral || typeof mergedUserData.referral !== "object") {
    mergedUserData.referral = {
      code: "",
      referredByCode: "",
      referredByUserKey: "",
      shareBirthDataConsent: true,
      socialConnectionCompleted: false
    };
  }
  if (!mergedUserData.referral.code) {
    mergedUserData.referral.code = generateReferralCode(userKey);
  }
  if (!mergedUserData.metrics || typeof mergedUserData.metrics !== "object") {
    mergedUserData.metrics = { invitesSent: 0, invitedRegistrations: 0 };
  }
  if (!Number.isFinite(Number(mergedUserData.metrics.invitedRegistrations))) {
    mergedUserData.metrics.invitedRegistrations = 0;
  }
  const referralContext = req.sessionData?.referralContext;
  const hasExistingReferral = Boolean(String(mergedUserData.referral.referredByUserKey || "").trim());
  if (referralContext?.code && !hasExistingReferral) {
    const code = String(referralContext.code || "").toUpperCase().trim();
    const shareBirthDataConsent = referralContext.shareBirthDataConsent !== false;
    const referrerUserKey = await findUserKeyByReferralCode(code);
    if (referrerUserKey && referrerUserKey !== userKey) {
      mergedUserData.referral.referredByCode = code;
      mergedUserData.referral.referredByUserKey = referrerUserKey;
      mergedUserData.referral.shareBirthDataConsent = shareBirthDataConsent;
      mergedUserData.referral.socialConnectionCompleted = false;

      const referrerData = await loadUserData(referrerUserKey);
      if (!referrerData.metrics || typeof referrerData.metrics !== "object") {
        referrerData.metrics = { invitesSent: 0, invitedRegistrations: 0 };
      }
      referrerData.metrics.invitedRegistrations = Number(referrerData.metrics.invitedRegistrations || 0) + 1;
      await saveUserData(referrerUserKey, referrerData);
    }
    req.sessionData.referralContext = null;
    await persistSession(req.sessionId, req.sessionData);
  }
  await saveUserData(userKey, mergedUserData);

  await finalizeReferralSocialConnectionIfReady(userKey, mergedUserData);
  return sanitizeAuthUser(req.sessionData);
}

async function exchangeGoogleCodeForProfile(req, code) {
  const redirectUri = oauthCallbackUrl(req, "google");
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code: String(code || ""),
      client_id: googleClientId,
      client_secret: googleClientSecret,
      redirect_uri: redirectUri,
      grant_type: "authorization_code"
    })
  });
  const tokenPayload = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || !tokenPayload?.access_token) {
    return { ok: false, reason: "google_token_exchange_failed", details: tokenPayload };
  }
  const userInfoResponse = await fetch("https://openidconnect.googleapis.com/v1/userinfo", {
    headers: { Authorization: `Bearer ${tokenPayload.access_token}` }
  });
  const userInfo = await userInfoResponse.json().catch(() => ({}));
  if (!userInfoResponse.ok || !userInfo?.sub) {
    return { ok: false, reason: "google_profile_fetch_failed", details: userInfo };
  }
  return {
    ok: true,
    profile: {
      id: String(userInfo.sub),
      first_name: String(userInfo.given_name || "").trim(),
      last_name: String(userInfo.family_name || "").trim(),
      username: String(userInfo.email || "").split("@")[0] || "",
      email: String(userInfo.email || "").trim().toLowerCase(),
      photo_url: String(userInfo.picture || "").trim()
    }
  };
}

async function exchangeGithubCodeForProfile(req, code) {
  const redirectUri = oauthCallbackUrl(req, "github");
  const tokenResponse = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json"
    },
    body: new URLSearchParams({
      code: String(code || ""),
      client_id: githubClientId,
      client_secret: githubClientSecret,
      redirect_uri: redirectUri
    })
  });
  const tokenPayload = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || !tokenPayload?.access_token) {
    return { ok: false, reason: "github_token_exchange_failed", details: tokenPayload };
  }
  const userResponse = await fetch("https://api.github.com/user", {
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${tokenPayload.access_token}`,
      "User-Agent": "astronautica-auth"
    }
  });
  const userInfo = await userResponse.json().catch(() => ({}));
  if (!userResponse.ok || !Number.isFinite(Number(userInfo?.id))) {
    return { ok: false, reason: "github_profile_fetch_failed", details: userInfo };
  }
  const emailsResponse = await fetch("https://api.github.com/user/emails", {
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${tokenPayload.access_token}`,
      "User-Agent": "astronautica-auth"
    }
  });
  const emailsPayload = await emailsResponse.json().catch(() => []);
  const emails = Array.isArray(emailsPayload) ? emailsPayload : [];
  const primaryEmail = emails.find((entry) => entry?.primary && entry?.verified)?.email
    || emails.find((entry) => entry?.verified)?.email
    || "";
  const fullName = String(userInfo?.name || "").trim();
  const [firstName = "", ...rest] = fullName.split(/\s+/).filter(Boolean);
  return {
    ok: true,
    profile: {
      id: String(userInfo.id),
      first_name: firstName,
      last_name: rest.join(" "),
      username: String(userInfo?.login || "").trim(),
      email: String(primaryEmail || "").trim().toLowerCase(),
      photo_url: String(userInfo?.avatar_url || "").trim()
    }
  };
}

function sanitizeAuthUser(sessionData) {
  const auth = sessionData?.auth;
  const user = auth?.user || auth?.telegramUser;
  if (!user || typeof user !== "object") {
    return null;
  }
  return {
    id: String(user.id || ""),
    provider: String(auth?.provider || ""),
    firstName: String(user.first_name || ""),
    lastName: String(user.last_name || ""),
    username: String(user.username || ""),
    email: String(user.email || ""),
    photoUrl: String(user.photo_url || "")
  };
}

const contracts = {
  auth: {
    status: "GET /api/auth/status",
    loginWidget: "POST /api/auth/telegram-widget",
    loginInitData: "POST /api/auth/telegram-init-data",
    googleStart: "GET /api/auth/google/start",
    googleCallback: "GET /api/auth/google/callback",
    githubStart: "GET /api/auth/github/start",
    githubCallback: "GET /api/auth/github/callback",
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
  const provider = authenticated ? String(req.sessionData?.auth?.provider || "") : null;
  res.json({
    ok: true,
    authRequired,
    authenticated,
    provider: provider || null,
    user: authenticated ? sanitizeAuthUser(req.sessionData) : null,
    telegramLoginEnabled: Boolean(telegramBotToken && telegramBotUsername),
    googleLoginEnabled,
    githubLoginEnabled,
    telegramBotUsername: telegramBotUsername || null,
    telegramBotId,
    referralContext: req.sessionData?.referralContext || null
  });
});

app.post("/api/auth/referral-context", async (req, res) => {
  const code = String(req.body?.code || "").toUpperCase().trim();
  const shareBirthDataConsent = req.body?.shareBirthDataConsent !== false;
  if (!code) {
    req.sessionData.referralContext = null;
    await persistSession(req.sessionId, req.sessionData);
    return res.json({ ok: true, referralContext: null });
  }
  req.sessionData.referralContext = {
    code,
    shareBirthDataConsent,
    capturedAt: Date.now()
  };
  await persistSession(req.sessionId, req.sessionData);
  return res.json({ ok: true, referralContext: req.sessionData.referralContext });
});

app.post("/api/auth/telegram-widget", async (req, res) => {
  const validation = validateTelegramWidgetAuth(req.body?.telegramAuth, telegramBotToken);
  if (!validation.ok) {
    return res.status(401).json({ error: "unauthorized", reason: validation.error });
  }
  const user = await finalizeAuthLogin(req, "telegram", validation.user, "widget");
  return res.json({ ok: true, authenticated: true, user });
});

app.post("/api/auth/telegram-init-data", async (req, res) => {
  const initData = String(req.body?.initData || "").trim();
  const validation = validateTelegramInitData(initData, telegramBotToken);
  if (!validation.ok) {
    return res.status(401).json({ error: "unauthorized", reason: validation.error });
  }

  const user = await finalizeAuthLogin(req, "telegram", validation.user, "webapp");
  return res.json({ ok: true, authenticated: true, user });
});

app.get("/api/auth/google/start", async (req, res) => {
  if (!googleLoginEnabled) {
    return res.status(503).json({ error: "google_auth_not_configured" });
  }
  const returnTo = normalizeReturnToPath(req.query?.returnTo || "/");
  const flow = upsertOauthFlow(req.sessionData, "google", returnTo);
  await persistSession(req.sessionId, req.sessionData);
  const authorizeUrl = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  authorizeUrl.searchParams.set("client_id", googleClientId);
  authorizeUrl.searchParams.set("redirect_uri", oauthCallbackUrl(req, "google"));
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("scope", "openid email profile");
  authorizeUrl.searchParams.set("state", flow.state);
  authorizeUrl.searchParams.set("prompt", "select_account");
  res.redirect(authorizeUrl.toString());
});

app.get("/api/auth/google/callback", async (req, res) => {
  const state = String(req.query?.state || "").trim();
  const code = String(req.query?.code || "").trim();
  const denied = String(req.query?.error || "").trim();
  const flowCheck = consumeOauthFlow(req.sessionData, "google", state);
  await persistSession(req.sessionId, req.sessionData);
  if (!flowCheck.ok) {
    return res.redirect("/login");
  }
  if (denied || !code) {
    return res.redirect("/login");
  }
  const exchanged = await exchangeGoogleCodeForProfile(req, code);
  if (!exchanged.ok) {
    return res.redirect("/login");
  }
  await finalizeAuthLogin(req, "google", exchanged.profile, "oauth");
  return res.redirect(flowCheck.returnTo || "/");
});

app.get("/api/auth/github/start", async (req, res) => {
  if (!githubLoginEnabled) {
    return res.status(503).json({ error: "github_auth_not_configured" });
  }
  const returnTo = normalizeReturnToPath(req.query?.returnTo || "/");
  const flow = upsertOauthFlow(req.sessionData, "github", returnTo);
  await persistSession(req.sessionId, req.sessionData);
  const authorizeUrl = new URL("https://github.com/login/oauth/authorize");
  authorizeUrl.searchParams.set("client_id", githubClientId);
  authorizeUrl.searchParams.set("redirect_uri", oauthCallbackUrl(req, "github"));
  authorizeUrl.searchParams.set("scope", "read:user user:email");
  authorizeUrl.searchParams.set("state", flow.state);
  res.redirect(authorizeUrl.toString());
});

app.get("/api/auth/github/callback", async (req, res) => {
  const state = String(req.query?.state || "").trim();
  const code = String(req.query?.code || "").trim();
  const denied = String(req.query?.error || "").trim();
  const flowCheck = consumeOauthFlow(req.sessionData, "github", state);
  await persistSession(req.sessionId, req.sessionData);
  if (!flowCheck.ok) {
    return res.redirect("/login");
  }
  if (denied || !code) {
    return res.redirect("/login");
  }
  const exchanged = await exchangeGithubCodeForProfile(req, code);
  if (!exchanged.ok) {
    return res.redirect("/login");
  }
  await finalizeAuthLogin(req, "github", exchanged.profile, "oauth");
  return res.redirect(flowCheck.returnTo || "/");
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

app.get("/api/profile", requireAuth, async (req, res) => {
  const current = pickProfile({ profile: req.userData.profile });
  const profile = await hydrateAndPersistProfileCoordinates(req, current);
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
  let rawProfile = pickProfile(req.body);
  if (!rawProfile) {
    return res.status(400).json({
      error: "invalid_profile",
      message: "name, birthDate, birthTime and birthCity are required"
    });
  }
  const currentProfile = pickProfile({ profile: req.userData.profile });
  const prevCity = String(currentProfile?.birthCity || "").trim().toLowerCase();
  const nextCity = String(rawProfile.birthCity || "").trim().toLowerCase();
  const cityChanged = Boolean(prevCity && nextCity && prevCity !== nextCity);
  if (cityChanged) {
    rawProfile = {
      ...rawProfile,
      latitude: null,
      longitude: null,
      timezoneIana: null
    };
  }
  const profile = await ensureProfileCoordinates(rawProfile);
  req.userData.profile = profile;
  if (!req.userData.referral || typeof req.userData.referral !== "object") {
    req.userData.referral = {
      code: generateReferralCode(req.userId),
      referredByCode: "",
      referredByUserKey: "",
      shareBirthDataConsent: true,
      socialConnectionCompleted: false
    };
  }
  if (!req.userData.referral.code) {
    req.userData.referral.code = generateReferralCode(req.userId);
  }
  req.userData = await finalizeReferralSocialConnectionIfReady(req.userId, req.userData);
  await saveUserData(req.userId, req.userData);
  return res.json({ ok: true, profile, profileReady: true });
});

app.delete("/api/profile", requireAuth, async (req, res) => {
  const userId = String(req.userId || "").trim();
  if (!userId) {
    return res.status(400).json({ error: "invalid_user_id" });
  }
  const userDataBeforeDelete = await loadUserData(userId);
  const inviterUserKey = String(userDataBeforeDelete?.referral?.referredByUserKey || "").trim();
  try {
    await removeDeletedUserFromSocialGraph(userId, userDataBeforeDelete);
  } catch (error) {
    console.error("profile_delete_social_cleanup_failed", error);
  }
  await deleteUserData(userId);
  if (inviterUserKey) {
    try {
      await recomputeInvitedRegistrationsForUser(inviterUserKey);
    } catch (error) {
      console.error("profile_delete_recompute_invites_failed", error);
    }
  }
  const oldSid = req.sessionId;
  const sid = crypto.randomUUID();
  const freshSession = defaultSessionData();
  await persistSession(sid, freshSession);
  await deleteSessionBySid(oldSid);
  res.setHeader("Set-Cookie", buildSessionCookie(sid, req));
  return res.json({ ok: true, deleted: true, authenticated: false });
});

app.get("/api/referral", requireAuth, async (req, res) => {
  req.userData = await finalizeReferralSocialConnectionIfReady(req.userId, req.userData);
  if (!req.userData.referral || typeof req.userData.referral !== "object") {
    req.userData.referral = {
      code: "",
      referredByCode: "",
      referredByUserKey: "",
      shareBirthDataConsent: true,
      socialConnectionCompleted: false
    };
  }
  if (!req.userData.referral.code) {
    req.userData.referral.code = generateReferralCode(req.userId);
    await saveUserData(req.userId, req.userData);
  }
  const base =
    appBaseUrlEnv ||
    `${String(req.headers["x-forwarded-proto"] || "").toLowerCase().includes("https") ? "https" : req.protocol}://${req.get("host")}`;
  const link = `${base}/login?ref=${encodeURIComponent(req.userData.referral.code)}`;
  return res.json({
    ok: true,
    code: req.userData.referral.code,
    link,
    invitedRegistrations: Number(req.userData.metrics?.invitedRegistrations || 0),
    shareInvitesSent: Number(req.userData.metrics?.invitesSent || 0)
  });
});

app.get("/api/friends", requireAuth, async (req, res) => {
  req.userData = await finalizeReferralSocialConnectionIfReady(req.userId, req.userData);
  res.json({ ok: true, friends: req.userData.friends || [] });
});

app.post("/api/friends", requireAuth, async (req, res) => {
  return res.status(410).json({
    error: "manual_friend_add_disabled",
    message: "Manual friend creation is disabled. Invite via your referral link from /friends."
  });
});

app.post("/api/friends/virtual-celebrity", requireAuth, async (req, res) => {
  const celebrityIdsRaw = Array.isArray(req.body?.celebrityIds)
    ? req.body.celebrityIds
    : [req.body?.celebrityId];
  const requestedIds = Array.from(
    new Set(
      celebrityIdsRaw
        .map((value) => String(value || "").trim())
        .filter(Boolean)
    )
  );
  if (!requestedIds.length) {
    return res.status(400).json({ error: "invalid_celebrity_id", message: "celebrityIds is required." });
  }
  const currentFriends = Array.isArray(req.userData.friends) ? req.userData.friends : [];
  const hasRealFriends = currentFriends.some((friend) => !friend?.isVirtual);
  if (hasRealFriends) {
    return res.status(409).json({
      error: "virtual_friend_only_when_empty",
      message: "Virtual celebrity profiles can be added only when there are no real social friends."
    });
  }
  const existingVirtualIds = new Set(
    currentFriends
      .filter((friend) => friend?.isVirtual && friend?.virtualSource === "celebrity")
      .map((friend) => String(friend?.celebrityId || "").trim())
      .filter(Boolean)
  );
  const remainingSlots = Math.max(0, 3 - existingVirtualIds.size);
  if (!remainingSlots) {
    return res.status(409).json({
      error: "virtual_friend_limit_reached",
      message: "You can add up to 3 virtual historical profiles."
    });
  }

  const addableIds = requestedIds
    .filter((id) => !existingVirtualIds.has(id))
    .filter((id) => historicalCelebritiesById.has(id))
    .slice(0, remainingSlots);

  const addedFriends = [];
  for (const id of addableIds) {
    const item = historicalCelebritiesById.get(id);
    if (!item) {
      continue;
    }
    const natalMini = await buildFriendNatalMini({
      friendName: item.name,
      friendBirthDate: item.birthDate,
      friendBirthTime: item.birthTime,
      friendBirthCity: item.birthCity
    });
    const friend = {
      id: crypto.randomUUID(),
      friendName: item.name,
      friendBirthDate: item.birthDate,
      friendBirthTime: item.birthTime,
      friendBirthCity: item.birthCity,
      friendSign: item.sign,
      friendTelegram: "",
      friendEmail: "",
      noShareData: true,
      natalMini,
      createdAt: Date.now(),
      isVirtual: true,
      virtualSource: "celebrity",
      celebrityId: item.id
    };
    addedFriends.push(friend);
  }

  if (!addedFriends.length) {
    return res.json({ ok: true, added: [], friends: currentFriends });
  }

  req.userData.friends = [...currentFriends, ...addedFriends];
  await saveUserData(req.userId, req.userData);
  return res.json({ ok: true, added: addedFriends, friends: req.userData.friends });
});

app.get("/api/celebrities", (req, res) => {
  const sign = String(req.query?.sign || "").trim();
  const items = sign
    ? historicalCelebrities.filter((item) => String(item.sign || "").toLowerCase() === sign.toLowerCase())
    : historicalCelebrities;
  return res.json({
    ok: true,
    celebrities: items.map((item) => ({
      id: item.id,
      slug: item.id,
      name: item.name,
      sign: item.sign,
      field: item.field,
      years: item.years,
      fact: item.fact,
      birthDate: item.birthDate,
      birthTime: item.birthTime,
      birthCity: item.birthCity
    }))
  });
});

app.get("/api/celebrities/:slug", async (req, res) => {
  const slug = String(req.params?.slug || "").trim();
  const item = historicalCelebritiesById.get(slug);
  if (!item) {
    return res.status(404).json({ error: "celebrity_not_found" });
  }
  const profile = {
    name: item.name,
    birthDate: item.birthDate,
    birthTime: item.birthTime,
    birthCity: item.birthCity,
    timezone: "UTC",
    latitude: null,
    longitude: null,
    timezoneIana: null
  };
  const hydrated = await ensureProfileCoordinates(profile);
  const natal = buildNatalDetail(hydrated);
  return res.json({
    ok: true,
    celebrity: {
      id: item.id,
      slug: item.id,
      name: item.name,
      sign: item.sign,
      field: item.field,
      years: item.years,
      fact: item.fact,
      birthDate: item.birthDate,
      birthTime: item.birthTime,
      birthCity: item.birthCity
    },
    natal
  });
});

app.delete("/api/friends/:id", requireAuth, async (req, res) => {
  const friendId = String(req.params?.id || "").trim();
  if (!friendId) {
    return res.status(400).json({ error: "invalid_friend_id", message: "Friend id is required" });
  }
  const currentFriends = Array.isArray(req.userData.friends) ? req.userData.friends : [];
  const nextFriends = currentFriends.filter((friend) => String(friend?.id || "") !== friendId);
  if (nextFriends.length === currentFriends.length) {
    return res.status(404).json({ error: "friend_not_found", message: "Friend not found" });
  }
  req.userData.friends = nextFriends;
  await saveUserData(req.userId, req.userData);
  return res.json({ ok: true, friends: nextFriends });
});

app.post("/api/natal-report", requireAuth, async (req, res) => {
  const requestProfile = pickProfile({ profile: req.body?.profile });
  const selectedProfile = resolveSessionProfile(req.body?.profile, req.userData);
  const profile = await hydrateAndPersistProfileCoordinates(req, selectedProfile, { persist: !requestProfile });
  if (!profile) {
    return res.status(400).json({ error: "invalid_profile", message: "profile is required" });
  }

  return res.json(buildNatalDetail(profile));
});

app.post("/api/daily-insight", requireAuth, async (req, res) => {
  const requestProfile = pickProfile({ profile: req.body?.profile });
  const selectedProfile = resolveSessionProfile(req.body?.profile, req.userData);
  const profile = await hydrateAndPersistProfileCoordinates(req, selectedProfile, { persist: !requestProfile });
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

  const natal = buildNatalDetail(profile);
  const natalCore = natal?.core || {
    sun: signFromDate(profile.birthDate),
    moon: moonFromDate(profile.birthDate),
    rising: risingFromTime(profile.birthTime)
  };
  const focus = "Prioritize one conversation that prevents future misunderstanding.";
  const risk = "Reactive messaging can escalate small ambiguity into unnecessary conflict.";
  const step = "Before noon, send one clear note: goal, boundary, and next checkpoint.";
  const [questPrimary, questSecondary, questOptional] = chooseDailyQuest(profile, natalCore, dayKey);
  const dailySeries = buildRealEnergySeries(profile, "week", now, natalCore) || {
    values: [48, 52, 50, 56, 54, 58, 55],
    labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    transits: []
  };
  const todayIndex = (() => {
    const d = now.getUTCDay();
    return d === 0 ? 6 : d - 1;
  })();
  const pickValue = (index) => dailySeries.values[Math.max(0, Math.min(dailySeries.values.length - 1, index))] || 50;
  const dailyDelta = {
    yesterday: pickValue(todayIndex - 1),
    today: pickValue(todayIndex),
    tomorrow: pickValue(todayIndex + 1)
  };
  const astronomy = (() => {
    const toSnapshot = (offsetDays, label) => {
      try {
        const target = dateAtUtcNoon(offsetDays);
        const origin = new Origin({
          year: target.getUTCFullYear(),
          month: target.getUTCMonth(),
          date: target.getUTCDate(),
          hour: target.getUTCHours(),
          minute: target.getUTCMinutes(),
          latitude: profile.latitude,
          longitude: profile.longitude
        });
        const horoscope = new Horoscope({ origin, houseSystem: "placidus", zodiac: "tropical", language: "en" });
        return {
          label,
          sun: horoscope?.CelestialBodies?.sun?.Sign?.label || "Unknown",
          moon: horoscope?.CelestialBodies?.moon?.Sign?.label || "Unknown",
          rising: horoscope?.Ascendant?.Sign?.label || "Unknown"
        };
      } catch {
        return {
          label,
          sun: natalCore.sun,
          moon: natalCore.moon,
          rising: natalCore.rising
        };
      }
    };
    return [toSnapshot(-1, "Yesterday"), toSnapshot(0, "Today"), toSnapshot(1, "Tomorrow")];
  })();

  pushDailyHistory(sessionDaily, { dayKey, focus, step });
  req.userData.daily = sessionDaily;
  if (!Number.isFinite(Number(req.userData.firstSeenAt))) {
    req.userData.firstSeenAt = Date.now();
  }
  if (!req.userData.metrics || typeof req.userData.metrics !== "object") {
    req.userData.metrics = { invitesSent: 0 };
  }
  await saveUserData(req.userId, req.userData);

  return res.json({
    dateLabel,
    intro: `${profile.name}, ${weekday} works best when you reduce context switching and protect one strategic block of deep work.`,
    focus,
    risk,
    step,
    streak: sessionDaily.streak,
    streakLabel: `Current streak: ${sessionDaily.streak} day${sessionDaily.streak === 1 ? "" : "s"}.`,
    history: sessionDaily.history,
    dayDashboard: {
      focus,
      risk,
      todayEnergy: dailyDelta.today,
      yesterdayEnergy: dailyDelta.yesterday,
      tomorrowEnergy: dailyDelta.tomorrow,
      deltaFromYesterday: dailyDelta.today - dailyDelta.yesterday,
      deltaToTomorrow: dailyDelta.tomorrow - dailyDelta.today
    },
    dailyQuest: {
      primary: questPrimary,
      secondary: questSecondary,
      optional: questOptional
    },
    achievements: {
      daysInSystem: Math.max(1, Math.floor((Date.now() - Number(req.userData.firstSeenAt || Date.now())) / 86400000) + 1),
      streakDays: sessionDaily.streak,
      friendsAdded: Array.isArray(req.userData.friends) ? req.userData.friends.length : 0,
      invitesSent: Number(req.userData.metrics?.invitesSent || 0)
    },
    astronomy
  });
});

app.post("/api/metrics/share-invite", requireAuth, async (req, res) => {
  if (!req.userData.metrics || typeof req.userData.metrics !== "object") {
    req.userData.metrics = { invitesSent: 0 };
  }
  req.userData.metrics.invitesSent = Number(req.userData.metrics.invitesSent || 0) + 1;
  await saveUserData(req.userId, req.userData);
  return res.json({ ok: true, invitesSent: req.userData.metrics.invitesSent });
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

app.get("/api/dashboard", requireAuth, async (req, res) => {
  const requestedPeriod = String(req.query?.period || "week").trim().toLowerCase();
  const period = ["week", "month", "year"].includes(requestedPeriod) ? requestedPeriod : "week";
  const current = pickProfile({ profile: req.userData.profile });
  await hydrateAndPersistProfileCoordinates(req, current);
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
    console.log(`astro-web auth providers telegram=${Boolean(telegramBotToken && telegramBotUsername)} google=${googleLoginEnabled} github=${githubLoginEnabled}`);
    app.listen(port, "0.0.0.0", () => {
      console.log(`astro-web listening on :${port}`);
    });
  })
  .catch((error) => {
    console.error("Failed to initialize astro-web", error);
    process.exit(1);
  });
