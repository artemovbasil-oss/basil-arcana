const app = document.getElementById("app");
const nav = document.getElementById("nav");
const menuButton = document.getElementById("menuButton");
const profileButton = document.getElementById("profileButton");
const profileInitials = document.getElementById("profileInitials");
const themeToggle = document.getElementById("themeToggle");
const themeStorageKey = "astronautica_theme";

const state = {
  authRequired: false,
  authenticated: false,
  authUser: null,
  telegramLoginEnabled: false,
  telegramBotUsername: null,
  telegramBotId: null,
  profile: null,
  profileReady: false,
  friends: [],
  friendInsights: {},
  dashboard: null,
  homePeriod: "week",
  theme: "dark",
  profileEditMode: false
};

menuButton.addEventListener("click", () => {
  nav.classList.toggle("open");
});

profileButton?.addEventListener("click", () => {
  navigate(state.authenticated ? "/profile" : "/login");
});

themeToggle?.addEventListener("click", () => {
  state.theme = state.theme === "dark" ? "light" : "dark";
  applyTheme(state.theme);
});

function navigate(path, { replace = false } = {}) {
  if (replace) {
    window.history.replaceState({}, "", path);
  } else {
    window.history.pushState({}, "", path);
  }
  render();
}

async function fetchJson(url, options) {
  const response = await fetch(url, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(options?.headers || {})
    },
    ...options
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload?.message || payload?.reason || `Request failed: ${response.status}`);
    error.status = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
}

const citySuggestionMeta = new Map();
let citySuggestTimer = null;

function hasProfile(profile = state.profile) {
  return Boolean(profile?.name && profile?.birthDate && profile?.birthTime && profile?.birthCity);
}

function actionPlanEntries(actionPlan, profile, core) {
  const source = Array.isArray(actionPlan) ? actionPlan : [];
  const name = (profile?.name || "User").split(/\s+/).filter(Boolean)[0] || "User";
  const sun = core?.sun || "your solar sign";
  const moon = core?.moon || "your lunar pattern";
  const rising = core?.rising || "your rising behavior";
  const templates = [
    {
      title: "Boundaries Protocol",
      action: source[0] || "Define one non-negotiable boundary for the week.",
      comment: `${name}, this stabilizes ${moon}-driven reactivity and prevents avoidable social energy loss.`
    },
    {
      title: "Execution Cadence",
      action: source[1] || "Convert one emotional reaction into a measurable action.",
      comment: `Use ${sun} motivation as a trigger: translate feeling into one concrete output with a deadline.`
    },
    {
      title: "Weekly Integration",
      action: source[2] || "Review one long-term commitment every Sunday.",
      comment: `This keeps ${rising} presentation aligned with your actual priorities and commitments.`
    }
  ];
  return templates;
}

function getInitials() {
  const first = String(state.authUser?.firstName || "").trim();
  const last = String(state.authUser?.lastName || "").trim();
  const username = String(state.authUser?.username || "").trim();
  const profileName = String(state.profile?.name || "").trim();
  if (first || last) {
    return `${first.slice(0, 1)}${last.slice(0, 1)}`.toUpperCase() || "?";
  }
  if (username) {
    return username.slice(0, 2).toUpperCase();
  }
  if (profileName) {
    return profileName
      .split(/\s+/)
      .slice(0, 2)
      .map((part) => part.slice(0, 1))
      .join("")
      .toUpperCase();
  }
  return "AU";
}

function renderProfileChip() {
  if (!profileButton || !profileInitials) {
    return;
  }
  profileInitials.style.display = "inline-flex";
  profileInitials.textContent = state.authenticated ? getInitials() : "?";
}

function applyTheme(nextTheme) {
  const theme = nextTheme === "light" ? "light" : "dark";
  state.theme = theme;
  document.body.setAttribute("data-theme", theme);
  window.localStorage.setItem(themeStorageKey, theme);
  if (themeToggle) {
    themeToggle.textContent = `Theme: ${theme}`;
  }
}

const zodiacOrder = [
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

const zodiacAssetBaseUrl = "https://basilarcana-assets.b-cdn.net/astronautica";
const zodiacMeta = {
  Aries: {
    file: "aries.png",
    brief: "Direct, fast, and initiative-first. Aries energy works best with clear targets and short execution cycles.",
    natal: "Aries in your core points to action as a regulation mechanism. Progress accelerates when tasks are concrete and time-boxed.",
    compact: "You move fastest when priorities are explicit and execution starts immediately."
  },
  Taurus: {
    file: "taurus.png",
    brief: "Grounded, persistent, and stability-driven. Taurus energy compounds through routine and quality control.",
    natal: "Taurus in your core favors consistency over volatility. Reliable habits produce better outcomes than reactive sprints.",
    compact: "Your strongest results come from stable cadence and low-noise execution."
  },
  Gemini: {
    file: "gemini.png",
    brief: "Curious, adaptive, and communication-heavy. Gemini energy optimizes through learning and information flow.",
    natal: "Gemini in your core rewards structured curiosity. You perform best when you convert ideas into documented next steps.",
    compact: "Clarity and momentum rise when you turn input into concise decisions."
  },
  Cancer: {
    file: "cancer.png",
    brief: "Protective, intuitive, and emotionally precise. Cancer energy is strongest with trusted context and boundaries.",
    natal: "Cancer in your core emphasizes emotional signal quality. Strategic protection of energy improves focus and recovery.",
    compact: "Boundaries and emotional hygiene directly improve your execution quality."
  },
  Leo: {
    file: "leo.png",
    brief: "Creative, visible, and purpose-led. Leo energy grows through ownership and expressive leadership.",
    natal: "Leo in your core needs meaningful output and recognition loops. Confidence rises when contribution is visible and measurable.",
    compact: "You perform best when your role is clear and your output has visible impact."
  },
  Virgo: {
    file: "virgo.png",
    brief: "Analytical, precise, and systems-focused. Virgo energy excels through refinement and process design.",
    natal: "Virgo in your core turns detail into leverage. Small iterative improvements create durable long-term gains.",
    compact: "Your edge is precision: optimize the process, then scale it."
  },
  Libra: {
    file: "libra.png",
    brief: "Relational, balanced, and diplomacy-oriented. Libra energy seeks alignment and fair structure.",
    natal: "Libra in your core improves outcomes through calibrated communication. Explicit agreements reduce friction across teams and relationships.",
    compact: "Better agreements and cleaner communication are your highest ROI moves."
  },
  Scorpio: {
    file: "scorpio.png",
    brief: "Intense, strategic, and transformative. Scorpio energy works deeply and prefers substance over noise.",
    natal: "Scorpio in your core drives focus under pressure. Controlled depth and selective trust are key performance factors.",
    compact: "Depth, discretion, and strategic timing are your strongest operating modes."
  },
  Sagittarius: {
    file: "sagittarius.png",
    brief: "Expansive, exploratory, and meaning-seeking. Sagittarius energy scales through vision and experimentation.",
    natal: "Sagittarius in your core needs direction plus freedom. You gain traction when long-range goals are tied to weekly experiments.",
    compact: "Vision becomes effective when paired with practical weekly execution."
  },
  Capricorn: {
    file: "capricorn.png",
    brief: "Disciplined, structural, and long-term. Capricorn energy compounds through strategy and accountability.",
    natal: "Capricorn in your core favors durable architecture: priorities, milestones, and measurable standards.",
    compact: "Your momentum is strongest with structure, deadlines, and clear ownership."
  },
  Aquarius: {
    file: "aquarius.png",
    brief: "Independent, systemic, and innovation-driven. Aquarius energy seeks better models and future-facing frameworks.",
    natal: "Aquarius in your core performs through systems thinking. Progress spikes when experiments are tied to clear social or product impact.",
    compact: "You unlock speed by improving the system, not just the task."
  },
  Pisces: {
    file: "pisces.png",
    brief: "Imaginative, empathic, and symbolic. Pisces energy senses subtle patterns and emotional undercurrents.",
    natal: "Pisces in your core needs creative channeling and clear boundaries. Ambiguity becomes useful when translated into concrete action.",
    compact: "Intuition works best when captured in simple, testable next steps."
  }
};

const zodiacElements = {
  Aries: "Fire",
  Taurus: "Earth",
  Gemini: "Air",
  Cancer: "Water",
  Leo: "Fire",
  Virgo: "Earth",
  Libra: "Air",
  Scorpio: "Water",
  Sagittarius: "Fire",
  Capricorn: "Earth",
  Aquarius: "Air",
  Pisces: "Water"
};

const zodiacModalities = {
  Aries: "Cardinal",
  Taurus: "Fixed",
  Gemini: "Mutable",
  Cancer: "Cardinal",
  Leo: "Fixed",
  Virgo: "Mutable",
  Libra: "Cardinal",
  Scorpio: "Fixed",
  Sagittarius: "Mutable",
  Capricorn: "Cardinal",
  Aquarius: "Fixed",
  Pisces: "Mutable"
};

const elementNarratives = {
  Fire: {
    drive: "You recharge through movement, challenge, and visible momentum.",
    risk: "When direction is unclear, impatience can replace strategy.",
    practice: "Best practice: choose one bold priority and complete it before opening new loops."
  },
  Earth: {
    drive: "You build confidence through consistency, craft, and measurable progress.",
    risk: "Under pressure, over-control can slow adaptation.",
    practice: "Best practice: lock core routines, then add change in small tested increments."
  },
  Air: {
    drive: "You operate best through perspective, dialogue, and pattern recognition.",
    risk: "Cognitive overload can create diffusion instead of decision.",
    practice: "Best practice: compress thinking into short written decisions and immediate next actions."
  },
  Water: {
    drive: "You navigate by emotional signal quality, intuition, and trust calibration.",
    risk: "Absorbing external stress can blur boundaries and priorities.",
    practice: "Best practice: protect energy first, then move from feeling into one concrete commitment."
  }
};

const modalityNarratives = {
  Cardinal: "Cardinal mode gives you strong initiation power: starting is easy, finishing requires structure.",
  Fixed: "Fixed mode gives endurance and depth: you sustain effort well, but need flexibility checkpoints.",
  Mutable: "Mutable mode gives adaptation and learning speed: you pivot well, but need anchor routines."
};

function resolveZodiacSign(sign) {
  const raw = String(sign || "").trim();
  if (!raw) {
    return "Unknown";
  }
  const match = zodiacOrder.find((item) => item.toLowerCase() === raw.toLowerCase());
  return match || raw;
}

function zodiacDetails(sign) {
  const normalized = resolveZodiacSign(sign);
  const meta = zodiacMeta[normalized];
  if (!meta) {
    return {
      sign: normalized,
      imageUrl: "",
      brief: "Core sign context is currently unavailable.",
      natal: "Sign-specific interpretation is currently unavailable.",
      compact: "No sign summary available yet."
    };
  }
  return {
    sign: normalized,
    imageUrl: `${zodiacAssetBaseUrl}/${meta.file}`,
    brief: meta.brief,
    natal: meta.natal,
    compact: meta.compact,
    element: zodiacElements[normalized] || "Unknown",
    modality: zodiacModalities[normalized] || "Unknown"
  };
}

function zodiacLongRead(sign) {
  const details = zodiacDetails(sign);
  const element = details.element;
  const modality = details.modality;
  const elementData = elementNarratives[element] || {
    drive: "Your sign pattern has a distinct energy profile.",
    risk: "Main risk appears when emotional and strategic signals diverge.",
    practice: "Best practice: convert interpretation into one measurable weekly behavior."
  };
  const modalityLine = modalityNarratives[modality] || "Your modality defines execution rhythm and adaptation speed.";
  return {
    structural: `${details.sign} belongs to ${element} element and ${modality} modality. ${modalityLine}`,
    dynamics: `${elementData.drive} ${elementData.risk}`,
    practical: elementData.practice
  };
}

function zodiacSignalModel(sign) {
  const normalized = resolveZodiacSign(sign);
  const index = Math.max(0, zodiacOrder.indexOf(normalized));
  const focus = 62 + ((index * 7) % 29);
  const adaptability = 54 + ((index * 11) % 33);
  const social = 48 + ((index * 13) % 39);
  return {
    focus: Math.max(40, Math.min(96, focus)),
    adaptability: Math.max(40, Math.min(96, adaptability)),
    social: Math.max(40, Math.min(96, social))
  };
}

function zodiacSignalChips(sign) {
  const details = zodiacDetails(sign);
  return [
    `Element: ${details.element}`,
    `Mode: ${details.modality}`,
    "Core vector: identity",
    "Timing: weekly cadence"
  ];
}

const aspectAngles = [0, 60, 90, 120, 180];
const zodiacIconClasses = {
  Aries: "mdi:zodiac-aries",
  Taurus: "mdi:zodiac-taurus",
  Gemini: "mdi:zodiac-gemini",
  Cancer: "mdi:zodiac-cancer",
  Leo: "mdi:zodiac-leo",
  Virgo: "mdi:zodiac-virgo",
  Libra: "mdi:zodiac-libra",
  Scorpio: "mdi:zodiac-scorpio",
  Sagittarius: "mdi:zodiac-sagittarius",
  Capricorn: "mdi:zodiac-capricorn",
  Aquarius: "mdi:zodiac-aquarius",
  Pisces: "mdi:zodiac-pisces"
};

const planetIconClasses = {
  Sun: "mdi:white-balance-sunny",
  Moon: "mdi:moon-waning-crescent",
  Mercury: "mdi:message-text-fast-outline",
  Venus: "mdi:heart-outline",
  Mars: "mdi:flash-outline",
  Jupiter: "mdi:star-four-points-outline",
  Saturn: "mdi:ring",
  Uranus: "mdi:atom",
  Neptune: "mdi:water-outline",
  Pluto: "mdi:circle-outline"
};

const uiIconClasses = {
  calendar: "mdi:calendar-outline",
  clock: "mdi:clock-outline",
  location: "mdi:map-marker-outline",
  briefcase: "mdi:briefcase-outline",
  group: "mdi:account-group-outline",
  brain: "mdi:head-cog-outline",
  heart: "mdi:heart-outline",
  coins: "mdi:cash-multiple",
  bolt: "mdi:flash-outline",
  shield: "mdi:shield-outline",
  chart: "mdi:chart-line",
  layers: "mdi:layers-outline",
  checklist: "mdi:clipboard-check-outline",
  moonphase: "mdi:moon-waxing-crescent",
  sun: "mdi:white-balance-sunny",
  sunrise: "mdi:weather-sunset-up",
  sunset: "mdi:weather-sunset-down",
  season: "mdi:calendar-star",
  transit: "mdi:orbit"
};

function degreeToRad(degree) {
  return ((degree - 90) * Math.PI) / 180;
}

function pointOnCircle(cx, cy, radius, degree) {
  const rad = degreeToRad(degree);
  return {
    x: cx + Math.cos(rad) * radius,
    y: cy + Math.sin(rad) * radius
  };
}

function stringHash(input) {
  const value = String(input || "");
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }
  return hash;
}

function normalizeAngle(angle) {
  let value = angle % 360;
  if (value < 0) {
    value += 360;
  }
  return value;
}

function shortestAngleDelta(a, b) {
  const diff = Math.abs(a - b) % 360;
  return diff > 180 ? 360 - diff : diff;
}

function zodiacIndex(sign) {
  const normalized = String(sign || "").trim();
  const index = zodiacOrder.indexOf(normalized);
  return index >= 0 ? index : 0;
}

function zodiacIcon(sign) {
  const iconClass = zodiacIconClasses[String(sign || "").trim()] || "mdi:circle-outline";
  return `<iconify-icon icon="${iconClass}" class="astro-icon" aria-hidden="true"></iconify-icon>`;
}

function planetIcon(key) {
  const raw = String(key || "").trim();
  const normalized = raw.charAt(0).toUpperCase() + raw.slice(1).toLowerCase();
  const iconClass = planetIconClasses[normalized] || "mdi:circle-outline";
  return `<iconify-icon icon="${iconClass}" class="astro-icon" aria-hidden="true"></iconify-icon>`;
}

function uiIcon(name) {
  const iconClass = uiIconClasses[String(name || "").trim()] || "mdi:circle-outline";
  return `<iconify-icon icon="${iconClass}" class="astro-icon" aria-hidden="true"></iconify-icon>`;
}

function planetLongitude(planet, index) {
  const signBase = zodiacIndex(planet.sign) * 30;
  const spread = Number.isFinite(planet.house) ? ((planet.house - 1) % 12) * 1.6 : 0;
  const jitter = (stringHash(`${planet.key}:${index}`) % 18) - 9;
  return normalizeAngle(signBase + 15 + spread + jitter);
}

function buildAspectGeometry(planets) {
  const lines = [];
  for (let left = 0; left < planets.length; left += 1) {
    for (let right = left + 1; right < planets.length; right += 1) {
      const delta = shortestAngleDelta(planets[left].longitude, planets[right].longitude);
      const matched = aspectAngles.find((angle) => Math.abs(delta - angle) <= 6);
      if (!matched) {
        continue;
      }
      lines.push({
        left: planets[left],
        right: planets[right],
        matched,
        type: matched === 60 || matched === 120 ? "soft" : "hard",
        styleClass:
          matched === 0
            ? "conjunction"
            : matched === 180
              ? "opposition"
              : matched === 90
                ? "square"
                : matched === 120
                  ? "trine"
                  : "sextile"
      });
    }
  }
  return lines.slice(0, 24);
}

function renderNatalChartSvg(data) {
  const size = 760;
  const center = size / 2;
  const outerRadius = 330;
  const signRadius = 286;
  const houseRadius = 245;
  const aspectRadius = 188;
  const planetRadius = 226;
  const labelRadius = 254;

  const planets = (data.planets || []).slice(0, 10).map((planet, index) => {
    const longitude = planetLongitude(planet, index);
    const dot = pointOnCircle(center, center, planetRadius, longitude);
    const label = pointOnCircle(center, center, labelRadius, longitude);
    return {
      ...planet,
      longitude,
      dot,
      label
    };
  });

  const aspects = buildAspectGeometry(planets);
  const houses = Array.from({ length: 12 }, (_, idx) => idx + 1);
  const signHints = {
    Aries: "Initiation, speed and direct action.",
    Taurus: "Stability, material grounding and consistency.",
    Gemini: "Learning, exchange and adaptability.",
    Cancer: "Emotional security and care patterns.",
    Leo: "Visibility, confidence and creative output.",
    Virgo: "Precision, optimization and craft.",
    Libra: "Balance, diplomacy and partnership logic.",
    Scorpio: "Intensity, depth and strategic focus.",
    Sagittarius: "Exploration, meaning and expansion.",
    Capricorn: "Structure, discipline and long-term goals.",
    Aquarius: "Systems thinking, innovation and autonomy.",
    Pisces: "Imagination, empathy and symbolic thinking."
  };
  const planetHints = {
    Sun: "Core identity, will and conscious direction.",
    Moon: "Emotional regulation, needs and instincts.",
    Mercury: "Thinking process and communication style.",
    Venus: "Attraction, values and relationship style.",
    Mars: "Action, drive and conflict response.",
    Jupiter: "Growth, confidence and opportunity.",
    Saturn: "Limits, duty and long-term mastery.",
    Uranus: "Change, originality and disruption.",
    Neptune: "Ideals, intuition and ambiguity.",
    Pluto: "Power, transformation and deep renewal."
  };
  const asciiLines = ["   .a.   ", "  /aaa\\  ", " (aa aa) ", "  \\aaa/  ", "   `a`   "];
  const asciiStepX = 11.5;
  const asciiStepY = 16;
  const maxLen = Math.max(...asciiLines.map((line) => line.length));
  const asciiStartX = center - ((maxLen - 1) * asciiStepX) / 2;
  const asciiStartY = center - ((asciiLines.length - 1) * asciiStepY) / 2 + 2;
  const asciiGlyphs = asciiLines
    .map((line, row) =>
      line
        .split("")
        .map((char, col) => {
          if (char === " ") {
            return "";
          }
          const x = asciiStartX + col * asciiStepX;
          const y = asciiStartY + row * asciiStepY;
          const drift = ((row + 1) * (col + 2)) % 5;
          return `<text class="ascii-char" data-drift="${drift}" x="${x}" y="${y}" text-anchor="middle" dominant-baseline="middle">${char}</text>`;
        })
        .join("")
    )
    .join("");

  return `
    <div class="natal-graphic">
      <svg class="natal-chart-svg" viewBox="0 0 ${size} ${size}" role="img" aria-label="Natal chart wheel">
        <circle class="natal-ring" cx="${center}" cy="${center}" r="${outerRadius}" />
        <circle class="natal-ring" cx="${center}" cy="${center}" r="${houseRadius}" />
        <circle class="natal-ring-inner" cx="${center}" cy="${center}" r="${aspectRadius}" />

        ${houses
          .map((house) => {
            const degree = (house - 1) * 30;
            const lineStart = pointOnCircle(center, center, aspectRadius, degree);
            const lineEnd = pointOnCircle(center, center, outerRadius, degree);
            const houseLabel = pointOnCircle(center, center, 214, degree + 14);
            return `
              <line class="natal-house-line" x1="${lineStart.x}" y1="${lineStart.y}" x2="${lineEnd.x}" y2="${lineEnd.y}" />
              <text class="natal-house-label" x="${houseLabel.x}" y="${houseLabel.y}" text-anchor="middle" dominant-baseline="middle">${house}</text>
            `;
          })
          .join("")}

        ${zodiacOrder
          .map((sign, index) => {
            const degree = index * 30 + 15;
            const signPoint = pointOnCircle(center, center, signRadius, degree);
            const hint = signHints[sign] || "Core archetypal zodiac pattern.";
            return `
              <text class="natal-sign-label" x="${signPoint.x}" y="${signPoint.y}" text-anchor="middle" dominant-baseline="middle">
                <title>${sign}: ${hint}</title>
                ${sign.slice(0, 3).toUpperCase()}
              </text>
            `;
          })
          .join("")}

        ${aspects
          .map((aspect) => {
            const start = pointOnCircle(center, center, aspectRadius, aspect.left.longitude);
            const end = pointOnCircle(center, center, aspectRadius, aspect.right.longitude);
            return `<line class="natal-aspect-line ${aspect.type} ${aspect.styleClass}" x1="${start.x}" y1="${start.y}" x2="${end.x}" y2="${end.y}" />`;
          })
          .join("")}

        <circle class="natal-center-core" cx="${center}" cy="${center}" r="56" />
        <g class="natal-ascii-logo" data-center-x="${center}" data-center-y="${center}">
          ${asciiGlyphs}
        </g>

        ${planets
          .map((planet) => {
            const guide = pointOnCircle(center, center, aspectRadius + 8, planet.longitude);
            const symbol = String(planet.key || "").slice(0, 2).toUpperCase();
            const hint = planetHints[planet.key] || `${planet.key}: important psychological and behavioral theme.`;
            return `
              <line class="natal-planet-line" x1="${guide.x}" y1="${guide.y}" x2="${planet.dot.x}" y2="${planet.dot.y}" />
              <circle class="natal-planet-dot" cx="${planet.dot.x}" cy="${planet.dot.y}" r="4.2">
                <title>${hint}</title>
              </circle>
              <text class="natal-planet-label" x="${planet.label.x}" y="${planet.label.y}" text-anchor="middle" dominant-baseline="middle">
                <title>${hint}</title>
                ${symbol}
              </text>
            `;
          })
          .join("")}
      </svg>
      <p class="muted">Outer ring: signs. Inner wheel: houses. Chords: major aspects. Markers: planetary placements.</p>
    </div>
  `;
}

function bindNatalAsciiLogo() {
  const svg = document.querySelector(".natal-chart-svg");
  if (!svg) {
    return;
  }
  const logo = svg.querySelector(".natal-ascii-logo");
  const chars = Array.from(svg.querySelectorAll(".ascii-char"));
  if (!logo || !chars.length) {
    return;
  }
  const centerX = Number(logo.getAttribute("data-center-x")) || 380;
  const centerY = Number(logo.getAttribute("data-center-y")) || 380;
  const move = (event) => {
    const rect = svg.getBoundingClientRect();
    const viewBox = svg.viewBox.baseVal;
    const ratioX = viewBox && rect.width ? viewBox.width / rect.width : 1;
    const ratioY = viewBox && rect.height ? viewBox.height / rect.height : 1;
    const mouseX = (event.clientX - rect.left) * ratioX;
    const mouseY = (event.clientY - rect.top) * ratioY;
    const normX = (mouseX - centerX) / 180;
    const normY = (mouseY - centerY) / 180;
    chars.forEach((char, index) => {
      const drift = Number(char.getAttribute("data-drift")) || 0;
      const amp = 0.55 + drift * 0.22;
      const phase = Math.sin((index + 1) * 0.7);
      const dx = Math.max(-2, Math.min(2, normX * amp + phase * 0.12));
      const dy = Math.max(-2, Math.min(2, normY * amp - phase * 0.1));
      char.setAttribute("transform", `translate(${dx.toFixed(2)}, ${dy.toFixed(2)})`);
    });
  };
  const reset = () => {
    chars.forEach((char) => char.removeAttribute("transform"));
  };
  svg.addEventListener("mousemove", move);
  svg.addEventListener("mouseleave", reset);
}

function shell({ eyebrow, title, intro, primaryCta, secondaryCta, rightPanel, body }) {
  return `
    <section class="hero">
      <article class="card">
        <span class="eyebrow">${eyebrow}</span>
        <h1>${title}</h1>
        <p>${intro}</p>
        <div class="hero-actions">
          <a class="btn primary" href="${primaryCta.href}">${primaryCta.label}</a>
          <a class="btn ghost" href="${secondaryCta.href}">${secondaryCta.label}</a>
        </div>
      </article>
      <aside class="card">
        ${rightPanel}
      </aside>
    </section>
    ${body}
  `;
}

function energyPointLabel(period, index) {
  if (period === "week") {
    return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index] || `D${index + 1}`;
  }
  if (period === "month") {
    return `${index + 1}`;
  }
  return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][index] || `M${index + 1}`;
}

function daysInCurrentMonth() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
}

function todayIndexForPeriod(period, length) {
  const now = new Date();
  if (period === "year") {
    return Math.max(0, Math.min(length - 1, now.getMonth()));
  }
  if (period === "month") {
    return Math.max(0, Math.min(length - 1, now.getDate() - 1));
  }
  const day = now.getDay();
  const mondayBased = day === 0 ? 6 : day - 1;
  return Math.max(0, Math.min(length - 1, mondayBased));
}

function todayMarkerValue(period) {
  return String(new Date().getDate());
}

function starPoints(cx, cy, outer = 4.2, inner = 2.1) {
  const points = [];
  for (let idx = 0; idx < 8; idx += 1) {
    const angle = (Math.PI / 4) * idx - Math.PI / 2;
    const radius = idx % 2 === 0 ? outer : inner;
    points.push(`${cx + Math.cos(angle) * radius},${cy + Math.sin(angle) * radius}`);
  }
  return points.join(" ");
}

function buildEnergySeries(dashboard, period) {
  const serverSeries = dashboard?.periodForecast?.series;
  if (
    serverSeries
    && serverSeries.period === period
    && Array.isArray(serverSeries.values)
    && serverSeries.values.length
  ) {
    const values = serverSeries.values.map((value) => Math.max(0, Math.min(100, Number(value) || 0)));
    const peak = Math.max(...values);
    const dip = Math.min(...values);
    const labels = Array.isArray(serverSeries.labels) && serverSeries.labels.length === values.length
      ? serverSeries.labels.map((label) => String(label || ""))
      : values.map((_, index) => energyPointLabel(period, index));
    return {
      values,
      labels,
      peakIndex: Number.isFinite(serverSeries.peakIndex) ? serverSeries.peakIndex : values.indexOf(peak),
      dipIndex: Number.isFinite(serverSeries.dipIndex) ? serverSeries.dipIndex : values.indexOf(dip),
      source: serverSeries.source || "transit-derived"
    };
  }
  const profile = dashboard?.profile;
  const intensity = Number(dashboard?.periodForecast?.intensity || 50);
  const count = period === "year" ? 12 : period === "month" ? daysInCurrentMonth() : 7;
  const baseSeed = stringHash(`${profile?.name || "anon"}:${profile?.birthDate || "0000-00-00"}:${period}:${intensity}`);
  const baseline = Math.max(28, Math.min(82, Number(intensity) || 50));
  const values = Array.from({ length: count }, (_, index) => {
    const waveA = Math.sin((index + 1) * 0.92 + (baseSeed % 9)) * 14;
    const waveB = Math.cos((index + 1) * 0.37 + (baseSeed % 17)) * 8;
    const noise = (stringHash(`${baseSeed}:${index}`) % 11) - 5;
    const point = Math.max(8, Math.min(96, Math.round(baseline + waveA + waveB + noise)));
    return point;
  });
  const peak = Math.max(...values);
  const dip = Math.min(...values);
  return {
    values,
    peakIndex: values.indexOf(peak),
    dipIndex: values.indexOf(dip),
    labels: values.map((_, index) => energyPointLabel(period, index)),
    source: "synthetic-fallback"
  };
}

function buildSmoothPath(points) {
  if (!points.length) {
    return "";
  }
  if (points.length === 1) {
    return `M ${points[0].x} ${points[0].y}`;
  }
  if (points.length === 2) {
    return `M ${points[0].x} ${points[0].y} L ${points[1].x} ${points[1].y}`;
  }
  let path = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i += 1) {
    const p0 = points[i - 1] || points[i];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[i + 2] || p2;
    const tension = 0.18;
    const cp1x = p1.x + ((p2.x - p0.x) * tension) / 3;
    const cp1y = p1.y + ((p2.y - p0.y) * tension) / 3;
    const cp2x = p2.x - ((p3.x - p1.x) * tension) / 3;
    const cp2y = p2.y - ((p3.y - p1.y) * tension) / 3;
    path += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`;
  }
  return path;
}

function isMobileViewport() {
  return Boolean(typeof window !== "undefined" && window.matchMedia && window.matchMedia("(max-width: 760px)").matches);
}

function visibleLabelIndexes(length, period) {
  if (period === "week") {
    return Array.from({ length }, (_, idx) => idx);
  }
  if (period === "year") {
    return Array.from({ length }, (_, idx) => idx);
  }
  const result = [];
  for (let idx = 0; idx < length; idx += 5) {
    result.push(idx);
  }
  if (!result.includes(length - 1)) {
    result.push(length - 1);
  }
  return result;
}

function renderEnergyChart(dashboard, period) {
  const series = buildEnergySeries(dashboard, period);
  const width = 980;
  const height = 238;
  const padX = 18;
  const padY = 18;
  const chartBottom = height - 38;
  const stepX = (width - padX * 2) / Math.max(1, series.values.length - 1);
  const toY = (value) => chartBottom - (value / 100) * (chartBottom - padY);
  const points = series.values.map((value, index) => ({
    x: padX + index * stepX,
    y: toY(value),
    value,
    label: series.labels[index]
  }));
  const linePath = buildSmoothPath(points);
  const peakPoint = points[series.peakIndex];
  const dipPoint = points[series.dipIndex];
  const labelIndexes = visibleLabelIndexes(points.length, period);
  const todayIndex = todayIndexForPeriod(period, points.length);
  const todayPoint = points[todayIndex];
  const todayValue = todayMarkerValue(period);

  const todayBadgeY = todayPoint.y;
  const todayBadgeRadius = period === "year" ? 11 : 10;
  return `
    <div class="energy-chart-wrap">
      <svg
        class="energy-chart"
        viewBox="0 0 ${width} ${height}"
        role="img"
        aria-label="Energy trend chart"
        data-min-x="${padX}"
        data-max-x="${width - padX}"
      >
        <line class="energy-axis" x1="${padX}" y1="${chartBottom}" x2="${width - padX}" y2="${chartBottom}" />
        ${points
          .map((point) => `<line class="energy-v-grid" x1="${point.x}" y1="${padY}" x2="${point.x}" y2="${chartBottom}" />`)
          .join("")}
        <line class="energy-hover-line" x1="${padX}" y1="${padY}" x2="${padX}" y2="${chartBottom}" />
        <path class="energy-line" d="${linePath}" />
        ${points
          .map((point, index) => {
            const tone = index === series.peakIndex ? "peak" : index === series.dipIndex ? "dip" : "neutral";
            const size = tone === "neutral" ? 6 : 8.4;
            return `<polygon class="energy-star ${tone}" points="${starPoints(point.x, point.y, size, size * 0.46)}" />`;
          })
          .join("")}
        <text class="energy-label peak" x="${peakPoint.x}" y="${peakPoint.y - 10}" text-anchor="middle">▲ ${peakPoint.value}</text>
        <text class="energy-label dip" x="${dipPoint.x}" y="${dipPoint.y + 18}" text-anchor="middle">▼ ${dipPoint.value}</text>
        <line class="energy-today-line" x1="${todayPoint.x}" y1="${padY}" x2="${todayPoint.x}" y2="${chartBottom}" />
        <circle class="energy-today-badge" cx="${todayPoint.x}" cy="${todayBadgeY}" r="${todayBadgeRadius}" />
        <text class="energy-today-text" x="${todayPoint.x}" y="${todayBadgeY + 0.2}" text-anchor="middle" dominant-baseline="middle">${todayValue}</text>
        ${labelIndexes
          .map((index) => {
            const point = points[index];
            return `<text class="energy-x-label" x="${point.x}" y="${height - 10}" text-anchor="middle">${point.label}</text>`;
          })
          .join("")}
      </svg>
      <div class="energy-legend">
        <span><i class="dot peak"></i> Peak energy</span>
        <span><i class="dot dip"></i> Energy dip</span>
      </div>
    </div>
  `;
}

function renderEnergyCards(dashboard, period) {
  const intensity = Number(dashboard?.periodForecast?.intensity || 50);
  const series = buildEnergySeries(dashboard, period);
  const todayIndex = todayIndexForPeriod(period, series.values.length);
  const todayLabel = series.labels[todayIndex] || "Today";
  const todayValue = series.values[todayIndex] || 0;
  const peakValue = series.values[series.peakIndex] || 0;
  const dipValue = series.values[series.dipIndex] || 0;
  const periodLabel = period === "year" ? "Year" : period === "month" ? "Month" : "Week";
  return `
    <div class="energy-cards">
      <article class="energy-card">
        <span>Today (${todayLabel})</span>
        <strong>${todayValue}</strong>
      </article>
      <article class="energy-card">
        <span>Peak</span>
        <strong class="peak">${peakValue}</strong>
      </article>
      <article class="energy-card">
        <span>Dip</span>
        <strong class="dip">${dipValue}</strong>
      </article>
      <article class="energy-card">
        <span>${periodLabel} intensity</span>
        <strong>${intensity}/100</strong>
      </article>
    </div>
  `;
}

function transitionSeries(dashboard, period) {
  const series = dashboard?.periodForecast?.series;
  if (!series || series.period !== period || !Array.isArray(series.transits)) {
    return [];
  }
  return series.transits;
}

function bodyCycleData(dashboard, period) {
  const transits = transitionSeries(dashboard, period);
  const periodSize = period === "year" ? 12 : period === "month" ? daysInCurrentMonth() : 7;
  const idx = todayIndexForPeriod(period, periodSize);
  const current = transits[idx] || {};
  const signs = [current?.sun?.sign || dashboard?.natalCore?.sun, current?.moon?.sign || dashboard?.natalCore?.moon, current?.rising?.sign || dashboard?.natalCore?.rising];
  const realAngles = [current?.sun?.angle, current?.moon?.angle, current?.rising?.angle];
  const names = ["Sun", "Moon", "Rising"];
  return names.map((name, i) => {
    const sign = String(signs[i] || "Unknown");
    const fallback = ((zodiacIndex(sign) * 30 + 15) % 360 + 360) % 360;
    const angle = Number.isFinite(realAngles[i]) ? realAngles[i] : fallback;
    const value = buildEnergySeries(dashboard, period).values[(idx + i * 2) % Math.max(1, periodSize)] || 50;
    return { name, sign, angle, value };
  });
}

function pointFromAngle(cx, cy, radius, degrees) {
  const a = ((degrees - 90) * Math.PI) / 180;
  return { x: cx + Math.cos(a) * radius, y: cy + Math.sin(a) * radius };
}

function renderCosmicStatePanel(dashboard, period) {
  const bodies = bodyCycleData(dashboard, period);
  const center = { x: 120, y: 110 };
  const rings = [36, 58, 80];
  const colors = ["#f3f3f3", "#9d9d9d", "#5f5f5f"];
  return `
    <article class="astro-viz-card">
      <h3>Current sky state</h3>
      <svg class="astro-viz-svg" viewBox="0 0 420 220" role="img" aria-label="Current planetary state">
        <g class="astro-viz-core">
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="${rings[2]}" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="${rings[1]}" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="${rings[0]}" />
          ${bodies
            .map((body, i) => {
              const p = pointFromAngle(center.x, center.y, rings[i], body.angle);
              return `
                <circle class="astro-viz-node" cx="${p.x}" cy="${p.y}" r="${i === 0 ? 5.6 : 4.8}" style="fill:${colors[i]}" />
                <line class="astro-viz-ray" x1="${center.x}" y1="${center.y}" x2="${p.x}" y2="${p.y}" />
              `;
            })
            .join("")}
        </g>
        <g transform="translate(250 26)">
          ${bodies
            .map(
              (body, i) => `
                <text class="astro-viz-label" x="0" y="${24 + i * 54}">
                  ${zodiacIcon(body.sign)} ${body.name} · ${body.sign}
                </text>
                <text class="astro-viz-value" x="0" y="${44 + i * 54}">${Math.round(body.value)}/100 phase energy</text>
              `
            )
            .join("")}
        </g>
      </svg>
    </article>
  `;
}

function renderCyclePanel(dashboard, period) {
  const transits = transitionSeries(dashboard, period);
  if (transits.length) {
    const width = 420;
    const height = 220;
    const center = { x: 136, y: 108 };
    const bodies = [
      { key: "sun", label: "Sun", radius: 64, color: "#f1f1f1" },
      { key: "moon", label: "Moon", radius: 48, color: "#9c9c9c" },
      { key: "rising", label: "Rising", radius: 34, color: "#5f5f5f" }
    ];
    const toPoly = (body) =>
      transits
        .map((step) => {
          const raw = Number(step?.[body.key]?.angle);
          const angle = Number.isFinite(raw) ? raw : zodiacIndex(step?.[body.key]?.sign) * 30;
          const p = pointFromAngle(center.x, center.y, body.radius, angle);
          return `${p.x},${p.y}`;
        })
        .join(" ");
    const first = transits[0] || {};
    const last = transits[transits.length - 1] || {};
    return `
      <article class="astro-viz-card">
        <h3>Lifecycle through ${period}</h3>
        <svg class="astro-viz-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="Planet lifecycle">
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="72" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="56" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="40" />
          ${bodies
            .map(
              (body) => `
                <polyline class="astro-viz-orbit ${body.key}" points="${toPoly(body)}" style="stroke:${body.color}" />
              `
            )
            .join("")}
          <g transform="translate(246 30)">
            ${bodies
              .map((body, i) => {
                const startSign = first?.[body.key]?.sign || "Unknown";
                const endSign = last?.[body.key]?.sign || "Unknown";
                return `
                  <text class="astro-viz-label" x="0" y="${24 + i * 54}">${body.label}</text>
                  <text class="astro-viz-value" x="0" y="${44 + i * 54}">${startSign} → ${endSign}</text>
                `;
              })
              .join("")}
          </g>
        </svg>
      </article>
    `;
  }
  const series = buildEnergySeries(dashboard, period);
  const values = series.values;
  const avg = Math.round(values.reduce((sum, v) => sum + v, 0) / Math.max(1, values.length));
  const peak = values[series.peakIndex] || 0;
  const dip = values[series.dipIndex] || 0;
  const width = 420;
  const height = 220;
  const y = (value) => 182 - (value / 100) * 140;
  const step = (width - 54) / Math.max(1, values.length - 1);
  const pts = values.map((v, i) => `${28 + i * step},${y(v)}`).join(" ");
  const markerX = 28 + todayIndexForPeriod(period, values.length) * step;
  const duration = period === "week" ? 7 : period === "month" ? 12 : 18;
  return `
    <article class="astro-viz-card">
      <h3>Cycle through ${period}</h3>
      <svg class="astro-viz-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="Planetary cycle">
        <polyline class="astro-viz-cycle-line" points="${pts}" />
        <line class="astro-viz-now-line" x1="${markerX}" y1="24" x2="${markerX}" y2="186" />
        <circle class="astro-viz-now-dot" cx="${markerX}" cy="${y(values[todayIndexForPeriod(period, values.length)] || 50)}" r="5" />
        <g class="astro-viz-sweep" style="animation-duration:${duration}s">
          <line x1="28" y1="186" x2="${width - 26}" y2="186" />
        </g>
        <text class="astro-viz-stat" x="28" y="208">avg ${avg}</text>
        <text class="astro-viz-stat" x="140" y="208">peak ${peak}</text>
        <text class="astro-viz-stat" x="260" y="208">dip ${dip}</text>
      </svg>
    </article>
  `;
}

function renderAstroVizRow(dashboard, period) {
  return `
    <div class="astro-viz-row">
      ${renderCosmicStatePanel(dashboard, period)}
      ${renderCyclePanel(dashboard, period)}
    </div>
  `;
}

function bindEnergyChartInteractions() {
  document.querySelectorAll(".energy-chart").forEach((svg) => {
    const hoverLine = svg.querySelector(".energy-hover-line");
    if (!hoverLine) {
      return;
    }
    const minX = Number(svg.getAttribute("data-min-x")) || 18;
    const maxX = Number(svg.getAttribute("data-max-x")) || 962;
    const move = (event) => {
      const rect = svg.getBoundingClientRect();
      const viewBox = svg.viewBox.baseVal;
      const ratio = viewBox && rect.width ? viewBox.width / rect.width : 1;
      const rawX = (event.clientX - rect.left) * ratio;
      const x = Math.max(minX, Math.min(maxX, rawX));
      hoverLine.setAttribute("x1", String(x));
      hoverLine.setAttribute("x2", String(x));
      hoverLine.classList.add("visible");
    };
    const hide = () => hoverLine.classList.remove("visible");
    svg.addEventListener("mousemove", move);
    svg.addEventListener("mouseenter", move);
    svg.addEventListener("mouseleave", hide);
    svg.addEventListener("touchstart", hide, { passive: true });
  });
}

function buildTodayAstroData(profile, dashboard) {
  const now = new Date();
  const day = now.getUTCDate();
  const moonAge = ((now.getTime() / 86400000) + 4.867) % 29.53059;
  const illumination = Math.round((1 - Math.cos((2 * Math.PI * moonAge) / 29.53059)) * 50);
  const moonPhase = moonAge < 1
    ? "New Moon"
    : moonAge < 7.4
      ? "Waxing"
      : moonAge < 8.9
        ? "First Quarter"
        : moonAge < 14.8
          ? "Waxing Gibbous"
          : moonAge < 16.2
            ? "Full Moon"
            : moonAge < 22.1
              ? "Waning"
              : moonAge < 23.6
                ? "Last Quarter"
                : "Waning Crescent";
  const seasonSign = zodiacOrder[(now.getUTCMonth() + 11) % zodiacOrder.length] || "Unknown";
  const transitIntensity = Number(dashboard?.periodForecast?.intensity || 50);
  const latitude = Number(profile?.latitude);
  const daylight = Number.isFinite(latitude)
    ? Math.round(12 + Math.sin(((day + latitude) / 58) * Math.PI) * 2.1)
    : 12;

  return {
    dateLabel: now.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }),
    moonPhase,
    illumination,
    seasonSign,
    daylightHours: Math.max(6, Math.min(18, daylight)),
    transitIntensity
  };
}

function renderTodayAstroPanel(profile, dashboard) {
  const info = buildTodayAstroData(profile, dashboard);
  return `
    <div class="today-panel">
      <h2>${info.dateLabel}</h2>
      <div class="today-grid">
        <div class="today-item">
          <span>${uiIcon("moonphase")} Moon</span>
          <strong>${info.moonPhase}</strong>
        </div>
        <div class="today-item">
          <span>${uiIcon("sun")} Illumination</span>
          <strong>${info.illumination}%</strong>
        </div>
        <div class="today-item">
          <span>${uiIcon("season")} Solar Season</span>
          <strong>${zodiacIcon(info.seasonSign)} ${info.seasonSign}</strong>
        </div>
        <div class="today-item">
          <span>${uiIcon("sunrise")} Daylight</span>
          <strong>${info.daylightHours}h</strong>
        </div>
        <div class="today-item">
          <span>${uiIcon("transit")} Transit Tone</span>
          <strong>${info.transitIntensity}/100</strong>
        </div>
      </div>
      <p class="muted">${dashboard?.daily?.focus || ""}</p>
    </div>
  `;
}

function renderNatalZodiacSection(sign) {
  const details = zodiacDetails(sign);
  const deep = zodiacLongRead(sign);
  const signLabel = details.sign === "Unknown" ? "Sign" : details.sign;
  return `
    <section class="section" id="natal-zodiac-sign">
      <article class="route-card content-panel premium-panel zodiac-natal-card">
        <span class="premium-kicker">Archetype</span>
        <h2>${signLabel} Profile</h2>
        <div class="zodiac-sign-image-wrap zodiac-sign-image-wrap-natal">
          ${
            details.imageUrl
              ? `<img class="zodiac-sign-image zodiac-sign-image-natal" src="${details.imageUrl}" alt="${signLabel} zodiac illustration" loading="lazy" decoding="async" />`
              : `<div class="zodiac-sign-fallback">${zodiacIcon(signLabel)} ${signLabel}</div>`
          }
        </div>
        <p class="zodiac-natal-lead">${details.natal}</p>
        <p class="zodiac-natal-secondary">${deep.structural}</p>
        <p class="zodiac-natal-secondary">${deep.dynamics}</p>
        <p class="zodiac-natal-secondary"><strong>Operational note:</strong> ${deep.practical}</p>
      </article>
    </section>
  `;
}

function renderHomeZodiacCompact(sign) {
  const details = zodiacDetails(sign);
  const deep = zodiacLongRead(sign);
  const chips = zodiacSignalChips(sign);
  const signals = zodiacSignalModel(sign);
  const signLabel = details.sign === "Unknown" ? "Sign" : details.sign;
  return `
    <section class="section">
      <article class="card zodiac-compact-card">
        <span class="eyebrow">Zodiac focus</span>
        <h2>${signLabel} Signal</h2>
        <div class="zodiac-sign-panel compact">
          <div class="zodiac-sign-image-wrap compact">
            ${
              details.imageUrl
                ? `<img class="zodiac-sign-image compact" src="${details.imageUrl}" alt="${signLabel} zodiac illustration" loading="lazy" decoding="async" />`
                : `<div class="zodiac-sign-fallback">${zodiacIcon(signLabel)} ${signLabel}</div>`
            }
          </div>
          <div class="zodiac-sign-copy zodiac-home-copy">
            <p>${details.compact}</p>
            <p>${deep.structural}</p>
            <div class="zodiac-chip-row">
              ${chips.map((chip) => `<span class="zodiac-chip">${chip}</span>`).join("")}
            </div>
            <div class="zodiac-signal-card" role="img" aria-label="${signLabel} signal profile">
              <div class="zodiac-signal-row">
                <span>Focus</span>
                <div class="zodiac-signal-track"><i style="width:${signals.focus}%"></i></div>
              </div>
              <div class="zodiac-signal-row">
                <span>Adaptability</span>
                <div class="zodiac-signal-track"><i style="width:${signals.adaptability}%"></i></div>
              </div>
              <div class="zodiac-signal-row">
                <span>Social clarity</span>
                <div class="zodiac-signal-track"><i style="width:${signals.social}%"></i></div>
              </div>
            </div>
          </div>
        </div>
      </article>
    </section>
  `;
}

function renderFriendZodiacSnippet(sign) {
  const details = zodiacDetails(sign);
  const deep = zodiacLongRead(sign);
  const signLabel = details.sign === "Unknown" ? "Sign" : details.sign;
  return `
    <article class="friend-sign-panel">
      <div class="friend-sign-image-wrap">
        ${
          details.imageUrl
            ? `<img class="friend-sign-image" src="${details.imageUrl}" alt="${signLabel} zodiac illustration" loading="lazy" decoding="async" />`
            : `<div class="zodiac-sign-fallback">${zodiacIcon(signLabel)} ${signLabel}</div>`
        }
      </div>
      <div class="friend-sign-copy">
        <h3>${signLabel}</h3>
        <p>${details.brief}</p>
        <p>${deep.practical}</p>
      </div>
    </article>
  `;
}

function normalizedFriendScore(score, period) {
  const value = Math.max(0, Math.min(100, Number(score) || 0));
  if (period === "month") {
    return Math.max(0, Math.min(100, value - 3 + ((value % 5) - 2)));
  }
  if (period === "year") {
    return Math.max(0, Math.min(100, value - 6 + ((value % 7) - 3)));
  }
  return value;
}

function renderFriendGauge(score) {
  const pct = Math.max(0, Math.min(100, Math.round(score)));
  const tone = pct >= 70 ? "high" : pct <= 30 ? "low" : "mid";
  const radius = 15;
  const c = 2 * Math.PI * radius;
  const progress = c - (pct / 100) * c;
  return `
    <svg class="friend-gauge" viewBox="0 0 42 42" role="img" aria-label="Compatibility ${pct}%">
      <circle class="friend-gauge-bg" cx="21" cy="21" r="${radius}" />
      <circle class="friend-gauge-fill ${tone}" cx="21" cy="21" r="${radius}" stroke-dasharray="${c}" stroke-dashoffset="${progress}" />
      <text class="friend-gauge-text ${tone}" x="21" y="22" text-anchor="middle" dominant-baseline="middle">${pct}%</text>
    </svg>
  `;
}

function renderFriendAccordion(friend, { expanded = false } = {}) {
  const score = Math.max(0, Math.min(100, Math.round(Number(friend?.score) || 0)));
  const highlights = Array.isArray(friend?.highlights) ? friend.highlights : [];
  const domains = Array.isArray(friend?.domains) ? friend.domains : [];
  const detailId = `friend-detail-${String(friend?.id || friend?.friendName || "friend").replace(/[^a-z0-9_-]/gi, "_")}`;
  return `
    <article class="friend-accordion ${expanded ? "open" : ""}" data-id="${friend.id || ""}">
      <button class="friend-accordion-trigger" type="button" aria-expanded="${expanded ? "true" : "false"}" aria-controls="${detailId}">
        <div class="friend-row">
          <div>
            <strong>${friend.friendName}</strong>
            <p>${zodiacIcon(friend.friendSign)} ${friend.friendSign} · ${friend.trend || "stable"}</p>
          </div>
          <div class="friend-score">
            ${renderFriendGauge(score)}
          </div>
        </div>
      </button>
      <div id="${detailId}" class="friend-accordion-body">
        <p class="friend-premium-note">${friend.note || "Compatibility insight will appear after analysis."}</p>
        <p class="friend-rationale">${friend.rationale || ""}</p>
        ${renderFriendZodiacSnippet(friend.friendSign)}
        <div class="friend-domain-grid">
          ${domains
            .map(
              (domain) => `
                <article class="friend-domain-card">
                  <span>${domain.label}</span>
                  <strong>${Math.max(0, Math.min(100, Number(domain.score) || 0))}%</strong>
                  <p>${domain.comment || ""}</p>
                </article>
              `
            )
            .join("")}
        </div>
        <ul class="bullet-list friend-highlights">
          ${highlights.map((item) => `<li>${item}</li>`).join("")}
        </ul>
        <p>${friend.advice || ""}</p>
        <div class="friend-actions">
          <button class="btn ghost js-share-friend" type="button" data-name="${friend.friendName}" data-sign="${friend.friendSign}" data-score="${score}">Share with friend</button>
        </div>
      </div>
    </article>
  `;
}

function renderFriendsBlock(dashboard, period) {
  const dynamicFriends = Array.isArray(dashboard?.friendsDynamic) ? dashboard.friendsDynamic : [];
  if (!dynamicFriends.length) {
    return `<p class="muted">No friends yet. Add friends to unlock dynamic compatibility tracking.</p>`;
  }
  return `<div class="friends-accordion-list">${dynamicFriends.map((friend) => renderFriendAccordion(friend)).join("")}</div>`;
}

function renderForecastSummary(dashboard, period) {
  const periodLabel = period === "year" ? "Year" : period === "month" ? "Month" : "Week";
  const intensity = Number(dashboard?.periodForecast?.intensity || 0);
  const detailBlock = isMobileViewport() ? renderEnergyCards(dashboard, period) : renderEnergyChart(dashboard, period);
  return `
    <p><strong>${periodLabel} intensity: ${intensity}/100.</strong> ${dashboard?.periodForecast?.summary || ""}</p>
    ${detailBlock}
    ${renderAstroVizRow(dashboard, period)}
  `;
}

function updateHomeDynamicBlocks(dashboard, period, { animate = false } = {}) {
  const forecastBlock = document.getElementById("homeForecastBlock");
  const friendsBlock = document.getElementById("homeFriendsBlock");
  if (forecastBlock) {
    if (animate) {
      forecastBlock.classList.remove("swap-in");
      void forecastBlock.offsetWidth;
      forecastBlock.classList.add("swap-in");
    }
    forecastBlock.innerHTML = renderForecastSummary(dashboard, period);
  }
  if (friendsBlock) {
    if (animate) {
      friendsBlock.classList.remove("swap-in");
      void friendsBlock.offsetWidth;
      friendsBlock.classList.add("swap-in");
    }
    friendsBlock.innerHTML = renderFriendsBlock(dashboard, period);
    bindFriendAccordionInteractions(friendsBlock);
    bindShareFriendButtons(friendsBlock);
  }
  document.querySelectorAll(".js-period").forEach((button) => {
    const buttonPeriod = button.getAttribute("data-period");
    button.classList.toggle("is-active", buttonPeriod === period);
  });
  bindEnergyChartInteractions();
}

function bindHomePeriodHandlers() {
  document.querySelectorAll(".js-period").forEach((button) => {
    button.addEventListener("click", async () => {
      const nextPeriod = button.getAttribute("data-period");
      if (!nextPeriod || nextPeriod === state.homePeriod) {
        return;
      }
      state.homePeriod = nextPeriod;
      try {
        const payload = await fetchJson(`/api/dashboard?period=${encodeURIComponent(state.homePeriod)}`);
        state.dashboard = payload.dashboard;
        updateHomeDynamicBlocks(state.dashboard, state.homePeriod, { animate: true });
      } catch (error) {
        if (error.status === 401) {
          await refreshAuthState();
          navigate("/login", { replace: true });
          return;
        }
        const forecastBlock = document.getElementById("homeForecastBlock");
        if (forecastBlock) {
          forecastBlock.innerHTML = `<p class="muted">Failed to update forecast: ${error.message}</p>`;
        }
      }
    });
  });
}

function homeViewLoading() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Dashboard</span>
        <h1>Astronautica</h1>
        <p id="homeStatus">Loading personal dashboard...</p>
      </article>
    </section>
  `;
}

function renderHomeDashboard(dashboard) {
  const period = dashboard.periodForecast?.period || state.homePeriod;
  const forecastSummary = renderForecastSummary(dashboard, period);
  const friendsBlock = renderFriendsBlock(dashboard, period);
  const profileName = String(dashboard.profile?.name || "").trim();
  const displayName = profileName.split(/\s+/).filter(Boolean)[0] || profileName || "User";
  const nameClass = displayName.length > 18 ? "mask-fade" : "name-plain";
  const todayPanel = renderTodayAstroPanel(dashboard.profile, dashboard);
  const chips = [
    `${zodiacIcon(dashboard.natalCore.sun)} Sun: ${dashboard.natalCore.sun}`,
    `${zodiacIcon(dashboard.natalCore.moon)} Moon: ${dashboard.natalCore.moon}`,
    `${zodiacIcon(dashboard.natalCore.rising)} Rising: ${dashboard.natalCore.rising}`,
    `${uiIcon("calendar")} ${dashboard.profile?.birthDate || ""}`,
    `${uiIcon("clock")} ${dashboard.profile?.birthTime || ""}`,
    `${uiIcon("location")} ${dashboard.profile?.birthCity || ""}`
  ].filter((item) => item.replace(/<[^>]+>/g, "").trim());
  const zodiacCompact = renderHomeZodiacCompact(dashboard.natalCore?.sun);

  return `
    <section class="hero">
      <article class="card">
        <span class="eyebrow">User Dashboard</span>
        <h1 class="dashboard-name"><span class="${nameClass}">${displayName}</span></h1>
        <div class="chip-grid">
          ${chips.map((chip) => `<span class="astro-chip">${chip}</span>`).join("")}
        </div>
        <div class="hero-actions">
          <a class="btn primary" href="/natal-chart">Natal Profile</a>
          <a class="btn ghost" href="/profile">Edit Birth Data</a>
        </div>
      </article>
      <aside class="card">
        ${todayPanel}
      </aside>
    </section>
    <section class="section">
      <article class="card">
        <div class="dashboard-head">
          <h2>Forecast</h2>
          <div class="period-switch">
            <button class="btn ghost js-period ${period === "week" ? "is-active" : ""}" data-period="week" type="button">Week</button>
            <button class="btn ghost js-period ${period === "month" ? "is-active" : ""}" data-period="month" type="button">Month</button>
            <button class="btn ghost js-period ${period === "year" ? "is-active" : ""}" data-period="year" type="button">Year</button>
          </div>
        </div>
        <div id="homeForecastBlock" class="dashboard-swap">${forecastSummary}</div>
      </article>
    </section>
    ${zodiacCompact}
    <section class="section">
      <article class="card">
        <h2>Friends dynamic compatibility</h2>
        <div id="homeFriendsBlock" class="friends-list dashboard-swap">${friendsBlock}</div>
      </article>
    </section>
  `;
}

function loginView() {
  const userLabel = state.authUser?.username
    ? `@${state.authUser.username}`
    : state.authUser?.firstName || "";

  if (state.authenticated) {
    return `
      <section class="section">
        <article class="card">
          <span class="eyebrow">Authentication</span>
          <h1>You are signed in</h1>
          <p>Provider: Telegram ${userLabel ? `(${userLabel})` : ""}</p>
          <div class="hero-actions">
            <a class="btn primary" href="/">Continue</a>
            <button id="logoutButton" class="btn ghost" type="button">Logout</button>
          </div>
        </article>
      </section>
    `;
  }

  const loginEnabled = state.telegramLoginEnabled && state.telegramBotUsername;

  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Authentication</span>
        <h1>Sign in with Telegram</h1>
        <p>This service is available only to authorized users.</p>
      </article>
    </section>
    <section class="section">
      <article class="card">
        ${
          loginEnabled
            ? `<div id="telegramWidgetMount"></div>
               <div class="hero-actions">
                 <button id="switchTelegramAccountButton" class="btn ghost" type="button">Login with another Telegram account</button>
                 <button id="webAppAuthButton" class="btn ghost" type="button">Login from Telegram WebApp context</button>
               </div>
               <p id="loginStatus" class="muted" style="margin-top:0.8rem"></p>`
            : `<p>Telegram login is not configured yet. Set TELEGRAM_BOT_TOKEN and TELEGRAM_BOT_USERNAME in Railway variables.</p>`
        }
      </article>
    </section>
  `;
}

function onboardingView() {
  const profile = state.profile || {};
  const fallbackName = [state.authUser?.firstName, state.authUser?.lastName].filter(Boolean).join(" ").trim()
    || String(state.authUser?.username || "").trim();
  const resolvedName = profile.name || fallbackName;
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 1</span>
        <h1>Build your birth profile</h1>
        <p>Accurate date, time and place are critical for house structure and rising sign quality.</p>
      </article>
    </section>
    <section class="section">
      <form id="onboardingForm" class="card form-grid">
        <label>Name
          <input required name="name" value="${resolvedName || ""}" placeholder="Your name" />
        </label>
        <label>Date of birth
          <input required type="date" name="birthDate" value="${profile.birthDate || ""}" />
        </label>
        <label>Birth time
          <input required type="time" name="birthTime" value="${profile.birthTime || ""}" />
        </label>
        <label>Birth city
          <input id="onboardingBirthCity" required name="birthCity" value="${profile.birthCity || ""}" placeholder="City, Country" list="citySuggestions" autocomplete="off" />
        </label>
        <label>Timezone
          <input required name="timezone" value="${profile.timezone || "UTC"}" placeholder="UTC+3" />
        </label>
        <input type="hidden" name="latitude" value="${Number.isFinite(Number(profile.latitude)) ? Number(profile.latitude) : ""}" />
        <input type="hidden" name="longitude" value="${Number.isFinite(Number(profile.longitude)) ? Number(profile.longitude) : ""}" />
        <input type="hidden" name="timezoneIana" value="${profile.timezoneIana || ""}" />
        <datalist id="citySuggestions"></datalist>
        <button class="btn primary form-submit" type="submit">Save and continue</button>
      </form>
    </section>
  `;
}

function profileView() {
  const profile = state.profile || {};
  const authLabel = state.authUser?.username
    ? `@${state.authUser.username}`
    : [state.authUser?.firstName, state.authUser?.lastName].filter(Boolean).join(" ");
  const isEditing = Boolean(state.profileEditMode);
  const profileLines = [
    { label: "Name", value: profile.name || "N/A" },
    { label: "Date of birth", value: profile.birthDate || "N/A" },
    { label: "Birth time", value: profile.birthTime || "N/A" },
    { label: "Birth city", value: profile.birthCity || "N/A" },
    { label: "Timezone", value: profile.timezone || "UTC" }
  ];
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Profile</span>
        <h1>Account</h1>
        <p>${authLabel || "Telegram user"}.</p>
      </article>
    </section>
    <section class="section">
      <article class="card">
        ${
          isEditing
            ? `
              <form id="profileForm" class="form-grid">
                <label>Name
                  <input required name="name" value="${profile.name || ""}" placeholder="Your name" />
                </label>
                <label>Date of birth
                  <input required type="date" name="birthDate" value="${profile.birthDate || ""}" />
                </label>
                <label>Birth time
                  <input required type="time" name="birthTime" value="${profile.birthTime || ""}" />
                </label>
                <label>Birth city
                  <input id="profileBirthCity" required name="birthCity" value="${profile.birthCity || ""}" placeholder="City, Country" list="citySuggestions" autocomplete="off" />
                </label>
                <label>Timezone
                  <input required name="timezone" value="${profile.timezone || "UTC"}" placeholder="UTC+3" />
                </label>
                <input type="hidden" name="latitude" value="${Number.isFinite(Number(profile.latitude)) ? Number(profile.latitude) : ""}" />
                <input type="hidden" name="longitude" value="${Number.isFinite(Number(profile.longitude)) ? Number(profile.longitude) : ""}" />
                <input type="hidden" name="timezoneIana" value="${profile.timezoneIana || ""}" />
                <datalist id="citySuggestions"></datalist>
              </form>
            `
            : `
              <div class="profile-readonly">
                ${profileLines
                  .map(
                    (item) => `
                      <div class="profile-row">
                        <span>${item.label}</span>
                        <strong>${item.value}</strong>
                      </div>
                    `
                  )
                  .join("")}
              </div>
            `
        }
      </article>
    </section>
    <section class="section">
      <article class="card profile-actions-card">
        <div class="profile-actions">
          <div class="profile-actions-left">
            <button id="profileLogoutButton" class="btn ghost" type="button">Logout</button>
            <button id="profileEditButton" class="btn ghost" type="button">${isEditing ? "Cancel edit" : "Edit"}</button>
          </div>
          <button id="profileUpdateButton" class="btn primary profile-update-btn" type="button" style="display:none">Update data</button>
        </div>
      </article>
    </section>
  `;
}

function natalViewLoading() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 2 · Natal</span>
        <h1>Your natal report</h1>
        <p id="natalStatus">Preparing your chart...</p>
      </article>
    </section>
  `;
}

function renderNatalHeader(profile, report) {
  const nameClass = String(profile?.name || "").length > 20 ? "mask-fade" : "name-plain";
  const chips = [
    `${zodiacIcon(report?.core?.sun)} Sun: ${report?.core?.sun || "Unknown"}`,
    `${zodiacIcon(report?.core?.moon)} Moon: ${report?.core?.moon || "Unknown"}`,
    `${zodiacIcon(report?.core?.rising)} Rising: ${report?.core?.rising || "Unknown"}`,
    `${uiIcon("calendar")} ${profile?.birthDate || "N/A"}`,
    `${uiIcon("clock")} ${profile?.birthTime || "N/A"}`,
    `${uiIcon("location")} ${profile?.birthCity || "N/A"}`
  ];

  return `
    <section class="section">
      <article class="card natal-head-card">
        <span class="eyebrow">Natal Report</span>
        <h1 class="natal-main-name"><span class="${nameClass}">${profile?.name || "User"}</span></h1>
        <div class="chip-grid">
          ${chips.map((chip) => `<span class="astro-chip">${chip}</span>`).join("")}
        </div>
      </article>
    </section>
  `;
}

function interpretPlanetPlacement(item) {
  const planet = String(item?.key || "Planet");
  const sign = String(item?.sign || "Unknown");
  const house = Number(item?.house);
  const retrograde = item?.retrograde ? "Retrograde indicates this theme is processed internally before action." : "";

  const byPlanet = {
    Sun: `Identity and will are expressed through ${sign} style.`,
    Moon: `Emotional regulation and safety needs are filtered through ${sign}.`,
    Mercury: `Thinking and communication are optimized by ${sign} patterns.`,
    Venus: `Affection, aesthetics and relational bonding move through ${sign}.`,
    Mars: `Action, drive and conflict response are energized by ${sign}.`,
    Jupiter: `Growth and opportunity expand through ${sign} behavior.`,
    Saturn: `Discipline and long-term structure are shaped by ${sign}.`,
    Uranus: `Innovation and autonomy pressure this area toward change.`,
    Neptune: `Meaning, ideals and ambiguity require grounded boundaries here.`,
    Pluto: `Deep transformation and power dynamics surface in this zone.`
  };

  const base = byPlanet[planet] || `${planet} themes manifest through ${sign}.`;
  const houseText = Number.isFinite(house)
    ? `Primary focus appears in house ${house}, so outcomes are strongest in that life domain.`
    : "House influence is broad and less localized.";
  return `${base} ${houseText} ${retrograde}`.trim();
}

function renderPlanetPlacementTable(planets) {
  const safePlanets = Array.isArray(planets) ? planets : [];
  if (isMobileViewport()) {
    return `
      <div class="placement-cards">
        ${safePlanets
          .map((item) => {
            const stateLabel = item.retrograde ? "Retrograde" : "Direct";
            return `
              <article class="placement-card">
                <div class="placement-chip-row">
                  <span class="placement-chip">${planetIcon(item.key)} ${item.key}</span>
                  <span class="placement-chip">${zodiacIcon(item.sign)} ${item.sign}</span>
                  <span class="placement-chip">House ${Number.isFinite(item.house) ? item.house : "—"}</span>
                  <span class="placement-chip">${stateLabel}</span>
                </div>
                <p>${interpretPlanetPlacement(item)}</p>
              </article>
            `;
          })
          .join("")}
      </div>
    `;
  }
  return `
    <div class="table-wrap">
      <table class="placement-table">
        <thead>
          <tr>
            <th>Planet</th>
            <th>Sign</th>
            <th>House</th>
            <th>State</th>
            <th>Meaning</th>
          </tr>
        </thead>
        <tbody>
          ${safePlanets
            .map((item) => {
              const stateLabel = item.retrograde ? "Retrograde" : "Direct";
              return `
                <tr>
                  <td data-label="Planet"><span class="astro-inline">${planetIcon(item.key)} <strong>${item.key}</strong></span></td>
                  <td data-label="Sign"><span class="astro-inline">${zodiacIcon(item.sign)} ${item.sign}</span></td>
                  <td data-label="House">${Number.isFinite(item.house) ? item.house : "—"}</td>
                  <td data-label="State">${stateLabel}</td>
                  <td data-label="Meaning">${interpretPlanetPlacement(item)}</td>
                </tr>
              `;
            })
            .join("")}
        </tbody>
      </table>
    </div>
  `;
}

function buildNatalEditorial(profile, report) {
  const sun = report?.core?.sun || "Unknown";
  const moon = report?.core?.moon || "Unknown";
  const rising = report?.core?.rising || "Unknown";
  const life = report?.lifeAreas || {};
  const housesFocus = Array.isArray(report?.housesFocus) ? report.housesFocus : [];
  const aspects = Array.isArray(report?.aspects) ? report.aspects : [];
  const actionPlan = Array.isArray(report?.growthPlan) ? report.growthPlan : [];
  const planItems = actionPlanEntries(actionPlan, profile, report?.core || {});
  const planets = Array.isArray(report?.planets) ? report.planets : [];
  const topPlanets = planets.slice(0, 3).map((item) => `${item.key} in ${item.sign}`);
  const voiceName = (profile?.name || "User").split(/\s+/).filter(Boolean)[0] || "User";
  const framingQuote = `${sun} drives intent, ${moon} regulates reaction, ${rising} shapes first impression.`;
  return `
    <section class="section" id="natal-framework">
      <article class="route-card content-panel premium-panel">
        <span class="premium-kicker">Context Layer</span>
        <h2>Interpretation Framework</h2>
        <p class="dropcap"><strong>Identity axis:</strong> ${zodiacIcon(sun)} ${sun} defines visible motivation, ${zodiacIcon(moon)} ${moon} defines emotional processing, and ${zodiacIcon(rising)} ${rising} defines behavioral presentation under pressure. In practical terms, this is your default operating model in work, relationships and recovery cycles.</p>
        <p>This reading is structured as decision support, not fatalism. It maps repeatable tendencies so ${voiceName} can plan timing, communication style and energy allocation with higher precision.</p>
        <blockquote class="premium-quote">“${framingQuote}”</blockquote>
        <p class="muted">Signal stack now active: ${topPlanets.join(" · ") || "Core planetary emphasis unavailable"}.</p>
      </article>
    </section>
    <section class="section" id="natal-focus">
      <div class="editorial-grid">
        <article class="feature-card content-card premium-panel">
          <span class="premium-kicker">Domain I</span>
          <h3>${uiIcon("briefcase")} Work Strategy</h3>
          <p>${life.career || "Career interpretation appears here based on chart geometry and planetary focus."}</p>
          <p>Execution protocol: define one strategic objective per week, lock two deep-work windows, and use low-friction tasks only in low-energy transits.</p>
        </article>
        <article class="feature-card content-card premium-panel">
          <span class="premium-kicker">Domain II</span>
          <h3>${uiIcon("group")} Relationship Dynamics</h3>
          <p>${life.relationships || "Relational interpretation appears here from Venus, Moon and house emphasis."}</p>
          <p>Communication protocol: state expectations early, mirror agreements in concrete language, and separate “emotion” from “request” in tense conversations.</p>
        </article>
        <article class="feature-card content-card premium-panel">
          <span class="premium-kicker">Domain III</span>
          <h3>${uiIcon("brain")} Decision Hygiene</h3>
          <p>When emotional load is high, convert interpretation into measurable micro-actions. This reduces narrative drift and stabilizes outcomes.</p>
          <p>Use a 24-hour review cycle for decisions impacting money, commitment and reputation; delay irreversible actions until signal is stable twice in a row.</p>
        </article>
      </div>
    </section>
    <section class="section" id="natal-houses">
      <article class="route-card content-panel premium-panel">
        <span class="premium-kicker">Architecture</span>
        <h2>House Dynamics</h2>
        <p class="dropcap">House emphasis shows where natal potential turns into measurable events. Repetition across these houses usually correlates with your strongest themes this season: where effort compounds, where conflict repeats, and where growth is easiest to operationalize.</p>
        <div class="chip-grid">
          ${housesFocus
            .map((item) => `<span class="astro-chip">House ${item.house}: ${item.meaning}</span>`)
            .join("")}
        </div>
        <blockquote class="premium-quote">Use high-focus blocks in emphasized houses, and reserve admin work for low-signal windows.</blockquote>
      </article>
    </section>
    <section class="section" id="natal-aspects">
      <article class="route-card content-panel premium-panel">
        <span class="premium-kicker">Geometry</span>
        <h2>Aspect Dynamics</h2>
        <p>Aspects describe internal coordination between drives. Harmonious links make execution cheaper; frictional links require conscious sequencing and recovery hygiene.</p>
        <ul class="bullet-list">${aspects.slice(0, 8).map((item) => `<li>${item}</li>`).join("")}</ul>
      </article>
    </section>
    <section class="section" id="natal-plan">
      <article class="route-card content-panel premium-panel">
        <span class="premium-kicker">Execution</span>
        <h2>Action Plan</h2>
        <ol class="premium-steps">
          ${planItems
            .map(
              (item) => `
                <li class="premium-step">
                  <h4>${item.title}</h4>
                  <p class="premium-step-action">${item.action}</p>
                  <p class="premium-step-comment">${item.comment}</p>
                </li>
              `
            )
            .join("")}
        </ol>
        <p><strong>Profile context:</strong> ${profile?.name || "User"} can run this plan as a weekly ritual with measurable checkpoints and a short post-week retrospective.</p>
      </article>
    </section>
  `;
}

function renderNatalToc() {
  const items = [
    { id: "natal-wheel", label: "Natal Wheel" },
    { id: "natal-placements", label: "Placements Matrix" },
    { id: "natal-core-domains", label: "Life Domains" },
    { id: "natal-zodiac-sign", label: "Zodiac Sign" },
    { id: "natal-framework", label: "Framework" },
    { id: "natal-focus", label: "Strategic Focus" },
    { id: "natal-houses", label: "House Dynamics" },
    { id: "natal-aspects", label: "Aspect Dynamics" },
    { id: "natal-plan", label: "Action Plan" }
  ];
  return `
    <aside class="natal-toc">
      <div class="natal-toc-sticky">
        <span class="eyebrow">Navigation</span>
        <nav class="natal-toc-nav">
          ${items
            .map(
              (item, index) =>
                `<a href="#${item.id}" class="js-natal-toc ${index === 0 ? "active" : ""}" data-target="${item.id}">${item.label}</a>`
            )
            .join("")}
        </nav>
      </div>
    </aside>
  `;
}

function bindNatalToc() {
  const links = Array.from(document.querySelectorAll(".js-natal-toc"));
  if (!links.length) {
    return;
  }
  const sections = links
    .map((link) => {
      const id = link.getAttribute("data-target");
      const element = id ? document.getElementById(id) : null;
      return element ? { id, element } : null;
    })
    .filter(Boolean);
  if (!sections.length) {
    return;
  }
  const setActive = (id) => {
    links.forEach((link) => link.classList.toggle("active", link.getAttribute("data-target") === id));
  };
  const observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!visible?.target?.id) {
        return;
      }
      setActive(visible.target.id);
    },
    {
      root: null,
      threshold: [0.2, 0.45, 0.7],
      rootMargin: "-22% 0px -58% 0px"
    }
  );
  sections.forEach((section) => observer.observe(section.element));
  links.forEach((link) => {
    link.addEventListener("click", (event) => {
      event.preventDefault();
      const id = link.getAttribute("data-target");
      if (id) {
        const target = document.getElementById(id);
        if (target) {
          target.scrollIntoView({ behavior: "smooth", block: "start" });
          if (history.replaceState) {
            history.replaceState(null, "", `#${id}`);
          }
        }
        setActive(id);
      }
    });
  });
}

function scrollToNatalHash({ smooth = true } = {}) {
  if (window.location.pathname !== "/natal-chart") {
    return;
  }
  const hash = String(window.location.hash || "").trim();
  if (!hash || hash === "#") {
    return;
  }
  const id = hash.slice(1);
  const target = document.getElementById(id);
  if (!target) {
    return;
  }
  target.scrollIntoView({ behavior: smooth ? "smooth" : "auto", block: "start" });
}

function natalViewEmpty() {
  return shell({
    eyebrow: "Natal Report",
    title: "Profile required before chart",
    intro: "Complete onboarding first. This keeps interpretations consistent and useful.",
    primaryCta: { href: "/onboarding", label: "Complete Onboarding" },
    secondaryCta: { href: "/", label: "Back Home" },
    rightPanel: "<h2>Why</h2><p>No birth data means no house system, no rising sign, and weak recommendations.</p>",
    body: ""
  });
}

function dailyViewLoading() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 3 · Daily</span>
        <h1>Daily focus</h1>
        <p id="dailyStatus">Building daily signal...</p>
      </article>
    </section>
  `;
}

function friendsView() {
  const zodiacSelectOptions = zodiacOrder
    .map((sign) => `<option value="${sign}">${sign}</option>`)
    .join("");
  return `
    <section class="hero">
      <article class="card">
        <span class="eyebrow">Friends</span>
        <h1>Check friends?</h1>
        <p>Fast synastry-lite view for communication quality, conflict timing and daily collaboration windows.</p>
      </article>
      <aside class="card">
        <form id="friendForm" class="form-grid">
          <label>Friend name
            <input required name="friendName" placeholder="Friend name" />
          </label>
          <label>Friend sign
            <select required name="friendSign">
              <option value="">Select sign</option>
              ${zodiacSelectOptions}
            </select>
          </label>
          <button class="btn primary form-submit" type="submit">Add friend</button>
        </form>
      </aside>
    </section>
    <section class="section">
      <article class="card">
        <h2>Your friends</h2>
        <div id="friendsList" class="friends-list"></div>
      </article>
    </section>
  `;
}

function faqView() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">FAQ</span>
        <h1>Astronautica method</h1>
        <div class="faq">
          <article class="faq-item">
            <h3>How we build your natal chart</h3>
            <p>We start with your birth date, exact birth time, and birthplace, then convert location into precise coordinates and timezone context. After that, Astronautica calculates a full tropical natal model with the Placidus house system using deterministic astronomical math. Under the hood, we use circular-natal-horoscope-js with Moshier ephemeris calculations, while city resolution and coordinate normalization are handled through Open-Meteo geocoding. The result is a reproducible chart architecture: same input always returns the same natal geometry, so interpretation remains consistent over time.</p>
          </article>
          <article class="faq-item">
            <h3>Our methodology: astronomy first, interpretation second</h3>
            <p>Our pipeline has two clear layers. First, the calculation layer: planetary and angular positions, house cusps, and core sign structure are computed from objective inputs. Second, the interpretation layer: we translate those signals into practical guidance for communication timing, emotional regulation, focus management, and relationship dynamics. This architecture keeps the product grounded and transparent: calculations are technical, while interpretations are presented as strategic decision support.</p>
          </article>
          <article class="faq-item">
            <h3>What makes this more rigorous than generic horoscope apps?</h3>
            <p>Most horoscope feeds are broad content streams. Astronautica is profile-anchored: we combine your natal chart geometry, explicit logic, and repeatable compatibility sub-signals. Daily guidance is generated in context of your profile state, not generic sign-only templates. That gives you continuity: one coherent system from natal baseline to day-level decisions.</p>
          </article>
          <article class="faq-item">
            <h3>How do friend compatibility scores work?</h3>
            <p>Compatibility is modeled as a structured composite: communication sync, emotional stability, and friction load. Instead of one opaque score, we expose domain-level diagnostics and short rationale, so you can see which pattern is helping and which one needs better boundaries or clearer protocols.</p>
          </article>
          <article class="faq-item">
            <h3>Is this medical, legal or financial advice?</h3>
            <p>No. This product is for reflection and planning only. High-stakes decisions should be validated with qualified professionals and real-world evidence.</p>
          </article>
        </div>
      </article>
    </section>
  `;
}

const routes = {
  "/": () => (state.dashboard ? renderHomeDashboard(state.dashboard) : homeViewLoading()),
  "/login": loginView,
  "/onboarding": onboardingView,
  "/profile": profileView,
  "/natal-chart": () => `<section class="section"><article class="card"><p class="muted">Loading...</p></article></section>`,
  "/daily": () => `<section class="section"><article class="card"><p class="muted">Loading...</p></article></section>`,
  "/friends": friendsView,
  "/faq": faqView
};

function markActiveNav(path) {
  document.querySelectorAll(".nav a").forEach((link) => {
    const href = link.getAttribute("href");
    link.classList.toggle("active", href === path);
  });
}

function renderFriendsList() {
  const container = document.getElementById("friendsList");
  if (!container) {
    return;
  }
  if (!state.friends.length) {
    container.innerHTML = "<p class=\"muted\">No friends saved yet.</p>";
    return;
  }

  container.innerHTML = `<div class="friends-accordion-list">${
    state.friends
      .map((friend) => {
        const insight = state.friendInsights[String(friend.id)] || {};
        return renderFriendAccordion({ ...friend, ...insight });
      })
      .join("")
  }</div>`;
}

function bindFriendAccordionInteractions(root = document) {
  root.querySelectorAll(".friend-accordion-trigger").forEach((button) => {
    button.addEventListener("click", () => {
      const card = button.closest(".friend-accordion");
      if (!(card instanceof HTMLElement)) {
        return;
      }
      const body = card.querySelector(".friend-accordion-body");
      const isOpen = card.classList.toggle("open");
      button.setAttribute("aria-expanded", isOpen ? "true" : "false");
      if (body instanceof HTMLElement) {
        if (isOpen) {
          body.style.maxHeight = `${body.scrollHeight + 24}px`;
          window.setTimeout(() => {
            body.style.maxHeight = `${body.scrollHeight + 24}px`;
          }, 140);
        } else {
          body.style.maxHeight = "0px";
        }
      }
    });
  });
}

function bindShareFriendButtons(root = document) {
  root.querySelectorAll(".js-share-friend").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      const target = event.currentTarget;
      if (!(target instanceof HTMLElement)) {
        return;
      }
      const friendName = target.getAttribute("data-name") || "Friend";
      const friendSign = target.getAttribute("data-sign") || "Unknown";
      const score = Number(target.getAttribute("data-score")) || 0;
      shareFriendCompatibility(friendName, friendSign, score);
    });
  });
}

function looksLikeEmail(value) {
  const v = String(value || "").trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
}

function normalizeTelegramHandle(value) {
  const raw = String(value || "").trim();
  const withoutUrl = raw.replace(/^https?:\/\/t\.me\//i, "");
  const withoutAt = withoutUrl.replace(/^@/, "");
  return withoutAt.replace(/[^a-zA-Z0-9_]/g, "");
}

function shareFriendCompatibility(friendName, friendSign, score) {
  const pct = Math.max(0, Math.min(100, Math.round(Number(score) || 0)));
  const reason = pct >= 75
    ? "strong communication sync and stable emotional rhythm"
    : pct >= 62
      ? "moderate alignment with clear communication requirements"
      : "higher friction load that needs explicit boundaries";
  openShareModal({ friendName, friendSign, score: pct, reason });
}

function closeShareModal() {
  document.querySelector(".share-modal-backdrop")?.remove();
}

function openShareModal(payload) {
  closeShareModal();
  const modal = document.createElement("div");
  modal.className = "share-modal-backdrop";
  modal.innerHTML = `
    <div class="share-modal card" role="dialog" aria-modal="true" aria-label="Share compatibility">
      <span class="eyebrow">Share</span>
      <h2>Share compatibility</h2>
      <p>${payload.friendName} (${payload.friendSign}) · ${payload.score}%</p>
      <form id="shareModalForm" class="form-grid">
        <label>Friend contact
          <input required name="contact" placeholder="email@example.com or @telegram" />
        </label>
        <div class="share-modal-actions">
          <button type="button" class="btn ghost js-share-cancel">Cancel</button>
          <button type="submit" class="btn primary">Share</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);

  modal.addEventListener("click", (event) => {
    if (event.target === modal) {
      closeShareModal();
    }
  });
  modal.querySelector(".js-share-cancel")?.addEventListener("click", closeShareModal);
  const form = modal.querySelector("#shareModalForm");
  form?.addEventListener("submit", (event) => {
    event.preventDefault();
    const contact = String(new FormData(form).get("contact") || "").trim();
    const subject = "Compatibility check from Astronautica";
    const shareUrl = `https://app.basilarcana.com/share.html?score=${encodeURIComponent(String(payload.score))}&sign=${encodeURIComponent(String(payload.friendSign || ""))}`;
    const summary = `I checked our compatibility on app.basilarcana.com: ${payload.score}%.`;
    const reasonText = `Why this score: ${payload.reason}.`;
    const linkText = `View details: ${shareUrl}`;
    const body = `${shareUrl}\n\n${summary}\n${reasonText}\n\n${linkText}`;
    if (looksLikeEmail(contact)) {
      fetchJson("/api/metrics/share-invite", { method: "POST", body: JSON.stringify({}) }).catch(() => {});
      window.location.href = `mailto:${encodeURIComponent(contact)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
      closeShareModal();
      return;
    }
    const handle = normalizeTelegramHandle(contact);
    if (!handle) {
      alert("Please enter a valid email or Telegram username.");
      return;
    }
    fetchJson("/api/metrics/share-invite", { method: "POST", body: JSON.stringify({}) }).catch(() => {});
    window.open(`https://t.me/${encodeURIComponent(handle)}?text=${encodeURIComponent(`${shareUrl}\n\n${subject}\n\n${summary}\n${reasonText}`)}`, "_blank", "noopener,noreferrer");
    closeShareModal();
  });
}

async function hydrateNatal() {
  if (!hasProfile()) {
    app.innerHTML = natalViewEmpty();
    return;
  }

  try {
    const data = await fetchJson("/api/natal-report", {
      method: "POST",
      body: JSON.stringify({})
    });
    const profile = state.profile;

    const natalChartSvg = renderNatalChartSvg(data);

    const editorial = buildNatalEditorial(profile, data);
    const placementsTable = renderPlanetPlacementTable(data.planets || []);
    const life = data.lifeAreas || {};
    const zodiacSection = renderNatalZodiacSection(data?.core?.sun);

    app.innerHTML = `
      ${renderNatalHeader(profile, data)}
      <div class="natal-layout">
        <div class="natal-main">
          <section class="section" id="natal-wheel">
            <article class="route-card">
              <h2>Natal Wheel</h2>
              ${natalChartSvg}
            </article>
          </section>
          <section class="section" id="natal-placements">
            <article class="route-card content-panel premium-panel">
              <span class="premium-kicker">Data Table + Narrative</span>
              <h2>Planet Placement Matrix</h2>
              <p class="dropcap">${data.summary}</p>
              <blockquote class="premium-quote">Planetary placements are not labels. They are a timing and behavior map for better choices under real constraints.</blockquote>
              ${placementsTable}
              <div class="placement-notes">
                <p><strong>Reading method:</strong> start with personal planets (Sun, Moon, Mercury, Venus, Mars), then evaluate outer-planet pressure only where it repeats in key houses.</p>
                <p><strong>Practical use:</strong> translate each placement into a weekly behavior experiment and track outcomes, not mood, for two cycles.</p>
              </div>
            </article>
          </section>
          <section class="section" id="natal-core-domains">
            <div class="feature-grid">
              <article class="feature-card content-card">
                <h3>${uiIcon("heart")} Relationships</h3>
                <p>${life.relationships || "N/A"}</p>
              </article>
              <article class="feature-card content-card">
                <h3>${uiIcon("briefcase")} Career</h3>
                <p>${life.career || "N/A"}</p>
              </article>
              <article class="feature-card content-card">
                <h3>${uiIcon("coins")} Money</h3>
                <p>${life.money || "N/A"}</p>
              </article>
              <article class="feature-card content-card">
                <h3>${uiIcon("bolt")} Energy</h3>
                <p>${life.energy || "N/A"}</p>
              </article>
              <article class="feature-card content-card">
                <h3>${uiIcon("chart")} Strength</h3>
                <p>${data.blocks?.strength || "N/A"}</p>
              </article>
              <article class="feature-card content-card">
                <h3>${uiIcon("shield")} Blind Spot</h3>
                <p>${data.blocks?.blindSpot || "N/A"}</p>
              </article>
            </div>
          </section>
          ${zodiacSection}
          ${editorial}
        </div>
        ${renderNatalToc()}
      </div>
    `;
    bindNatalToc();
    bindNatalAsciiLogo();
    animateHeadingTypewriter();
    window.setTimeout(() => scrollToNatalHash({ smooth: false }), 0);
  } catch (error) {
    if (error.status === 401) {
      await refreshAuthState();
      navigate("/login", { replace: true });
      return;
    }
    const status = document.getElementById("natalStatus");
    if (status) {
      status.textContent = `Failed to load natal report: ${error.message}`;
    }
  }
}

async function hydrateHome() {
  if (!hasProfile()) {
    app.innerHTML = shell({
      eyebrow: "Dashboard",
      title: "Complete onboarding first",
      intro: "The dashboard needs birth profile data to compute natal core and forecasts.",
      primaryCta: { href: "/onboarding", label: "Open Onboarding" },
      secondaryCta: { href: "/login", label: "Account" },
      rightPanel: "<h2>Next</h2><p>After onboarding, home becomes your all-in-one astrology dashboard.</p>",
      body: ""
    });
    return;
  }

  try {
    const payload = await fetchJson(`/api/dashboard?period=${encodeURIComponent(state.homePeriod)}`);
    state.dashboard = payload.dashboard;
    app.innerHTML = renderHomeDashboard(payload.dashboard);
    bindHomePeriodHandlers();
    updateHomeDynamicBlocks(state.dashboard, state.homePeriod, { animate: false });
    animateHeadingTypewriter();
  } catch (error) {
    if (error.status === 401) {
      await refreshAuthState();
      navigate("/login", { replace: true });
      return;
    }
    if (error.payload?.error === "profile_required") {
      navigate("/onboarding", { replace: true });
      return;
    }
    const status = document.getElementById("homeStatus");
    if (status) {
      status.textContent = `Failed to load dashboard: ${error.message}`;
    }
  }
}

function animateRouteTransition() {
  app.classList.remove("route-enter");
  void app.offsetWidth;
  app.classList.add("route-enter");
}

function animateHeadingTypewriter() {
  const heading = app.querySelector("h1");
  if (!(heading instanceof HTMLElement) || heading.dataset.typed === "1") {
    return;
  }
  const holder = heading.children.length === 1 && heading.firstElementChild instanceof HTMLElement
    ? heading.firstElementChild
    : heading;
  const fullText = String(holder.textContent || "").trim();
  if (!fullText) {
    return;
  }
  heading.dataset.typed = "1";
  heading.classList.add("typewriter-heading", "is-typing");
  holder.textContent = "";
  const duration = Math.max(620, Math.min(1680, fullText.length * 38));
  const start = performance.now();
  const tick = (now) => {
    const progress = Math.min(1, (now - start) / duration);
    const eased = Math.pow(progress, 1.45);
    const nextLength = Math.max(1, Math.round(fullText.length * eased));
    holder.textContent = fullText.slice(0, nextLength);
    if (progress < 1) {
      window.requestAnimationFrame(tick);
      return;
    }
    window.setTimeout(() => {
      heading.classList.remove("is-typing");
    }, 220);
  };
  window.requestAnimationFrame(tick);
}

function formatSignedDelta(value) {
  const num = Number(value) || 0;
  return `${num > 0 ? "+" : ""}${num}`;
}

function renderDailyAstronomySvg(astronomy, dayDashboard) {
  const snapshots = Array.isArray(astronomy) && astronomy.length
    ? astronomy.slice(0, 3)
    : [
        { label: "Yesterday", sun: "Unknown", moon: "Unknown", rising: "Unknown" },
        { label: "Today", sun: "Unknown", moon: "Unknown", rising: "Unknown" },
        { label: "Tomorrow", sun: "Unknown", moon: "Unknown", rising: "Unknown" }
      ];
  const energySeries = [
    Number(dayDashboard?.yesterdayEnergy) || 50,
    Number(dayDashboard?.todayEnergy) || 50,
    Number(dayDashboard?.tomorrowEnergy) || 50
  ];
  const deltas = [
    0,
    Number(dayDashboard?.deltaFromYesterday) || 0,
    Number(dayDashboard?.deltaToTomorrow) || 0
  ];
  const trend = (delta) => {
    if (delta > 0) {
      return { icon: "▲", cls: "up", text: `+${delta}` };
    }
    if (delta < 0) {
      return { icon: "▼", cls: "down", text: `${delta}` };
    }
    return { icon: "■", cls: "flat", text: "0" };
  };

  return `
    <article class="route-card daily-astronomy-card">
      <h2>Astronomy pulse</h2>
      <div class="daily-astro-compact-grid">
        ${snapshots
          .map((item, index) => {
            const t = trend(deltas[index]);
            return `
              <article class="daily-astro-compact-item ${index === 1 ? "today" : ""}">
                <div class="daily-astro-head">
                  <span class="daily-astro-big-star">✦</span>
                  <span class="daily-astro-day">${item.label}</span>
                </div>
                <div class="daily-astro-main-row">
                  <strong class="daily-astro-score">${energySeries[index]}</strong>
                  <span class="daily-astro-trend ${t.cls}" aria-label="Trend ${t.text}">
                    ${t.icon} ${t.text}
                  </span>
                </div>
                <p class="daily-astro-signs-text">${item.sun} · ${item.moon} · ${item.rising}</p>
              </article>
            `;
          })
          .join("")}
      </div>
      <p class="muted">Three-point transit snapshot: yesterday baseline, today state, tomorrow drift.</p>
    </article>
  `;
}

async function hydrateDaily() {
  if (!hasProfile()) {
    app.innerHTML = shell({
      eyebrow: "Daily",
      title: "Complete profile first",
      intro: "Daily guidance is tuned by natal structure, so onboarding comes first.",
      primaryCta: { href: "/onboarding", label: "Go to Onboarding" },
      secondaryCta: { href: "/", label: "Back Home" },
      rightPanel: "<h2>Daily engine</h2><p>Focus, risk, and one practical step refreshed every day.</p>",
      body: ""
    });
    return;
  }

  try {
    const data = await fetchJson("/api/daily-insight", {
      method: "POST",
      body: JSON.stringify({})
    });
    const d = data?.dayDashboard || {};
    const q = data?.dailyQuest || {};
    const a = data?.achievements || {};

    app.innerHTML = `
      <section class="hero">
        <article class="card daily-hero-main">
          <span class="eyebrow">Daily Ritual</span>
          <h1>${data.dateLabel}</h1>
          <p>${data.intro}</p>
          <div class="daily-kpis">
            <article class="metric">
              <strong>${d.todayEnergy ?? "--"}/100</strong>
              <span>Today intensity</span>
            </article>
            <article class="metric">
              <strong>${formatSignedDelta(d.deltaFromYesterday)}</strong>
              <span>vs yesterday</span>
            </article>
            <article class="metric">
              <strong>${formatSignedDelta(d.deltaToTomorrow)}</strong>
              <span>to tomorrow</span>
            </article>
          </div>
        </article>
        <aside class="card daily-hero-side">
          <h2>Dynamics</h2>
          <div class="daily-delta-grid">
            <div class="daily-delta-card">
              <span>Yesterday</span>
              <strong>${d.yesterdayEnergy ?? "--"}/100</strong>
            </div>
            <div class="daily-delta-card">
              <span>Today</span>
              <strong>${d.todayEnergy ?? "--"}/100</strong>
            </div>
            <div class="daily-delta-card">
              <span>Tomorrow</span>
              <strong>${d.tomorrowEnergy ?? "--"}/100</strong>
            </div>
          </div>
          <p class="muted"><strong>Focus:</strong> ${d.focus || data.focus || ""}</p>
          <p class="muted"><strong>Risk:</strong> ${d.risk || data.risk || ""}</p>
        </aside>
      </section>
      <section class="section">
        <div class="editorial-grid">
          <article class="route-card content-panel daily-quest-card">
            <span class="premium-kicker">Daily Quest</span>
            <h2>${q.primary?.title || "Daily quest"}</h2>
            <p class="dropcap">${q.primary?.task || data.step}</p>
            <blockquote class="premium-quote">${q.secondary?.title || "Secondary challenge"}: ${q.secondary?.task || ""}</blockquote>
            <p><strong>Optional:</strong> ${q.optional?.title || "Optional stretch"} — ${q.optional?.task || ""}</p>
          </article>
          <article class="route-card content-panel daily-achievements-card">
            <span class="premium-kicker">Achievements</span>
            <h2>Your trajectory</h2>
            <div class="daily-achievement-grid">
              <div class="daily-achievement-item"><span>Days in system</span><strong>${a.daysInSystem ?? "--"}</strong></div>
              <div class="daily-achievement-item"><span>Current streak</span><strong>${a.streakDays ?? data.streak ?? "--"}</strong></div>
              <div class="daily-achievement-item"><span>Friends added</span><strong>${a.friendsAdded ?? "--"}</strong></div>
              <div class="daily-achievement-item"><span>Invited via share</span><strong>${a.invitesSent ?? "--"}</strong></div>
            </div>
            <p class="muted">${data.streakLabel || ""}</p>
          </article>
          <article class="route-card content-panel">
            <span class="premium-kicker">History</span>
            <h2>Recent days</h2>
            <ul class="bullet-list">${(data.history || [])
              .map((item) => `<li>${item.dayKey}: ${item.focus}</li>`)
              .join("")}</ul>
          </article>
        </div>
      </section>
      <section class="section">
        ${renderDailyAstronomySvg(data.astronomy, d)}
      </section>
    `;
    animateHeadingTypewriter();
  } catch (error) {
    if (error.status === 401) {
      await refreshAuthState();
      navigate("/login", { replace: true });
      return;
    }
    const status = document.getElementById("dailyStatus");
    if (status) {
      status.textContent = `Failed to load daily insight: ${error.message}`;
    }
  }
}

function mountTelegramWidget() {
  const mount = document.getElementById("telegramWidgetMount");
  if (!mount || !state.telegramBotUsername) {
    return;
  }
  mount.innerHTML = "";
  const script = document.createElement("script");
  script.async = true;
  script.src = "https://telegram.org/js/telegram-widget.js?22";
  script.setAttribute("data-telegram-login", state.telegramBotUsername);
  script.setAttribute("data-size", "large");
  script.setAttribute("data-userpic", "false");
  script.setAttribute("data-request-access", "write");
  script.setAttribute("data-onauth", "onTelegramAuth(user)");
  mount.appendChild(script);
}

async function handleTelegramWidgetAuth(telegramAuth) {
  try {
    await fetchJson("/api/auth/telegram-widget", {
      method: "POST",
      body: JSON.stringify({ telegramAuth })
    });
    await loadSessionState();
    navigate("/", { replace: true });
  } catch (error) {
    const status = document.getElementById("loginStatus");
    if (status) {
      status.textContent = `Login failed: ${error.message}`;
    }
  }
}

async function handleWebAppInitDataAuth() {
  const status = document.getElementById("loginStatus");
  const initData = window.Telegram?.WebApp?.initData;
  if (!initData) {
    if (status) {
      status.textContent = "No Telegram WebApp initData found in this browser context.";
    }
    return;
  }

  try {
    await fetchJson("/api/auth/telegram-init-data", {
      method: "POST",
      body: JSON.stringify({ initData })
    });
    await loadSessionState();
    navigate("/", { replace: true });
  } catch (error) {
    if (status) {
      status.textContent = `WebApp login failed: ${error.message}`;
    }
  }
}

function handleSwitchTelegramAccount() {
  const status = document.getElementById("loginStatus");
  const botId = Number(state.telegramBotId);
  if (!Number.isFinite(botId) || botId <= 0) {
    if (status) {
      status.textContent = "Telegram bot id is not configured.";
    }
    return;
  }

  if (window.Telegram?.Login?.auth) {
    window.Telegram.Login.auth(
      {
        bot_id: botId,
        request_access: "write"
      },
      (user) => {
        if (!user) {
          if (status) {
            status.textContent = "Telegram account switch was cancelled.";
          }
          return;
        }
        handleTelegramWidgetAuth(user);
      }
    );
    return;
  }

  const authUrl = `https://oauth.telegram.org/auth?bot_id=${encodeURIComponent(
    String(botId)
  )}&origin=${encodeURIComponent(window.location.origin)}&request_access=write`;
  window.open(authUrl, "_blank", "noopener,noreferrer");
}

async function loadCitySuggestions(query) {
  const q = String(query || "").trim();
  if (q.length < 2) {
    return [];
  }
  const payload = await fetchJson(`/api/cities?query=${encodeURIComponent(q)}&limit=12`);
  return Array.isArray(payload?.cities) ? payload.cities : [];
}

function bindCityAutocomplete(form, cityInputId) {
  const cityInput = document.getElementById(cityInputId);
  const datalist = form?.querySelector("#citySuggestions");
  const latitudeInput = form?.querySelector('input[name="latitude"]');
  const longitudeInput = form?.querySelector('input[name="longitude"]');
  const timezoneIanaInput = form?.querySelector('input[name="timezoneIana"]');
  const timezoneInput = form?.querySelector('input[name="timezone"]');

  if (!form || !cityInput || !datalist) {
    return;
  }

  const applySelectedMeta = () => {
    const selected = citySuggestionMeta.get(cityInput.value);
    if (!selected) {
      return;
    }
    if (latitudeInput) latitudeInput.value = String(selected.latitude ?? "");
    if (longitudeInput) longitudeInput.value = String(selected.longitude ?? "");
    if (timezoneIanaInput) timezoneIanaInput.value = String(selected.timezoneIana ?? "");
    if (timezoneInput && !timezoneInput.value.trim()) {
      timezoneInput.value = String(selected.timezoneIana || "UTC");
    }
  };

  cityInput.addEventListener("input", () => {
    citySuggestionMeta.delete(cityInput.value);
    if (citySuggestTimer) {
      window.clearTimeout(citySuggestTimer);
    }
    citySuggestTimer = window.setTimeout(async () => {
      try {
        const cities = await loadCitySuggestions(cityInput.value);
        datalist.innerHTML = cities
          .map((city) => {
            const label = String(city.displayName || city.name || "").trim();
            if (label) {
              citySuggestionMeta.set(label, city);
            }
            return `<option value="${label}"></option>`;
          })
          .join("");
      } catch {
        datalist.innerHTML = "";
      }
    }, 180);
  });

  cityInput.addEventListener("change", applySelectedMeta);
  cityInput.addEventListener("blur", applySelectedMeta);
}

async function submitProfileForm(form, afterSavePath = null) {
  const formData = new FormData(form);
  const profile = Object.fromEntries(formData.entries());
  const payload = await fetchJson("/api/profile", {
    method: "PUT",
    body: JSON.stringify({ profile })
  });
  state.profile = payload.profile;
  state.profileReady = payload.profileReady;
  if (afterSavePath) {
    navigate(afterSavePath);
  } else {
    render();
  }
}

function attachRouteHandlers(path) {
  if (path === "/") {
    const homeFriends = document.getElementById("homeFriendsBlock");
    if (homeFriends) {
      bindFriendAccordionInteractions(homeFriends);
      bindShareFriendButtons(homeFriends);
    }
  }

  if (path === "/login") {
    if (!state.authenticated && state.telegramLoginEnabled) {
      mountTelegramWidget();
      const webAppAuthButton = document.getElementById("webAppAuthButton");
      webAppAuthButton?.addEventListener("click", handleWebAppInitDataAuth);
      const switchAccountButton = document.getElementById("switchTelegramAccountButton");
      switchAccountButton?.addEventListener("click", handleSwitchTelegramAccount);
    }

    const logoutButton = document.getElementById("logoutButton");
    logoutButton?.addEventListener("click", async () => {
      await fetchJson("/api/auth/logout", { method: "POST", body: JSON.stringify({}) });
      await loadSessionState();
      navigate("/login", { replace: true });
    });
  }

  if (path === "/onboarding") {
    const form = document.getElementById("onboardingForm");
    bindCityAutocomplete(form, "onboardingBirthCity");
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      try {
        await submitProfileForm(form, "/");
      } catch (error) {
        if (error.status === 401) {
          await refreshAuthState();
          navigate("/login", { replace: true });
          return;
        }
        alert(`Failed to save profile: ${error.message}`);
      }
    });
  }

  if (path === "/profile") {
    const profileForm = document.getElementById("profileForm");
    const profileUpdateButton = document.getElementById("profileUpdateButton");
    if (profileForm) {
      bindCityAutocomplete(profileForm, "profileBirthCity");
      profileForm.addEventListener("submit", (event) => event.preventDefault());
      const initialSnapshot = JSON.stringify(Object.fromEntries(new FormData(profileForm).entries()));
      const syncDirtyState = () => {
        const currentSnapshot = JSON.stringify(Object.fromEntries(new FormData(profileForm).entries()));
        const dirty = currentSnapshot !== initialSnapshot;
        if (profileUpdateButton) {
          profileUpdateButton.style.display = dirty ? "inline-flex" : "none";
          profileUpdateButton.disabled = !dirty;
        }
      };
      profileForm.addEventListener("input", syncDirtyState);
      profileForm.addEventListener("change", syncDirtyState);
      profileUpdateButton?.addEventListener("click", async () => {
        try {
          await submitProfileForm(profileForm, null);
          state.profileEditMode = false;
          render();
        } catch (error) {
          if (error.status === 401) {
            await refreshAuthState();
            navigate("/login", { replace: true });
            return;
          }
          alert(`Failed to update profile: ${error.message}`);
        }
      });
    }

    const profileLogoutButton = document.getElementById("profileLogoutButton");
    profileLogoutButton?.addEventListener("click", async () => {
      await fetchJson("/api/auth/logout", { method: "POST", body: JSON.stringify({}) });
      await loadSessionState();
      navigate("/login", { replace: true });
    });

    const profileEditButton = document.getElementById("profileEditButton");
    profileEditButton?.addEventListener("click", () => {
      state.profileEditMode = !state.profileEditMode;
      render();
    });
  }

  if (path === "/friends") {
    const refreshFriendInsights = async () => {
      try {
        const payload = await fetchJson("/api/dashboard?period=week");
        const dynamic = Array.isArray(payload?.dashboard?.friendsDynamic) ? payload.dashboard.friendsDynamic : [];
        state.friendInsights = dynamic.reduce((acc, item) => {
          if (item?.id) {
            acc[String(item.id)] = item;
          }
          return acc;
        }, {});
      } catch {
        state.friendInsights = {};
      }
    };
    refreshFriendInsights().finally(() => {
      renderFriendsList();
      const list = document.getElementById("friendsList");
      if (list) {
        bindFriendAccordionInteractions(list);
        bindShareFriendButtons(list);
      }
    });

    const form = document.getElementById("friendForm");
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const friend = Object.fromEntries(formData.entries());
      try {
        const payload = await fetchJson("/api/friends", {
          method: "POST",
          body: JSON.stringify(friend)
        });
        state.friends = payload.friends || [];
        form.reset();
        await refreshFriendInsights();
        renderFriendsList();
        const list = document.getElementById("friendsList");
        if (list) {
          bindFriendAccordionInteractions(list);
          bindShareFriendButtons(list);
        }
      } catch (error) {
        if (error.status === 401) {
          await refreshAuthState();
          navigate("/login", { replace: true });
          return;
        }
        alert(`Failed to save friend: ${error.message}`);
      }
    });
  }
}

async function refreshAuthState() {
  const auth = await fetchJson("/api/auth/status");
  state.authRequired = Boolean(auth.authRequired);
  state.authenticated = Boolean(auth.authenticated);
  state.authUser = auth.user || null;
  state.telegramLoginEnabled = Boolean(auth.telegramLoginEnabled);
  state.telegramBotUsername = auth.telegramBotUsername || null;
  state.telegramBotId = Number(auth.telegramBotId) || null;
}

async function loadSessionState() {
  await refreshAuthState();

  if (state.authRequired && !state.authenticated) {
    state.profile = null;
    state.profileReady = false;
    state.friends = [];
    state.friendInsights = {};
    state.dashboard = null;
    return;
  }

  const [profilePayload, friendsPayload] = await Promise.all([
    fetchJson("/api/profile"),
    fetchJson("/api/friends")
  ]);
  state.profile = profilePayload.profile || null;
  state.profileReady = Boolean(profilePayload.profileReady);
  state.friends = friendsPayload.friends || [];
  if (state.profileReady) {
    try {
      const payload = await fetchJson(`/api/dashboard?period=${encodeURIComponent(state.homePeriod)}`);
      state.dashboard = payload.dashboard || null;
      const dynamic = Array.isArray(payload?.dashboard?.friendsDynamic) ? payload.dashboard.friendsDynamic : [];
      state.friendInsights = dynamic.reduce((acc, item) => {
        if (item?.id) {
          acc[String(item.id)] = item;
        }
        return acc;
      }, {});
    } catch {
      state.dashboard = null;
      state.friendInsights = {};
    }
  } else {
    state.dashboard = null;
    state.friendInsights = {};
  }
}

function render() {
  let path = window.location.pathname;
  if (path !== "/profile") {
    state.profileEditMode = false;
  }
  const profileExists = hasProfile();

  if (state.authRequired && !state.authenticated && path !== "/login") {
    path = "/login";
    window.history.replaceState({}, "", path);
  }

  if (state.authRequired && state.authenticated && !profileExists && !["/onboarding", "/login"].includes(path)) {
    path = "/onboarding";
    window.history.replaceState({}, "", path);
  }

  if (state.authRequired && state.authenticated && profileExists && path === "/onboarding") {
    path = "/";
    window.history.replaceState({}, "", path);
  }

  const makeView = routes[path] || homeViewLoading;
  app.innerHTML = makeView();
  animateRouteTransition();
  animateHeadingTypewriter();
  markActiveNav(path);
  renderProfileChip();
  attachRouteHandlers(path);

  if (path === "/natal-chart") {
    hydrateNatal();
  }
  if (path === "/daily") {
    hydrateDaily();
  }
  if (path === "/") {
    hydrateHome();
  }
}

document.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof Element)) {
    return;
  }
  const anchor = target.closest("a");
  if (!(anchor instanceof HTMLAnchorElement)) {
    return;
  }
  const href = anchor.getAttribute("href");
  if (!href || href.startsWith("http") || href.startsWith("mailto:")) {
    return;
  }

  if (href.startsWith("#")) {
    event.preventDefault();
    if (history.replaceState) {
      history.replaceState(null, "", `${window.location.pathname}${href}`);
    }
    scrollToNatalHash({ smooth: true });
    return;
  }

  if (href.startsWith("/")) {
    const [nextPath, hash = ""] = href.split("#");
    const samePath = nextPath === window.location.pathname;
    if (samePath && hash) {
      event.preventDefault();
      if (history.replaceState) {
        history.replaceState(null, "", href);
      }
      scrollToNatalHash({ smooth: true });
      return;
    }
  }
  event.preventDefault();
  window.history.pushState({}, "", href);
  nav.classList.remove("open");
  render();
});

window.addEventListener("popstate", render);
window.onTelegramAuth = (user) => {
  handleTelegramWidgetAuth(user);
};

loadSessionState()
  .catch((error) => {
    console.error("Failed to initialize session state", error);
  })
  .finally(() => {
    const storedTheme = window.localStorage.getItem(themeStorageKey);
    applyTheme(storedTheme || state.theme);
    render();
  });

window.__astroState = state;
