const app = document.getElementById("app");
const nav = document.getElementById("nav");
const menuButton = document.getElementById("menuButton");

menuButton.addEventListener("click", () => {
  nav.classList.toggle("open");
});

function layout({ eyebrow, title, intro, primaryCta, secondaryCta, rightPanel, body }) {
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
  return layout({
    eyebrow: "Astrology Platform",
    title: "Hyper-personalized<br/>astro readings<br/>in real time",
    intro:
      "A dark, focus-first experience inspired by modern astrology products. Built as a standalone web app for app.basilarcana.com and kept independent from your Telegram miniapp.",
    primaryCta: { href: "/download", label: "Get The App" },
    secondaryCta: { href: "/natal-chart", label: "Explore Natal Chart" },
    rightPanel: `
      <h2>Today in your sky</h2>
      <p>Mercury sharpens language while Venus softens reactions. Watch where friction turns into curiosity.</p>
      <div class="metric-grid">
        <div class="metric"><strong>Sun</strong><p>Identity</p></div>
        <div class="metric"><strong>Moon</strong><p>Emotion</p></div>
        <div class="metric"><strong>Rising</strong><p>Perception</p></div>
      </div>
    `,
    body: `
      <section class="section">
        <div class="feature-grid">
          <article class="feature-card">
            <h3>Natal Blueprint</h3>
            <p>Generate a readable map of your planetary placements, houses, and major aspects.</p>
          </article>
          <article class="feature-card">
            <h3>Compatibility Lens</h3>
            <p>Compare two charts to reveal friction points, emotional glue, and growth zones.</p>
          </article>
          <article class="feature-card">
            <h3>Daily Signal</h3>
            <p>Short tactical guidance that adapts to transits rather than generic zodiac copy.</p>
          </article>
        </div>
      </section>
    `
  });
}

function downloadView() {
  return layout({
    eyebrow: "Download",
    title: "Start on web.<br/>Continue on mobile.",
    intro:
      "Use the web experience directly at app.basilarcana.com. Native apps can be connected later without changing this deployment.",
    primaryCta: { href: "https://apps.apple.com", label: "App Store" },
    secondaryCta: { href: "https://play.google.com/store", label: "Google Play" },
    rightPanel: `
      <h2>Why this setup</h2>
      <ul class="bullet-list">
        <li>Separate Railway service from your miniapp and landing</li>
        <li>Independent release cycle and rollback path</li>
        <li>Ready for Telegram + Google login expansion</li>
      </ul>
    `,
    body: `
      <section class="section">
        <div class="route-card">
          <h2>Deployment scope</h2>
          <p>This service is intentionally isolated. It can evolve into a full astrology portal without touching existing bot flows.</p>
        </div>
      </section>
    `
  });
}

function natalChartView() {
  return layout({
    eyebrow: "Natal Chart",
    title: "Chart engine for<br/>deep personal context",
    intro:
      "Collect birth date, time, and location to calculate houses, placements, and aspect geometry. Present insights in plain language with optional advanced mode.",
    primaryCta: { href: "/compatibility", label: "See Compatibility" },
    secondaryCta: { href: "/faq", label: "Read FAQ" },
    rightPanel: `
      <h2>Data flow</h2>
      <ul class="bullet-list">
        <li>Input validation for date/time/location</li>
        <li>Ephemeris calculation pipeline</li>
        <li>Interpretation rendering layer</li>
      </ul>
    `,
    body: `
      <section class="section">
        <div class="feature-grid">
          <article class="feature-card"><h3>Planets</h3><p>Sun through Pluto with sign/house details.</p></article>
          <article class="feature-card"><h3>Aspects</h3><p>Major angular relations and weighted orbs.</p></article>
          <article class="feature-card"><h3>Houses</h3><p>Life domains mapped with concise narratives.</p></article>
        </div>
      </section>
    `
  });
}

function compatibilityView() {
  return layout({
    eyebrow: "Compatibility",
    title: "Compare two charts.<br/>Find your edges.",
    intro:
      "A synastry-style panel for communication rhythm, emotional needs, and relational stress tests.",
    primaryCta: { href: "/download", label: "Try Beta" },
    secondaryCta: { href: "/", label: "Back Home" },
    rightPanel: `
      <h2>Dimensions</h2>
      <ul class="bullet-list">
        <li>Attachment and conflict patterns</li>
        <li>Intimacy and timing preferences</li>
        <li>Shared growth vectors</li>
      </ul>
    `,
    body: `
      <section class="section">
        <div class="route-card">
          <h2>Interpretation style</h2>
          <p>Use direct, non-fatalistic language. Offer practical prompts instead of deterministic claims.</p>
        </div>
      </section>
    `
  });
}

function faqView() {
  return `
    <section class="section">
      <article class="card">
        <span class="eyebrow">FAQ</span>
        <h1>Common questions</h1>
        <p>Operational and product details for the standalone astro service.</p>
      </article>
    </section>
    <section class="section faq">
      <article class="faq-item">
        <h3>Is this connected to the Telegram miniapp?</h3>
        <p>No. This deployment is isolated in a separate service and domain (`app.basilarcana.com`).</p>
      </article>
      <article class="faq-item">
        <h3>Can we add Telegram and Google auth later?</h3>
        <p>Yes. The frontend can keep the same routes while backend auth providers are added incrementally.</p>
      </article>
      <article class="faq-item">
        <h3>What should be deployed in Railway?</h3>
        <p>Only folder `basil_arcana/astro_web` for this service. Existing `server`, `landing`, and bot services stay untouched.</p>
      </article>
    </section>
  `;
}

const routes = {
  "/": homeView,
  "/download": downloadView,
  "/natal-chart": natalChartView,
  "/compatibility": compatibilityView,
  "/faq": faqView
};

function render() {
  const path = window.location.pathname;
  const makeView = routes[path] || homeView;
  app.innerHTML = makeView();

  document.querySelectorAll(".nav a").forEach((link) => {
    const href = link.getAttribute("href");
    if (href === path) {
      link.classList.add("active");
    } else {
      link.classList.remove("active");
    }
  });
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
