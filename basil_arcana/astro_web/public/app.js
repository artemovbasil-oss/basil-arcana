const app = document.getElementById("app");
const nav = document.getElementById("nav");
const menuButton = document.getElementById("menuButton");

const state = {
  authRequired: false,
  authenticated: false,
  authUser: null,
  telegramLoginEnabled: false,
  telegramBotUsername: null,
  profile: null,
  profileReady: false,
  friends: [],
  dashboard: null,
  homePeriod: "week"
};

menuButton.addEventListener("click", () => {
  nav.classList.toggle("open");
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
  const periodLabel = period === "year" ? "Year" : period === "month" ? "Month" : "Week";
  const intensity = Number(dashboard.periodForecast?.intensity || 0);
  const dynamicFriends = Array.isArray(dashboard.friendsDynamic) ? dashboard.friendsDynamic : [];
  const friendsBlock = dynamicFriends.length
    ? dynamicFriends
        .map(
          (friend) => `
          <div class="friend-row">
            <div>
              <strong>${friend.friendName}</strong>
              <p>${friend.friendSign} · ${friend.trend}</p>
            </div>
            <div class="friend-score">
              <strong>${friend.score}</strong>
              <p>${friend.note}</p>
            </div>
          </div>
        `
        )
        .join("")
    : `<p class="muted">No friends yet. Add friends to unlock dynamic compatibility tracking.</p>`;

  return `
    <section class="hero">
      <article class="card">
        <span class="eyebrow">User Dashboard</span>
        <h1>${dashboard.profile.name}</h1>
        <p>${dashboard.natalCore.sun} sun, ${dashboard.natalCore.moon} moon, ${dashboard.natalCore.rising} rising.</p>
        <div class="hero-actions">
          <a class="btn primary" href="/natal-chart">Natal Profile</a>
          <a class="btn ghost" href="/onboarding">Edit Birth Data</a>
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
        <p><strong>${periodLabel} intensity: ${intensity}/100.</strong> ${dashboard.periodForecast.summary}</p>
      </article>
    </section>
    <section class="section">
      <article class="card">
        <h2>Friends dynamic compatibility</h2>
        <div class="friends-list">${friendsBlock}</div>
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
    rightPanel: "<h2>Why</h2><p>No birth data means no house system, no rising sign, and weak recommendations.</p>",
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
          <h2>Planet placements</h2>
          <ul class="bullet-list">${(data.planets || [])
            .map((item) => `<li>${item.key}: ${item.sign}, house ${item.house}</li>`)
            .join("")}</ul>
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
          <h2>Growth plan</h2>
          <ul class="bullet-list">${(data.growthPlan || []).map((item) => `<li>${item}</li>`).join("")}</ul>
        </article>
      </section>
      <section class="section">
        <article class="route-card">
          <h2>Major aspects</h2>
          <ul class="bullet-list">${data.aspects.map((item) => `<li>${item}</li>`).join("")}</ul>
        </article>
      </section>
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
    const periodButtons = app.querySelectorAll(".js-period");
    periodButtons.forEach((button) => {
      button.addEventListener("click", async () => {
        const nextPeriod = button.getAttribute("data-period");
        if (!nextPeriod || nextPeriod === state.homePeriod) {
          return;
        }
        state.homePeriod = nextPeriod;
        app.innerHTML = homeViewLoading();
        await hydrateHome();
      });
    });
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

function attachRouteHandlers(path) {
  if (path === "/login") {
    if (!state.authenticated && state.telegramLoginEnabled) {
      mountTelegramWidget();
      const webAppAuthButton = document.getElementById("webAppAuthButton");
      webAppAuthButton?.addEventListener("click", handleWebAppInitDataAuth);
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
      const formData = new FormData(form);
      const profile = Object.fromEntries(formData.entries());
      try {
        const payload = await fetchJson("/api/profile", {
          method: "PUT",
          body: JSON.stringify({ profile })
        });
        state.profile = payload.profile;
        state.profileReady = payload.profileReady;
        navigate("/natal-chart");
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
  if (state.authRequired && !state.authenticated && path !== "/login") {
    path = "/login";
    window.history.replaceState({}, "", path);
  }

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
    render();
  });

window.__astroState = state;
