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
const zodiacGlyphs = {
  Aries: "♈",
  Taurus: "♉",
  Gemini: "♊",
  Cancer: "♋",
  Leo: "♌",
  Virgo: "♍",
  Libra: "♎",
  Scorpio: "♏",
  Sagittarius: "♐",
  Capricorn: "♑",
  Aquarius: "♒",
  Pisces: "♓"
};

const planetGlyphs = {
  Sun: "☉",
  Moon: "☽",
  Mercury: "☿",
  Venus: "♀",
  Mars: "♂",
  Jupiter: "♃",
  Saturn: "♄",
  Uranus: "♅",
  Neptune: "♆",
  Pluto: "♇"
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

function zodiacGlyph(sign) {
  return zodiacGlyphs[String(sign || "").trim()] || "◌";
}

function planetGlyph(key) {
  const raw = String(key || "").trim();
  const normalized = raw.charAt(0).toUpperCase() + raw.slice(1).toLowerCase();
  return planetGlyphs[normalized] || raw.slice(0, 2).toUpperCase() || "•";
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
            return `<text class="natal-sign-label" x="${signPoint.x}" y="${signPoint.y}" text-anchor="middle" dominant-baseline="middle">${zodiacGlyph(sign)} ${sign.slice(0, 3).toUpperCase()}</text>`;
          })
          .join("")}

        ${aspects
          .map((aspect) => {
            const start = pointOnCircle(center, center, aspectRadius, aspect.left.longitude);
            const end = pointOnCircle(center, center, aspectRadius, aspect.right.longitude);
            return `<line class="natal-aspect-line ${aspect.type} ${aspect.styleClass}" x1="${start.x}" y1="${start.y}" x2="${end.x}" y2="${end.y}" />`;
          })
          .join("")}

        ${planets
          .map((planet) => {
            const guide = pointOnCircle(center, center, aspectRadius + 8, planet.longitude);
            const symbol = planetGlyph(planet.key);
            return `
              <line class="natal-planet-line" x1="${guide.x}" y1="${guide.y}" x2="${planet.dot.x}" y2="${planet.dot.y}" />
              <circle class="natal-planet-dot" cx="${planet.dot.x}" cy="${planet.dot.y}" r="4.2" />
              <text class="natal-planet-label" x="${planet.label.x}" y="${planet.label.y}" text-anchor="middle" dominant-baseline="middle">${symbol}</text>
            `;
          })
          .join("")}
      </svg>
      <p class="muted">Outer ring: signs. Inner wheel: houses. Chords: major aspects. Markers: planetary placements.</p>
    </div>
  `;
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

function renderEnergyChart(dashboard, period) {
  const intensity = Number(dashboard?.periodForecast?.intensity || 50);
  const series = buildEnergySeries(dashboard?.profile, period, intensity);
  const width = 980;
  const height = 158;
  const padX = 18;
  const padY = 20;
  const stepX = (width - padX * 2) / Math.max(1, series.values.length - 1);
  const toY = (value) => height - padY - (value / 100) * (height - padY * 2);
  const points = series.values.map((value, index) => ({
    x: padX + index * stepX,
    y: toY(value),
    value,
    label: series.labels[index]
  }));
  const polyline = points.map((point) => `${point.x},${point.y}`).join(" ");
  const peakPoint = points[series.peakIndex];
  const dipPoint = points[series.dipIndex];

  return `
    <div class="energy-chart-wrap">
      <svg class="energy-chart" viewBox="0 0 ${width} ${height}" role="img" aria-label="Energy trend chart">
        <line class="energy-axis" x1="${padX}" y1="${height - padY}" x2="${width - padX}" y2="${height - padY}" />
        <polyline class="energy-line" points="${polyline}" />
        ${points
          .map(
            (point, index) => `
              <circle class="energy-node ${index === series.peakIndex ? "peak" : index === series.dipIndex ? "dip" : ""}" cx="${point.x}" cy="${point.y}" r="${index === series.peakIndex || index === series.dipIndex ? 5.4 : 3.4}" />
            `
          )
          .join("")}
        <text class="energy-label peak" x="${peakPoint.x}" y="${peakPoint.y - 10}" text-anchor="middle">▲ ${peakPoint.value}</text>
        <text class="energy-label dip" x="${dipPoint.x}" y="${dipPoint.y + 18}" text-anchor="middle">▼ ${dipPoint.value}</text>
      </svg>
      <div class="energy-legend">
        <span><i class="dot peak"></i> Peak energy</span>
        <span><i class="dot dip"></i> Energy dip</span>
      </div>
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
  const radius = 15;
  const c = 2 * Math.PI * radius;
  const progress = c - (pct / 100) * c;
  return `
    <svg class="friend-gauge" viewBox="0 0 42 42" role="img" aria-label="Compatibility ${pct}%">
      <circle class="friend-gauge-bg" cx="21" cy="21" r="${radius}" />
      <circle class="friend-gauge-fill" cx="21" cy="21" r="${radius}" stroke-dasharray="${c}" stroke-dashoffset="${progress}" />
      <text class="friend-gauge-text" x="21" y="22" text-anchor="middle" dominant-baseline="middle">${pct}%</text>
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
            <p>${zodiacGlyph(friend.friendSign)} ${friend.friendSign} · ${friend.trend}</p>
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

  return `
    <section class="hero">
      <article class="card">
        <span class="eyebrow">User Dashboard</span>
        <h1 class="dashboard-name"><span class="mask-fade">${dashboard.profile.name}</span></h1>
        <p>${zodiacGlyph(dashboard.natalCore.sun)} ${dashboard.natalCore.sun} sun, ${zodiacGlyph(dashboard.natalCore.moon)} ${dashboard.natalCore.moon} moon, ${zodiacGlyph(dashboard.natalCore.rising)} ${dashboard.natalCore.rising} rising.</p>
        <div class="hero-actions">
          <a class="btn primary" href="/natal-chart">Natal Profile</a>
          <a class="btn ghost" href="/profile">Edit Birth Data</a>
        </div>
      </article>
      <aside class="card">
        <h2>${dashboard.daily.dateLabel}</h2>
        <ul class="bullet-list">
          <li>${dashboard.daily.focus}</li>
          <li>${dashboard.daily.advice}</li>
          <li>${dashboard.daily.horoscopeToday}</li>
        </ul>
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
          <input required name="name" value="${profile.name || ""}" placeholder="Your name" />
        </label>
        <label>Date of birth
          <input required type="date" name="birthDate" value="${profile.birthDate || ""}" />
        </label>
        <label>Birth time
          <input required type="time" name="birthTime" value="${profile.birthTime || ""}" />
        </label>
        <label>Birth city
          <input required name="birthCity" value="${profile.birthCity || ""}" placeholder="City, Country" />
        </label>
        <label>Timezone
          <input required name="timezone" value="${profile.timezone || "UTC"}" placeholder="UTC+3" />
        </label>
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
          <input required name="birthCity" value="${profile.birthCity || ""}" placeholder="City, Country" />
        </label>
        <label>Timezone
          <input required name="timezone" value="${profile.timezone || "UTC"}" placeholder="UTC+3" />
        </label>
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
        <span class="eyebrow">Step 2 · ☉ Natal</span>
        <h1>Your natal report</h1>
        <p id="natalStatus">Preparing your chart...</p>
      </article>
    </section>
  `;
}

function buildNatalEditorial(profile, report) {
  const sun = report?.core?.sun || "Unknown";
  const moon = report?.core?.moon || "Unknown";
  const rising = report?.core?.rising || "Unknown";
  const life = report?.lifeAreas || {};
  return `
    <section class="section">
      <article class="route-card content-panel">
        <h2>Interpretation Framework</h2>
        <p><strong>Identity axis:</strong> ${zodiacGlyph(sun)} ${sun} defines visible motivation, ${zodiacGlyph(moon)} ${moon} defines emotional processing, and ${zodiacGlyph(rising)} ${rising} defines behavioral presentation under pressure.</p>
        <p>This reading is designed for practical planning. The goal is not prediction, but better timing, better communication, and better personal decisions.</p>
      </article>
    </section>
    <section class="section">
      <div class="editorial-grid">
        <article class="feature-card content-card">
          <h3>🜂 Work Strategy</h3>
          <p>${life.career || "Career interpretation appears here based on chart geometry and planetary focus."}</p>
          <p>Execution advice: define a single weekly strategic objective and protect two uninterrupted deep-work windows.</p>
        </article>
        <article class="feature-card content-card">
          <h3>☍ Relationship Dynamics</h3>
          <p>${life.relationships || "Relational interpretation appears here from Venus, Moon and house emphasis."}</p>
          <p>Communication advice: state expectations early, then mirror back agreements in concrete language.</p>
        </article>
        <article class="feature-card content-card">
          <h3>☿ Decision Hygiene</h3>
          <p>When emotional load is high, convert interpretation into short measurable actions. This reduces drift and stabilizes outcomes.</p>
          <p>Use 24-hour review cycles for decisions that impact money, commitment, and reputation.</p>
        </article>
      </div>
    </section>
  `;
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
        <span class="eyebrow">Step 3 · ☽ Daily</span>
        <h1>Daily focus</h1>
        <p id="dailyStatus">Building daily signal...</p>
      </article>
    </section>
  `;
}

function friendsView() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 4 · ☍ Friends</span>
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
          <input required name="friendSign" placeholder="e.g. Libra" />
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
          <p>${friend.friendSign}</p>
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

    app.innerHTML = `
      <section class="section">
        <article class="card">
          <span class="eyebrow">Natal Report</span>
          <h1>${profile.name}: ${zodiacGlyph(data.core.sun)} ${data.core.sun} sun, ${zodiacGlyph(data.core.moon)} ${data.core.moon} moon, ${zodiacGlyph(data.core.rising)} ${data.core.rising} rising</h1>
          <p>${data.summary}</p>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Natal wheel</h2>
          ${natalChartSvg}
        </article>
      </section>
      <section class="section">
        <div class="feature-grid">
          <article class="feature-card"><h3>Strength</h3><p>${data.blocks.strength}</p></article>
          <article class="feature-card"><h3>Blind Spot</h3><p>${data.blocks.blindSpot}</p></article>
          <article class="feature-card"><h3>Action</h3><p>${data.blocks.action}</p></article>
        </div>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Planet placements</h2>
          <ul class="bullet-list">${(data.planets || [])
            .map((item) => `<li>${planetGlyph(item.key)} ${item.key}: ${zodiacGlyph(item.sign)} ${item.sign}, house ${item.house}${item.retrograde ? " (R)" : ""}</li>`)
            .join("")}</ul>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Life areas</h2>
          <ul class="bullet-list">
            <li><strong>Relationships:</strong> ${data.lifeAreas?.relationships || "N/A"}</li>
            <li><strong>Career:</strong> ${data.lifeAreas?.career || "N/A"}</li>
            <li><strong>Money:</strong> ${data.lifeAreas?.money || "N/A"}</li>
            <li><strong>Energy:</strong> ${data.lifeAreas?.energy || "N/A"}</li>
          </ul>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>House focus</h2>
          <ul class="bullet-list">${(data.housesFocus || [])
            .map((item) => `<li>House ${item.house} (${item.theme}): ${item.meaning}</li>`)
            .join("")}</ul>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>All houses</h2>
          <ul class="bullet-list">${(data.housesAll || [])
            .map((item) => `<li>House ${item.house}: ${zodiacGlyph(item.sign)} ${item.sign}</li>`)
            .join("")}</ul>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Growth plan</h2>
          <ul class="bullet-list">${(data.growthPlan || []).map((item) => `<li>${item}</li>`).join("")}</ul>
          <p style="margin-top:0.8rem">Calculation mode: ${data.calculation?.mode || "unknown"} · ${data.calculation?.houseSystem || "n/a"} · ${data.calculation?.zodiac || "n/a"}</p>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Major aspects</h2>
          <ul class="bullet-list">${data.aspects.map((item) => `<li>${item}</li>`).join("")}</ul>
        </article>
      </section>
      ${editorial}
    `;
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
