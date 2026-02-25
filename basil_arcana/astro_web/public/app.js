const app = document.getElementById("app");
const nav = document.getElementById("nav");
const menuButton = document.getElementById("menuButton");
const profileKey = "astro_profile_v1";

menuButton.addEventListener("click", () => {
  nav.classList.toggle("open");
});

function getProfile() {
  try {
    const raw = window.localStorage.getItem(profileKey);
    if (!raw) {
      return null;
    }
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function saveProfile(profile) {
  window.localStorage.setItem(profileKey, JSON.stringify(profile));
}

function hasProfile(profile) {
  return Boolean(profile?.name && profile?.birthDate && profile?.birthTime && profile?.birthCity);
}

function signFromMonth(month) {
  const signs = [
    "Capricorn", "Aquarius", "Pisces", "Aries", "Taurus", "Gemini",
    "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius"
  ];
  return signs[(month + 11) % 12];
}

function risingFromTime(time) {
  const hour = Number(String(time || "00:00").split(":")[0]);
  const rising = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"
  ];
  return rising[Math.floor((Number.isFinite(hour) ? hour : 0) / 2) % 12];
}

async function fetchJson(url, options) {
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options
  });
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }
  return response.json();
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

function homeView() {
  const profile = getProfile();
  const profileReady = hasProfile(profile);
  return shell({
    eyebrow: "Astrology MVP",
    title: "Natal intelligence<br/>daily engagement<br/>friend chemistry",
    intro:
      "MVP focus: accurate birth profile, one deep natal report, daily ritual card, and lightweight friend compatibility.",
    primaryCta: { href: profileReady ? "/natal-chart" : "/onboarding", label: profileReady ? "Open My Natal" : "Start Onboarding" },
    secondaryCta: { href: "/daily", label: "Open Daily" },
    rightPanel: `
      <h2>MVP status</h2>
      <div class="metric-grid">
        <div class="metric"><strong>${profileReady ? "Ready" : "Missing"}</strong><p>Birth Profile</p></div>
        <div class="metric"><strong>Live</strong><p>Natal Route</p></div>
        <div class="metric"><strong>Live</strong><p>Daily Route</p></div>
      </div>
      <ul class="bullet-list">
        <li>Profile saved locally for rapid iteration</li>
        <li>Server-side mock contracts available under /api</li>
        <li>Designed for Telegram + Google auth upgrade</li>
      </ul>
    `,
    body: `
      <section class="section">
        <div class="feature-grid">
          <article class="feature-card">
            <h3>1. Onboarding</h3>
            <p>Name + birth data + city + timezone quality checks.</p>
          </article>
          <article class="feature-card">
            <h3>2. Natal Report</h3>
            <p>Strengths, blind spots, and practical direction in one screen.</p>
          </article>
          <article class="feature-card">
            <h3>3. Daily + Friends</h3>
            <p>Recurring daily advice and quick compatibility pulses.</p>
          </article>
        </div>
      </section>
    `
  });
}

function onboardingView() {
  const profile = getProfile() || {};
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

function natalViewLoading() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 2</span>
        <h1>Your natal report</h1>
        <p id="natalStatus">Preparing your chart...</p>
      </article>
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
    rightPanel: `<h2>Why</h2><p>No birth data means no house system, no rising sign, and weak recommendations.</p>`,
    body: ""
  });
}

function dailyViewLoading() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 3</span>
        <h1>Daily focus</h1>
        <p id="dailyStatus">Building daily signal...</p>
      </article>
    </section>
  `;
}

function friendsView() {
  const profile = getProfile();
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">Step 4</span>
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
        <button class="btn primary form-submit" type="submit">Check compatibility</button>
      </form>
    </section>
    <section class="section">
      <article id="friendResult" class="card" style="display:none"></article>
    </section>
    ${!hasProfile(profile) ? '<section class="section"><article class="route-card"><p>Tip: complete onboarding first for better personalized friend advice.</p></article></section>' : ''}
  `;
}

function faqView() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">FAQ</span>
        <h1>MVP scope</h1>
        <div class="faq">
          <article class="faq-item">
            <h3>What is already implemented?</h3>
            <p>Onboarding flow, natal route, daily route, friend compatibility route, and server mock API contracts.</p>
          </article>
          <article class="faq-item">
            <h3>What comes next?</h3>
            <p>Auth (Telegram + Google), persistent DB profile, real ephemeris calculations, and notification engine.</p>
          </article>
        </div>
      </article>
    </section>
  `;
}

const routes = {
  "/": homeView,
  "/onboarding": onboardingView,
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

async function hydrateNatal() {
  const profile = getProfile();
  if (!hasProfile(profile)) {
    app.innerHTML = natalViewEmpty();
    return;
  }
  try {
    const data = await fetchJson("/api/natal-report", {
      method: "POST",
      body: JSON.stringify({ profile })
    });

    app.innerHTML = `
      <section class="section">
        <article class="card">
          <span class="eyebrow">Natal Report</span>
          <h1>${profile.name}: ${data.core.sun} sun, ${data.core.moon} moon, ${data.core.rising} rising</h1>
          <p>${data.summary}</p>
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
          <h2>Top aspects</h2>
          <ul class="bullet-list">${data.aspects.map((item) => `<li>${item}</li>`).join("")}</ul>
        </article>
      </section>
    `;
  } catch (error) {
    const status = document.getElementById("natalStatus");
    if (status) {
      status.textContent = `Failed to load natal report: ${error.message}`;
    }
  }
}

async function hydrateDaily() {
  const profile = getProfile();
  if (!hasProfile(profile)) {
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
      body: JSON.stringify({ profile })
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
        </article>
      </section>
    `;
  } catch (error) {
    const status = document.getElementById("dailyStatus");
    if (status) {
      status.textContent = `Failed to load daily insight: ${error.message}`;
    }
  }
}

function attachRouteHandlers(path) {
  if (path === "/onboarding") {
    const form = document.getElementById("onboardingForm");
    form?.addEventListener("submit", (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const profile = Object.fromEntries(formData.entries());
      saveProfile(profile);
      window.history.pushState({}, "", "/natal-chart");
      render();
    });
  }

  if (path === "/friends") {
    const form = document.getElementById("friendForm");
    const result = document.getElementById("friendResult");
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const friend = Object.fromEntries(formData.entries());
      const profile = getProfile();
      const payload = {
        profile,
        friend
      };
      try {
        const data = await fetchJson("/api/compatibility-report", {
          method: "POST",
          body: JSON.stringify(payload)
        });
        if (result) {
          result.style.display = "block";
          result.innerHTML = `
            <span class="eyebrow">Compatibility</span>
            <h2>${data.score}/100 with ${friend.friendName}</h2>
            <ul class="bullet-list">${data.highlights.map((item) => `<li>${item}</li>`).join("")}</ul>
            <p>${data.advice}</p>
          `;
        }
      } catch (error) {
        if (result) {
          result.style.display = "block";
          result.innerHTML = `<p>Failed to calculate compatibility: ${error.message}</p>`;
        }
      }
    });
  }
}

function render() {
  const path = window.location.pathname;
  const makeView = routes[path] || homeView;
  app.innerHTML = makeView();
  markActiveNav(path);
  attachRouteHandlers(path);

  if (path === "/natal-chart") {
    hydrateNatal();
  }
  if (path === "/daily") {
    hydrateDaily();
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
render();

window.__astroPreview = {
  getProfile,
  saveProfile,
  signFromMonth,
  risingFromTime
};
