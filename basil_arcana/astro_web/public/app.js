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
  dashboard: null,
  homePeriod: "week",
  theme: "dark"
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

function buildEnergySeries(profile, period, intensity) {
  const count = period === "year" ? 12 : period === "month" ? 30 : 7;
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
    labels: values.map((_, index) => energyPointLabel(period, index))
  };
}

function buildSmoothPath(points) {
  if (!points.length) {
    return "";
  }
  if (points.length === 1) {
    return `M ${points[0].x} ${points[0].y}`;
  }
  let path = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i += 1) {
    const current = points[i];
    const next = points[i + 1];
    const controlX = (current.x + next.x) / 2;
    path += ` Q ${controlX} ${current.y} ${next.x} ${next.y}`;
  }
  return path;
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
  const isMobile = typeof window !== "undefined" && window.matchMedia && window.matchMedia("(max-width: 760px)").matches;
  const intensity = Number(dashboard?.periodForecast?.intensity || 50);
  const series = buildEnergySeries(dashboard?.profile, period, intensity);
  const width = 980;
  const height = isMobile ? 340 : 220;
  const padX = isMobile ? 22 : 18;
  const padY = isMobile ? 22 : 18;
  const chartBottom = height - (isMobile ? 58 : 38);
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
  const todayBadgeRadius = isMobile ? (period === "year" ? 14 : 13) : period === "year" ? 11 : 10;
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
            const size = tone === "neutral" ? (isMobile ? 6.2 : 5.1) : isMobile ? 8.4 : 7;
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

function renderFriendsBlock(dashboard, period) {
  const dynamicFriends = Array.isArray(dashboard?.friendsDynamic) ? dashboard.friendsDynamic : [];
  if (!dynamicFriends.length) {
    return `<p class="muted">No friends yet. Add friends to unlock dynamic compatibility tracking.</p>`;
  }
  return dynamicFriends
    .map((friend) => {
      const score = normalizedFriendScore(friend.score, period);
      return `
        <div class="friend-row">
          <div>
            <strong>${friend.friendName}</strong>
            <p>${zodiacIcon(friend.friendSign)} ${friend.friendSign} · ${friend.trend}</p>
          </div>
          <div class="friend-score">
            ${renderFriendGauge(score)}
            <p>${friend.note}</p>
          </div>
        </div>
      `;
    })
    .join("");
}

function renderForecastSummary(dashboard, period) {
  const periodLabel = period === "year" ? "Year" : period === "month" ? "Month" : "Week";
  const intensity = Number(dashboard?.periodForecast?.intensity || 0);
  return `
    <p><strong>${periodLabel} intensity: ${intensity}/100.</strong> ${dashboard?.periodForecast?.summary || ""}</p>
    ${renderEnergyChart(dashboard, period)}
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
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Profile</span>
        <h1>Account</h1>
        <p>${authLabel || "Telegram user"}.</p>
      </article>
    </section>
    <section class="section">
      <form id="profileForm" class="card form-grid">
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
        <button class="btn primary form-submit" type="submit">Save profile</button>
      </form>
    </section>
    <section class="section">
      <article class="card">
        <button id="profileLogoutButton" class="btn ghost" type="button">Logout</button>
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
        <ol class="premium-steps">${actionPlan.map((item) => `<li>${item}</li>`).join("")}</ol>
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
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 4 · Friends</span>
        <h1>Friend compatibility</h1>
        <p>Fast synastry-lite view for communication and daily interaction.</p>
      </article>
    </section>
    <section class="section">
      <form id="friendForm" class="card form-grid">
        <label>Friend name
          <input required name="friendName" placeholder="Friend name" />
        </label>
        <label>Friend sign
          <select required name="friendSign">
            <option value="">Select sign</option>
            ${zodiacSelectOptions}
          </select>
        </label>
        <button class="btn primary form-submit" type="submit">Save friend</button>
      </form>
    </section>
    <section class="section">
      <article class="card">
        <h2>Your friends</h2>
        <div id="friendsList" class="friends-list"></div>
      </article>
    </section>
    <section class="section">
      <article id="friendResult" class="card" style="display:none"></article>
    </section>
  `;
}

function faqView() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">FAQ</span>
        <h1>Astronautica scope</h1>
        <div class="faq">
          <article class="faq-item">
            <h3>What is already implemented?</h3>
            <p>Onboarding flow, natal route, daily route, friend compatibility route, and server API contracts.</p>
          </article>
          <article class="faq-item">
            <h3>How does auth work now?</h3>
            <p>Telegram auth with server-side signature verification and session persistence.</p>
          </article>
          <article class="faq-item">
            <h3>What comes next?</h3>
            <p>Google login provider, DB-backed user identities, and real ephemeris calculations.</p>
          </article>
        </div>
      </article>
    </section>
  `;
}

const routes = {
  "/": homeViewLoading,
  "/login": loginView,
  "/onboarding": onboardingView,
  "/profile": profileView,
  "/natal-chart": natalViewLoading,
  "/daily": dailyViewLoading,
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

  container.innerHTML = state.friends
    .map(
      (friend) => `
      <div class="friend-row" data-id="${friend.id}">
        <div>
          <strong>${friend.friendName}</strong>
          <p>${zodiacIcon(friend.friendSign)} ${friend.friendSign}</p>
        </div>
        <button class="btn ghost js-check-friend" data-id="${friend.id}">Check</button>
      </div>
    `
    )
    .join("");
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
          ${editorial}
        </div>
        ${renderNatalToc()}
      </div>
    `;
    bindNatalToc();
    bindNatalAsciiLogo();
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

    app.innerHTML = `
      <section class="section">
        <article class="card">
          <span class="eyebrow">Daily Ritual</span>
          <h1>${data.dateLabel}</h1>
          <p>${data.intro}</p>
        </article>
      </section>
      <section class="section">
        <div class="feature-grid">
          <article class="feature-card"><h3>Focus</h3><p>${data.focus}</p></article>
          <article class="feature-card"><h3>Risk</h3><p>${data.risk}</p></article>
          <article class="feature-card"><h3>One Step</h3><p>${data.step}</p></article>
        </div>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Streak</h2>
          <p>${data.streakLabel}</p>
          <ul class="bullet-list">${(data.history || [])
            .map((item) => `<li>${item.dayKey}: ${item.focus}</li>`)
            .join("")}</ul>
        </article>
      </section>
    `;
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

async function runCompatibility(friend) {
  const result = document.getElementById("friendResult");
  if (!result) {
    return;
  }

  try {
    const data = await fetchJson("/api/compatibility-report", {
      method: "POST",
      body: JSON.stringify({ friend })
    });
    result.style.display = "block";
    result.innerHTML = `
      <span class="eyebrow">Compatibility</span>
      <h2>${data.score}/100 with ${friend.friendName}</h2>
      <ul class="bullet-list">${data.highlights.map((item) => `<li>${item}</li>`).join("")}</ul>
      <p>${data.advice}</p>
    `;
  } catch (error) {
    if (error.status === 401) {
      await refreshAuthState();
      navigate("/login", { replace: true });
      return;
    }
    result.style.display = "block";
    result.innerHTML = `<p>Failed to calculate compatibility: ${error.message}</p>`;
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
    bindCityAutocomplete(profileForm, "profileBirthCity");
    profileForm?.addEventListener("submit", async (event) => {
      event.preventDefault();
      try {
        await submitProfileForm(profileForm, null);
      } catch (error) {
        if (error.status === 401) {
          await refreshAuthState();
          navigate("/login", { replace: true });
          return;
        }
        alert(`Failed to save profile: ${error.message}`);
      }
    });

    const profileLogoutButton = document.getElementById("profileLogoutButton");
    profileLogoutButton?.addEventListener("click", async () => {
      await fetchJson("/api/auth/logout", { method: "POST", body: JSON.stringify({}) });
      await loadSessionState();
      navigate("/login", { replace: true });
    });
  }

  if (path === "/friends") {
    renderFriendsList();

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
        renderFriendsList();
      } catch (error) {
        if (error.status === 401) {
          await refreshAuthState();
          navigate("/login", { replace: true });
          return;
        }
        alert(`Failed to save friend: ${error.message}`);
      }
    });

    const list = document.getElementById("friendsList");
    list?.addEventListener("click", async (event) => {
      const target = event.target;
      if (!(target instanceof HTMLElement) || !target.classList.contains("js-check-friend")) {
        return;
      }
      const id = target.getAttribute("data-id");
      const friend = state.friends.find((item) => item.id === id);
      if (!friend) {
        return;
      }
      await runCompatibility(friend);
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
    return;
  }

  const [profilePayload, friendsPayload] = await Promise.all([
    fetchJson("/api/profile"),
    fetchJson("/api/friends")
  ]);
  state.profile = profilePayload.profile || null;
  state.profileReady = Boolean(profilePayload.profileReady);
  state.friends = friendsPayload.friends || [];
}

function render() {
  let path = window.location.pathname;
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
  if (!(target instanceof HTMLAnchorElement)) {
    return;
  }
  const href = target.getAttribute("href");
  if (!href || href.startsWith("http") || href.startsWith("mailto:")) {
    return;
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
