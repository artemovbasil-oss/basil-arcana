import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();
const port = Number(process.env.PORT || 8080);
const publicDir = path.join(__dirname, "public");

app.use(express.json({ limit: "256kb" }));
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

  if (!name || !birthDate || !birthTime || !birthCity) {
    return null;
  }

  return { name, birthDate, birthTime, birthCity, timezone };
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

const contracts = {
  natal_report: {
    request: {
      profile: {
        name: "string",
        birthDate: "YYYY-MM-DD",
        birthTime: "HH:mm",
        birthCity: "string",
        timezone: "string"
      }
    },
    response: {
      core: { sun: "string", moon: "string", rising: "string" },
      summary: "string",
      blocks: { strength: "string", blindSpot: "string", action: "string" },
      aspects: ["string"]
    }
  },
  daily_insight: {
    request: {
      profile: {
        name: "string",
        birthDate: "YYYY-MM-DD",
        birthTime: "HH:mm",
        birthCity: "string",
        timezone: "string"
      }
    },
    response: {
      dateLabel: "string",
      intro: "string",
      focus: "string",
      risk: "string",
      step: "string",
      streakLabel: "string"
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
  }
};

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "astro-web" });
});

app.get("/api/contracts", (_req, res) => {
  res.json({ ok: true, contracts });
});

app.post("/api/natal-report", (req, res) => {
  const profile = pickProfile(req.body);
  if (!profile) {
    return res.status(400).json({
      error: "invalid_profile",
      message: "name, birthDate, birthTime and birthCity are required"
    });
  }

  const sun = signFromDate(profile.birthDate);
  const moon = moonFromDate(profile.birthDate);
  const rising = risingFromTime(profile.birthTime);

  return res.json({
    core: { sun, moon, rising },
    summary: `${profile.name}, your chart emphasizes ${sun} identity with ${moon} emotional tone and ${rising} outward style.`,
    blocks: {
      strength: `${sun} supports long-range identity coherence. You can sustain direction through pressure.`,
      blindSpot: `${moon} can overreact to relational uncertainty when signals are mixed.`,
      action: `Use ${rising} visibility intentionally: one clear priority and one explicit boundary today.`
    },
    aspects: [
      "Sun trine Moon: internal alignment can become execution speed.",
      "Mercury square Mars: speak slower before commitment.",
      "Venus sextile Saturn: durable bonds grow through steady cadence.",
      "Jupiter opposition Neptune: verify optimism with measurable steps."
    ]
  });
});

app.post("/api/daily-insight", (req, res) => {
  const profile = pickProfile(req.body);
  if (!profile) {
    return res.status(400).json({
      error: "invalid_profile",
      message: "profile is required for daily insight"
    });
  }

  const now = new Date();
  const weekday = now.toLocaleDateString("en-US", { weekday: "long" });
  const dateLabel = now.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric"
  });

  return res.json({
    dateLabel,
    intro: `${profile.name}, ${weekday} works best when you reduce context switching and protect one strategic block of deep work.`,
    focus: "Prioritize one conversation that prevents future misunderstanding.",
    risk: "Reactive messaging can escalate small ambiguity into unnecessary conflict.",
    step: "Before noon, send one clear note: goal, boundary, and next checkpoint.",
    streakLabel: "Current streak: 1 day (MVP mock)."
  });
});

app.post("/api/compatibility-report", (req, res) => {
  const friend = req.body?.friend;
  const friendName = String(friend?.friendName || "").trim();
  const friendSign = String(friend?.friendSign || "").trim();

  if (!friendName || !friendSign) {
    return res.status(400).json({
      error: "invalid_friend",
      message: "friendName and friendSign are required"
    });
  }

  const profile = pickProfile(req.body);
  const userSign = profile ? signFromDate(profile.birthDate) : "Unknown";
  const score = Math.max(55, Math.min(95, 60 + ((friendName.length + friendSign.length) % 35)));

  return res.json({
    score,
    highlights: [
      `${userSign} x ${friendSign}: conversation quality improves with direct framing of expectations.`,
      "High short-term resonance in planning and idea generation.",
      "Conflict risk appears when feedback is delayed too long."
    ],
    advice: `With ${friendName}, set one shared weekly ritual and one explicit repair rule after friction.`
  });
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(publicDir, "index.html"));
});

app.listen(port, "0.0.0.0", () => {
  console.log(`astro-web listening on :${port}`);
});
