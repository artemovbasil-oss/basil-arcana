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
  googleLoginEnabled: false,
  githubLoginEnabled: false,
  profile: null,
  profileReady: false,
  friends: [],
  friendInsights: {},
  dashboard: null,
  homePeriod: "week",
  theme: "dark",
  profileEditMode: false,
  solarSystem: null
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
  nav.classList.remove("open");
  if (window.location.pathname === "/" && state.dashboard) {
    initSolarSystemWidget(state.dashboard, state.homePeriod);
  }
});

function navigate(path, { replace = false } = {}) {
  nav.classList.remove("open");
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
    const icon = theme === "dark" ? "mdi:moon-waning-crescent" : "mdi:white-balance-sunny";
    const target = theme === "dark" ? "light" : "dark";
    themeToggle.innerHTML = `<iconify-icon icon="${icon}" aria-hidden="true"></iconify-icon>`;
    themeToggle.setAttribute("aria-label", `Switch to ${target} theme`);
    themeToggle.setAttribute("title", `Switch to ${target} theme`);
  }
  syncZodiacThemeImages(theme);
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

const zodiacCelebrities = {
  Aries: [
    { name: "Lady Gaga", field: "Music / Performance", years: "b. 1986", fact: "Her debut era reshaped modern pop visuals and made theatrical live performance mainstream again." },
    { name: "Robert Downey Jr.", field: "Film", years: "b. 1965", fact: "His Iron Man role launched Marvel's modern cinema universe and redefined franchise leading characters." },
    { name: "Emma Watson", field: "Film / Advocacy", years: "b. 1990", fact: "After Harry Potter, she became a global voice for girls' education and gender equality." },
    { name: "Pedro Pascal", field: "Film / TV", years: "b. 1975", fact: "The Mandalorian and The Last of Us made him one of streaming's most recognizable leads." },
    { name: "Mariah Carey", field: "Music", years: "b. 1969", fact: "She set enduring vocal standards and still holds one of the most successful chart records." },
    { name: "Elton John", field: "Music", years: "b. 1947", fact: "His touring longevity and songwriting catalog built one of the most influential pop careers ever." },
    { name: "Reese Witherspoon", field: "Film / Production", years: "b. 1976", fact: "She scaled from actor to major producer, backing female-led stories with global mainstream impact." },
    { name: "Jackie Chan", field: "Film / Action", years: "b. 1954", fact: "He fused stunt innovation and comedy timing, changing action cinema language across multiple decades." },
    { name: "Pharrell Williams", field: "Music / Design", years: "b. 1973", fact: "He combined producer hitmaking with fashion leadership, shaping cross-industry culture beyond music charts." },
    { name: "Celine Dion", field: "Music", years: "b. 1968", fact: "Her vocal consistency and residency-era success created one of the strongest global live brands." }
  ],
  Taurus: [
    { name: "Adele", field: "Music", years: "b. 1988", fact: "Her album cycles repeatedly reset sales benchmarks in the streaming era with minimal overexposure." },
    { name: "Dwayne Johnson", field: "Film / Sports Entertainment", years: "b. 1972", fact: "He transitioned from WWE to box-office anchor while building a large direct audience brand." },
    { name: "David Beckham", field: "Football / Business", years: "b. 1975", fact: "He turned elite sports fame into a long-running global lifestyle and ownership platform." },
    { name: "Gigi Hadid", field: "Fashion", years: "b. 1995", fact: "She became one of the defining faces of the social-first supermodel generation." },
    { name: "George Clooney", field: "Film", years: "b. 1961", fact: "He sustained A-list relevance across acting, directing, and producing with strong critical recognition." },
    { name: "Mark Zuckerberg", field: "Technology", years: "b. 1984", fact: "As Meta's cofounder, he helped build one of the largest social platforms in history." },
    { name: "Megan Fox", field: "Film", years: "b. 1986", fact: "Her blockbuster visibility in the 2000s made her a defining pop-culture screen presence." },
    { name: "Gal Gadot", field: "Film", years: "b. 1985", fact: "Her Wonder Woman role revived a major franchise and expanded women-led superhero market demand." },
    { name: "Tina Fey", field: "Comedy / Writing", years: "b. 1970", fact: "She shaped modern TV comedy by combining showrunning, writing precision, and on-screen performance." },
    { name: "Cher", field: "Music / Film", years: "b. 1946", fact: "Few artists sustained chart and cultural relevance across as many decades and formats." }
  ],
  Gemini: [
    { name: "Angelina Jolie", field: "Film / Humanitarian Work", years: "b. 1975", fact: "She combined major studio success with high-visibility international humanitarian advocacy for years." },
    { name: "Kanye West", field: "Music / Fashion", years: "b. 1977", fact: "His production style shifted mainstream rap sonics and influenced fashion-business crossover models." },
    { name: "Natalie Portman", field: "Film", years: "b. 1981", fact: "From franchise films to Oscar-winning drama, she maintained rare range and critical consistency." },
    { name: "Chris Evans", field: "Film", years: "b. 1981", fact: "His Captain America run anchored a decade of franchise storytelling and global fan loyalty." },
    { name: "Johnny Depp", field: "Film", years: "b. 1963", fact: "He built a career on eccentric character work that repeatedly converted into major box-office." },
    { name: "Kendrick Lamar", field: "Music", years: "b. 1987", fact: "He became a benchmark for concept-driven rap albums with broad cultural and critical impact." },
    { name: "Tom Holland", field: "Film", years: "b. 1996", fact: "His Spider-Man era positioned him as one of the most bankable young film leads." },
    { name: "Heidi Klum", field: "Fashion / Television", years: "b. 1973", fact: "She expanded from runway prominence into enduring mainstream hosting and production roles." },
    { name: "Naomi Campbell", field: "Fashion", years: "b. 1970", fact: "As a supermodel pioneer, she helped define modern runway celebrity power dynamics." },
    { name: "Awkwafina", field: "Film / Comedy", years: "b. 1988", fact: "She moved quickly from digital breakout to major film roles and award-level recognition." }
  ],
  Cancer: [
    { name: "Ariana Grande", field: "Music", years: "b. 1993", fact: "Her vocal style and streaming dominance made her one of pop's strongest digital-era performers." },
    { name: "Selena Gomez", field: "Music / TV / Business", years: "b. 1992", fact: "She built a multi-vertical brand spanning music, acting, and high-growth beauty commerce." },
    { name: "Tom Hanks", field: "Film", years: "b. 1956", fact: "He remains one of cinema's most trusted leads, with decades of iconic dramatic roles." },
    { name: "Meryl Streep", field: "Film", years: "b. 1949", fact: "Her nomination record and range still set an acting benchmark across generations." },
    { name: "Margot Robbie", field: "Film / Production", years: "b. 1990", fact: "She paired blockbuster acting with production strategy, scaling from star talent to studio force." },
    { name: "Lionel Messi", field: "Football", years: "b. 1987", fact: "His sustained elite output and World Cup win cemented one of sport's strongest legacies." },
    { name: "Vin Diesel", field: "Film", years: "b. 1967", fact: "He turned Fast & Furious into one of the highest-grossing global action franchises." },
    { name: "Benedict Cumberbatch", field: "Film / TV", years: "b. 1976", fact: "He balanced prestige roles and major franchises while keeping strong international audience appeal." },
    { name: "Post Malone", field: "Music", years: "b. 1995", fact: "His genre-blending catalog produced durable streaming hits across rap, pop, and melodic rock." },
    { name: "Lana Del Rey", field: "Music", years: "b. 1985", fact: "Her cinematic songwriting style strongly influenced alternative-pop aesthetics in the 2010s and beyond." }
  ],
  Leo: [
    { name: "Barack Obama", field: "Politics / Media", years: "b. 1961", fact: "As U.S. president, he combined policy influence with unmatched modern speech communication impact." },
    { name: "Jennifer Lopez", field: "Music / Film", years: "b. 1969", fact: "She sustained crossover success in music, film, and touring over multiple industry cycles." },
    { name: "Madonna", field: "Music", years: "b. 1958", fact: "Her reinvention strategy became a blueprint for longevity in mainstream global pop careers." },
    { name: "Daniel Radcliffe", field: "Film / Stage", years: "b. 1989", fact: "After Potter, he rebuilt his profile through eclectic stage and independent screen choices." },
    { name: "Chris Hemsworth", field: "Film", years: "b. 1983", fact: "His Thor role and action portfolio made him a consistent global studio lead." },
    { name: "Mila Kunis", field: "Film / Television", years: "b. 1983", fact: "She successfully moved from long-running TV comedy into mainstream film and voice work." },
    { name: "Charlize Theron", field: "Film / Production", years: "b. 1975", fact: "She combined Oscar-level dramatic work with action-franchise credibility and producer leadership." },
    { name: "Jason Momoa", field: "Film / TV", years: "b. 1979", fact: "Aquaman and TV fantasy hits turned him into a durable international action persona." },
    { name: "Kylie Jenner", field: "Business / Media", years: "b. 1997", fact: "She converted social-media reach into one of the most visible celebrity beauty businesses." },
    { name: "Dua Lipa", field: "Music", years: "b. 1995", fact: "Her catalog and touring scale made her a core pop headliner in the 2020s." }
  ],
  Virgo: [
    { name: "Beyoncé", field: "Music / Performance", years: "b. 1981", fact: "Her visual albums and stadium tours set precision standards for modern live production." },
    { name: "Keanu Reeves", field: "Film", years: "b. 1964", fact: "The John Wick era renewed his global profile with a highly disciplined action identity." },
    { name: "Zendaya", field: "Film / Television", years: "b. 1996", fact: "She moved quickly from youth TV to Emmy-winning roles and major film franchises." },
    { name: "Tom Hardy", field: "Film", years: "b. 1977", fact: "His intense character approach made him a frequent choice for high-pressure lead roles." },
    { name: "Blake Lively", field: "Film / Entrepreneurship", years: "b. 1987", fact: "She maintained screen visibility while expanding into premium brand and product ventures." },
    { name: "Idris Elba", field: "Film / Television", years: "b. 1972", fact: "His mix of prestige TV and franchise film work built broad multi-market recognition." },
    { name: "Nick Jonas", field: "Music / Film", years: "b. 1992", fact: "He transitioned from teen pop roots into diversified solo, acting, and touring output." },
    { name: "Cameron Diaz", field: "Film", years: "b. 1972", fact: "Her 1990s-2000s run made her one of the era's most bankable comedy stars." },
    { name: "P!nk", field: "Music", years: "b. 1979", fact: "Her vocal durability and high-intensity acrobatic shows define one of touring's strongest reputations." },
    { name: "Michael Bublé", field: "Music", years: "b. 1975", fact: "He modernized classic vocal-pop repertoire and sustained a durable global live audience." }
  ],
  Libra: [
    { name: "Kim Kardashian", field: "Media / Business", years: "b. 1980", fact: "She helped define creator-era celebrity commerce through direct-to-consumer beauty and lifestyle brands." },
    { name: "Will Smith", field: "Film / Music", years: "b. 1968", fact: "He achieved rare crossover success as both blockbuster actor and charting recording artist." },
    { name: "Serena Williams", field: "Tennis / Business", years: "b. 1981", fact: "Her Grand Slam dominance transformed expectations around longevity and power in women's tennis." },
    { name: "Bruno Mars", field: "Music", years: "b. 1985", fact: "He combines songwriting precision with high-energy live shows that repeatedly drive global hits." },
    { name: "Zac Efron", field: "Film", years: "b. 1987", fact: "He evolved from teen-musical fame into mainstream comedy and dramatic streaming projects." },
    { name: "Hugh Jackman", field: "Film / Stage", years: "b. 1968", fact: "He balanced Wolverine franchise scale with award-level musical theater and dramatic work." },
    { name: "Snoop Dogg", field: "Music / Media", years: "b. 1971", fact: "His long media run shows rare adaptability across music, sports entertainment, and branding." },
    { name: "Gwen Stefani", field: "Music / Fashion", years: "b. 1969", fact: "She built enduring visibility by combining pop reinvention with strong fashion positioning." },
    { name: "Kate Winslet", field: "Film", years: "b. 1975", fact: "Her career sustained high critical credibility while retaining major mainstream audience relevance." },
    { name: "Eminem", field: "Music", years: "b. 1972", fact: "His lyrical technicality and sales scale shaped mainstream rap metrics for two decades." }
  ],
  Scorpio: [
    { name: "Leonardo DiCaprio", field: "Film / Environmental Advocacy", years: "b. 1974", fact: "He combined long-term box-office power with high-visibility climate and conservation campaigning." },
    { name: "Ryan Gosling", field: "Film", years: "b. 1980", fact: "He maintained leading-man demand through selective roles spanning indie prestige and global blockbusters." },
    { name: "Anne Hathaway", field: "Film", years: "b. 1982", fact: "Her transition from family films to Oscar-winning drama established broad performance range." },
    { name: "Emma Stone", field: "Film", years: "b. 1988", fact: "She built a strong awards profile while staying commercially viable in studio projects." },
    { name: "Drake", field: "Music", years: "b. 1986", fact: "His chart consistency and streaming numbers made him a defining artist of the era." },
    { name: "Kendall Jenner", field: "Fashion / Media", years: "b. 1995", fact: "She became a global runway and campaign fixture while scaling cross-platform media reach." },
    { name: "Bill Gates", field: "Technology / Philanthropy", years: "b. 1955", fact: "After Microsoft leadership, he became one of the largest private funders of global health." },
    { name: "Gordon Ramsay", field: "Culinary / Television", years: "b. 1966", fact: "He expanded chef status into an international television and restaurant brand network." },
    { name: "Julia Roberts", field: "Film", years: "b. 1967", fact: "Her 1990s star run and continued screen presence built one of cinema's biggest names." },
    { name: "Winona Ryder", field: "Film / Television", years: "b. 1971", fact: "Stranger Things introduced her to a new generation while renewing her cultural relevance." }
  ],
  Sagittarius: [
    { name: "Taylor Swift", field: "Music", years: "b. 1989", fact: "Her rerecording strategy and stadium demand changed artist ownership conversations at industry scale." },
    { name: "Brad Pitt", field: "Film / Production", years: "b. 1963", fact: "He sustained A-list longevity while producing multiple award-winning films through his studio." },
    { name: "Nicki Minaj", field: "Music", years: "b. 1982", fact: "She expanded women-led mainstream rap visibility and influenced a generation of performers." },
    { name: "Jay-Z", field: "Music / Business", years: "b. 1969", fact: "He built one of the strongest artist-to-investor transitions in modern entertainment business." },
    { name: "Britney Spears", field: "Music", years: "b. 1981", fact: "Her early-2000s impact helped define the global teen-pop template and performance style." },
    { name: "Miley Cyrus", field: "Music / Television", years: "b. 1992", fact: "She repeatedly reinvented her sound while keeping strong mainstream attention across cycles." },
    { name: "Samuel L. Jackson", field: "Film", years: "b. 1948", fact: "His prolific output made him one of the highest-grossing actors in film history." },
    { name: "Ben Stiller", field: "Film / Direction", years: "b. 1965", fact: "He combined comedy acting and directing into durable commercial and critical television success." },
    { name: "Christina Aguilera", field: "Music", years: "b. 1980", fact: "Her vocal power and era-defining singles established long-term influence in pop performance." },
    { name: "Billie Eilish", field: "Music", years: "b. 2001", fact: "She reached global scale early with a minimalist sonic identity and strong award trajectory." }
  ],
  Capricorn: [
    { name: "Denzel Washington", field: "Film", years: "b. 1954", fact: "He remains a benchmark for dramatic authority and consistency across several decades." },
    { name: "LeBron James", field: "Basketball / Media", years: "b. 1984", fact: "His on-court longevity and off-court media ventures set a modern athlete-business template." },
    { name: "Michelle Obama", field: "Public Leadership", years: "b. 1964", fact: "She built one of the strongest modern civic influence platforms beyond formal office." },
    { name: "Bradley Cooper", field: "Film", years: "b. 1975", fact: "He transitioned from comedic roles into critically acclaimed directing and dramatic performance work." },
    { name: "Timothée Chalamet", field: "Film", years: "b. 1995", fact: "He became a rare young actor balancing indie prestige and major studio franchise scale." },
    { name: "Kate Middleton", field: "Public Figure", years: "b. 1982", fact: "Her sustained public profile shapes modern royal communications and philanthropy visibility." },
    { name: "Dolly Parton", field: "Music / Philanthropy", years: "b. 1946", fact: "Her songwriting legacy pairs with large literacy philanthropy and strong multi-generation cultural reach." },
    { name: "John Legend", field: "Music", years: "b. 1978", fact: "He combines acclaimed songwriting with broad television and live-performance visibility." },
    { name: "Jim Carrey", field: "Film / Comedy", years: "b. 1962", fact: "His physical comedy style changed 1990s mainstream humor and remains widely referenced." },
    { name: "Nina Dobrev", field: "Television / Film", years: "b. 1989", fact: "Her TV franchise visibility translated into sustained global fan engagement and screen presence." }
  ],
  Aquarius: [
    { name: "Shakira", field: "Music", years: "b. 1977", fact: "Her bilingual catalog and touring power made her one of Latin music's biggest globals." },
    { name: "Harry Styles", field: "Music / Film", years: "b. 1994", fact: "He successfully transitioned from boy-band fame into solo arena-level artist status." },
    { name: "Jennifer Aniston", field: "Television / Film", years: "b. 1969", fact: "Friends-era visibility evolved into lasting film and streaming lead relevance." },
    { name: "Cristiano Ronaldo", field: "Football", years: "b. 1985", fact: "His goal records and brand scale set one of modern sport's largest personal platforms." },
    { name: "Alicia Keys", field: "Music", years: "b. 1981", fact: "She built a long-running catalog anchored by songwriting craft and live vocal credibility." },
    { name: "Ed Sheeran", field: "Music", years: "b. 1991", fact: "His songwriting pipeline repeatedly produced global hits across pop and acoustic formats." },
    { name: "Oprah Winfrey", field: "Media / Business", years: "b. 1954", fact: "Her media empire reshaped talk-format influence and long-form audience trust economics." },
    { name: "Michael Jordan", field: "Basketball / Business", years: "b. 1963", fact: "His competitive legacy and brand partnerships still define modern athlete commercial scale." },
    { name: "The Weeknd", field: "Music", years: "b. 1990", fact: "He merged cinematic pop and dark R&B into one of streaming's biggest catalogs." },
    { name: "Ashton Kutcher", field: "Film / Technology Investing", years: "b. 1978", fact: "He moved from TV stardom into early-stage tech investing with notable exits." }
  ],
  Pisces: [
    { name: "Rihanna", field: "Music / Business", years: "b. 1988", fact: "She expanded from chart dominance into a global beauty and fashion business empire." },
    { name: "Justin Bieber", field: "Music", years: "b. 1994", fact: "His long career from teen breakout to adult pop star remains unusually resilient." },
    { name: "Bad Bunny", field: "Music", years: "b. 1994", fact: "He proved Spanish-language releases can lead global charts without format compromise." },
    { name: "Olivia Rodrigo", field: "Music / Acting", years: "b. 2003", fact: "Her debut songwriting impact made her one of the fastest global pop breakouts." },
    { name: "Drew Barrymore", field: "Film / Television", years: "b. 1975", fact: "She built one of entertainment's longest careers, spanning child acting to daytime hosting." },
    { name: "Camila Cabello", field: "Music", years: "b. 1997", fact: "Her solo transition produced major global singles and sustained cross-market audience reach." },
    { name: "Eva Mendes", field: "Film / Business", years: "b. 1974", fact: "She combined mainstream film work with commercial partnerships in fashion and home categories." },
    { name: "Daniel Craig", field: "Film", years: "b. 1968", fact: "His Bond era reset the franchise tone with a grounded and physical character style." },
    { name: "Shaquille O'Neal", field: "Basketball / Media", years: "b. 1972", fact: "He translated dominant sports fame into durable broadcasting and business entertainment presence." },
    { name: "Simone Biles", field: "Gymnastics", years: "b. 1997", fact: "Her difficulty level and medal record redefined the ceiling for modern gymnastics performance." }
  ]
};

const femaleCelebrityNames = new Set([
  "Lady Gaga",
  "Emma Watson",
  "Mariah Carey",
  "Reese Witherspoon",
  "Celine Dion",
  "Adele",
  "Gigi Hadid",
  "Megan Fox",
  "Gal Gadot",
  "Tina Fey",
  "Cher",
  "Angelina Jolie",
  "Natalie Portman",
  "Heidi Klum",
  "Naomi Campbell",
  "Awkwafina",
  "Ariana Grande",
  "Selena Gomez",
  "Meryl Streep",
  "Margot Robbie",
  "Lana Del Rey",
  "Jennifer Lopez",
  "Madonna",
  "Mila Kunis",
  "Charlize Theron",
  "Kylie Jenner",
  "Dua Lipa",
  "Beyoncé",
  "Zendaya",
  "Blake Lively",
  "Cameron Diaz",
  "P!nk",
  "Kim Kardashian",
  "Serena Williams",
  "Gwen Stefani",
  "Kate Winslet",
  "Anne Hathaway",
  "Emma Stone",
  "Kendall Jenner",
  "Julia Roberts",
  "Winona Ryder",
  "Taylor Swift",
  "Nicki Minaj",
  "Britney Spears",
  "Miley Cyrus",
  "Christina Aguilera",
  "Michelle Obama",
  "Kate Middleton",
  "Dolly Parton",
  "Nina Dobrev",
  "Shakira",
  "Jennifer Aniston",
  "Alicia Keys",
  "Oprah Winfrey",
  "Rihanna",
  "Olivia Rodrigo",
  "Drew Barrymore",
  "Camila Cabello",
  "Eva Mendes",
  "Simone Biles"
]);

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
      imageUrlLight: "",
      imageUrlDark: "",
      brief: "Core sign context is currently unavailable.",
      natal: "Sign-specific interpretation is currently unavailable.",
      compact: "No sign summary available yet."
    };
  }
  const signAsset = String(normalized || "").toLowerCase();
  const imageUrlDark = `${zodiacAssetBaseUrl}/${signAsset}-black.png`;
  const imageUrlLight = `${zodiacAssetBaseUrl}/${signAsset}-white.png`;
  const model = {
    sign: normalized,
    imageUrl: state.theme === "light" ? imageUrlLight : imageUrlDark,
    imageUrlLight,
    imageUrlDark,
    brief: meta.brief,
    natal: meta.natal,
    compact: meta.compact,
    element: zodiacElements[normalized] || "Unknown",
    modality: zodiacModalities[normalized] || "Unknown"
  };
  return model;
}

function syncZodiacThemeImages(theme = state.theme) {
  const desiredSuffix = theme === "light" ? "-white.png" : "-black.png";
  document.querySelectorAll("img[data-zodiac-light][data-zodiac-dark]").forEach((img) => {
    const light = img.getAttribute("data-zodiac-light") || "";
    const dark = img.getAttribute("data-zodiac-dark") || "";
    const current = img.getAttribute("src") || "";
    const pool = [light, dark, current].filter(Boolean);
    const bySuffix = pool.find((url) => url.toLowerCase().endsWith(desiredSuffix));
    const fallback = theme === "light" ? light : dark;
    const next = bySuffix || fallback;
    if (next && img.getAttribute("src") !== next) {
      img.setAttribute("src", next);
    }
  });
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
  transit: "mdi:orbit",
  email: "mdi:email-outline",
  google: "mdi:google",
  telegram: "mdi:telegram"
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

function zodiacFromAngle(angleDeg) {
  const norm = normalizeAngle(angleDeg);
  const idx = Math.floor(norm / 30) % 12;
  return zodiacOrder[idx] || "Aries";
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

function escapeHtml(text) {
  return String(text || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function celebrityGender(name) {
  return femaleCelebrityNames.has(String(name || "").trim()) ? "female" : "male";
}

function celebrityBirthYear(years) {
  const match = String(years || "").match(/(\d{4})/);
  return match ? Number(match[1]) : null;
}

function celebrityAgeLabel(years) {
  const birthYear = celebrityBirthYear(years);
  if (!birthYear) {
    return years || "";
  }
  const currentYear = new Date().getUTCFullYear();
  return `Age ${Math.max(0, currentYear - birthYear)}`;
}

function zodiacPolarity(sign) {
  const s = resolveZodiacSign(sign);
  return ["Aries", "Gemini", "Leo", "Libra", "Sagittarius", "Aquarius"].includes(s) ? "Yang" : "Yin";
}

function celebrityAstroChips(sign, years) {
  const s = resolveZodiacSign(sign);
  const element = zodiacElements[s] || "Unknown";
  const modality = zodiacModalities[s] || "Unknown";
  const polarity = zodiacPolarity(s);
  const age = celebrityAgeLabel(years);
  return [`Element: ${element}`, `Mode: ${modality}`, `Polarity: ${polarity}`, age].filter(Boolean);
}

function celebrityAvatarDataUrl(name, gender) {
  const g = gender === "female" ? "female" : "male";
  const seed = encodeURIComponent(String(name || "User").trim() || "User");
  const style = "lorelei-neutral";
  const base = "https://api.dicebear.com/9.x";
  return `${base}/${style}/svg?seed=${seed}&size=64&flip=${g === "female" ? "false" : "true"}&backgroundColor=transparent`;
}

function buildFriendEnergySeries(dashboard, period, baseSeries) {
  const friends = Array.isArray(dashboard?.friendsDynamic) ? dashboard.friendsDynamic : [];
  if (!friends.length) {
    return [];
  }
  const values = Array.isArray(baseSeries?.values) ? baseSeries.values : [];
  const count = values.length;
  if (!count) {
    return [];
  }
  return friends.map((friend, index) => {
    const friendName = String(friend?.friendName || `Friend ${index + 1}`).trim() || `Friend ${index + 1}`;
    const score = Math.max(0, Math.min(100, Number(friend?.score) || 50));
    const trend = String(friend?.trend || "stable").trim().toLowerCase();
    const trendBias = trend === "high" ? 2.2 : trend === "fragile" ? -2.6 : 0;
    const seed = stringHash(`${friend?.id || friendName}:${period}:${score}`);
    const friendValues = values.map((userValue, pointIndex) => {
      const waveA = Math.sin((pointIndex + 1) * 0.91 + (seed % 17)) * 6.3;
      const waveB = Math.cos((pointIndex + 1) * 0.47 + (seed % 11)) * 4.1;
      const micro = ((seed + pointIndex * 13) % 7) - 3;
      const anchor = userValue * 0.24 + score * 0.76;
      return Math.max(8, Math.min(96, Math.round(anchor + waveA + waveB + trendBias + micro * 0.65)));
    });
    const avg = Math.round(friendValues.reduce((sum, value) => sum + value, 0) / Math.max(1, friendValues.length));
    return {
      id: String(friend?.id || friendName),
      name: friendName,
      values: friendValues,
      today: friendValues[todayIndexForPeriod(period, friendValues.length)] || friendValues[0] || 0,
      avg
    };
  });
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
  const friendSeries = buildFriendEnergySeries(dashboard, period, series);
  const friendPaths = friendSeries.map((friend) => {
    const friendPoints = friend.values.map((value, index) => ({
      x: padX + index * stepX,
      y: toY(value)
    }));
    return {
      id: friend.id,
      name: friend.name,
      path: buildSmoothPath(friendPoints)
    };
  });

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
        ${friendPaths
          .map(
            (friend) => `
              <path class="energy-friend-line" d="${friend.path}" />
              <path class="energy-friend-hit" d="${friend.path}" data-friend-name="${escapeHtml(friend.name)}" />
            `
          )
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
        ${friendPaths.length ? `<span><i class="dot friend"></i> Friend trajectories</span>` : ""}
      </div>
      <div class="energy-friend-tooltip" aria-hidden="true"></div>
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
    ${renderFriendEnergyTable(dashboard, period, series)}
  `;
}

function renderFriendEnergyTable(dashboard, period, baseSeries = null) {
  const series = baseSeries || buildEnergySeries(dashboard, period);
  const friendSeries = buildFriendEnergySeries(dashboard, period, series);
  if (!friendSeries.length) {
    return "";
  }
  return `
    <div class="friend-energy-table-wrap">
      <h3>Friend trends</h3>
      <table class="friend-energy-table">
        <thead>
          <tr>
            <th>Friend</th>
            <th>Today</th>
            <th>Avg</th>
          </tr>
        </thead>
        <tbody>
          ${friendSeries
            .map(
              (friend) => `
                <tr>
                  <td>${escapeHtml(friend.name)}</td>
                  <td>${friend.today}</td>
                  <td>${friend.avg}</td>
                </tr>
              `
            )
            .join("")}
        </tbody>
      </table>
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
  const total = Math.round(bodies.reduce((sum, body) => sum + (Number(body.value) || 0), 0) / Math.max(1, bodies.length));
  return `
    <article class="astro-viz-card astro-viz-card-current">
      <div class="astro-viz-head">
        <h3>Current sky state</h3>
        <span class="astro-viz-badge">phase index ${total}/100</span>
      </div>
      <svg class="astro-viz-svg" viewBox="0 0 420 220" role="img" aria-label="Current planetary state">
        <g class="astro-viz-core">
          <circle class="astro-viz-ring-dashed" cx="${center.x}" cy="${center.y}" r="${rings[2] + 7}" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="${rings[2]}" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="${rings[1]}" />
          <circle class="astro-viz-ring" cx="${center.x}" cy="${center.y}" r="${rings[0]}" />
          ${bodies
            .map((body, i) => {
              const p = pointFromAngle(center.x, center.y, rings[i], body.angle);
              const nodeRadius = i === 0 ? 5.6 : 4.8;
              const orbitRadius = nodeRadius + (i === 0 ? 4.8 : 4.2);
              const spinDuration = (8 + i * 2.2).toFixed(1);
              const vx = p.x - center.x;
              const vy = p.y - center.y;
              const length = Math.hypot(vx, vy) || 1;
              const ux = vx / length;
              const uy = vy / length;
              const rayStartPad = 7;
              const rayEndPad = nodeRadius + 3;
              const rayX1 = center.x + ux * rayStartPad;
              const rayY1 = center.y + uy * rayStartPad;
              const rayX2 = p.x - ux * rayEndPad;
              const rayY2 = p.y - uy * rayEndPad;
              const from = i % 2 === 0 ? "0" : "360";
              const to = i % 2 === 0 ? "360" : "0";
              return `
                <line class="astro-viz-ray" x1="${rayX1}" y1="${rayY1}" x2="${rayX2}" y2="${rayY2}" />
                <circle class="astro-viz-node" cx="${p.x}" cy="${p.y}" r="${nodeRadius}" style="fill:${colors[i]}" />
                <g class="astro-viz-satellite-system">
                  <circle class="astro-viz-sat-orbit" cx="${p.x}" cy="${p.y}" r="${orbitRadius}" />
                  <circle class="astro-viz-sat-dot" cx="${p.x}" cy="${p.y - orbitRadius}" r="1.5" />
                  <animateTransform
                    attributeName="transform"
                    attributeType="XML"
                    type="rotate"
                    from="${from} ${p.x} ${p.y}"
                    to="${to} ${p.x} ${p.y}"
                    dur="${spinDuration}s"
                    repeatCount="indefinite"
                  />
                </g>
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
                <text class="astro-viz-angle" x="0" y="${58 + i * 54}">angle ${Math.round(Number(body.angle) || 0)}° · ring ${i + 1}</text>
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

    const wrap = svg.closest(".energy-chart-wrap");
    const tooltip = wrap?.querySelector(".energy-friend-tooltip");
    if (!(tooltip instanceof HTMLElement) || !(wrap instanceof HTMLElement)) {
      return;
    }
    const showFriendTooltip = (event, name) => {
      tooltip.textContent = name;
      tooltip.style.opacity = "1";
      tooltip.style.transform = "translate(-50%, -130%)";
      const rect = wrap.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const y = event.clientY - rect.top;
      tooltip.style.left = `${x}px`;
      tooltip.style.top = `${y}px`;
    };
    const hideFriendTooltip = () => {
      tooltip.style.opacity = "0";
    };
    svg.querySelectorAll(".energy-friend-hit").forEach((path) => {
      path.addEventListener("mouseenter", (event) => {
        const name = path.getAttribute("data-friend-name") || "Friend";
        showFriendTooltip(event, name);
      });
      path.addEventListener("mousemove", (event) => {
        const name = path.getAttribute("data-friend-name") || "Friend";
        showFriendTooltip(event, name);
      });
      path.addEventListener("mouseleave", hideFriendTooltip);
    });
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
  const dailyFocus = personalizedDailyLine(dashboard?.daily?.focus || "", {
    dayKey: new Date().toISOString().slice(0, 10),
    core: dashboard?.natalCore,
    profile
  });
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
      <p class="muted">${dailyFocus}</p>
    </div>
  `;
}

function profileFirstName(profile) {
  const name = String(profile?.name || "").trim();
  return name.split(/\s+/).filter(Boolean)[0] || "You";
}

function personalizedDailyLine(baseText, { dayKey = "", core = null, profile = null } = {}) {
  const cleanedBase = String(baseText || "").trim();
  const sun = resolveZodiacSign(core?.sun || "Sun");
  const moon = resolveZodiacSign(core?.moon || "Moon");
  const rising = resolveZodiacSign(core?.rising || "Rising");
  const who = profileFirstName(profile);
  const seed = Math.abs(stringHash(`${dayKey}:${sun}:${moon}:${rising}:${cleanedBase}`));
  const openers = [
    `${who}, start with one high-friction conversation before noon and lock next steps in writing.`,
    `${who}, protect signal quality first: clarify one unclear expectation before starting execution.`,
    `${who}, run one decisive dialogue today that prevents a week of background tension.`,
    `${who}, choose precision over speed in communication: one clear message can save multiple loops.`,
    `${who}, anchor today's social load with one proactive check-in and one explicit boundary.`
  ];
  const bridges = [
    `Use ${sun} direction for intent, ${moon} for tone, and ${rising} for timing.`,
    `${sun} supports leadership framing, while ${moon} helps regulate emotional bandwidth.`,
    `With ${rising} active in your behavior layer, concise language will outperform long explanations.`,
    `${moon} asks for cleaner boundaries, and ${sun} asks for explicit ownership.`,
    `${sun}/${moon}/${rising} alignment is strongest when commitment and timeline are both named.`
  ];
  const opener = openers[seed % openers.length];
  const bridge = bridges[(seed >> 3) % bridges.length];
  return cleanedBase ? `${opener} ${bridge}` : `${opener}`;
}

function personalizeDailyHistory(history, { core = null, profile = null } = {}) {
  const list = Array.isArray(history) ? history : [];
  return list.map((item, index) => {
    const dayKey = String(item?.dayKey || "").trim() || `day-${index}`;
    return {
      ...item,
      dayKey,
      focus: personalizedDailyLine(item?.focus || "", { dayKey: `${dayKey}:${index}`, core, profile })
    };
  });
}

function renderNatalZodiacSection(sign) {
  const details = zodiacDetails(sign);
  const deep = zodiacLongRead(sign);
  const signLabel = details.sign === "Unknown" ? "Sign" : details.sign;
  const chips = [
    `Element: ${details.element}`,
    `Mode: ${details.modality}`,
    "Signal: identity"
  ];
  const narrative = `${details.natal} ${details.brief} ${deep.structural} ${deep.dynamics} ${deep.practical}`;
  return `
    <section class="section" id="natal-zodiac-sign">
      <article class="route-card content-panel premium-panel zodiac-natal-card">
        <span class="premium-kicker">Archetype</span>
        <h2>${signLabel}</h2>
        <div class="zodiac-sign-image-wrap zodiac-sign-image-wrap-natal">
          ${
            details.imageUrl
              ? `<img class="zodiac-sign-image zodiac-sign-image-natal" src="${details.imageUrl}" data-zodiac-light="${details.imageUrlLight}" data-zodiac-dark="${details.imageUrlDark}" alt="${signLabel} zodiac illustration" loading="lazy" decoding="async" />`
              : `<div class="zodiac-sign-fallback">${zodiacIcon(signLabel)} ${signLabel}</div>`
          }
        </div>
        <p class="zodiac-natal-text">${narrative}</p>
        <div class="zodiac-chip-row zodiac-natal-chips">
          ${chips.map((chip) => `<span class="zodiac-chip">${chip}</span>`).join("")}
        </div>
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
                ? `<img class="zodiac-sign-image compact" src="${details.imageUrl}" data-zodiac-light="${details.imageUrlLight}" data-zodiac-dark="${details.imageUrlDark}" alt="${signLabel} zodiac illustration" loading="lazy" decoding="async" />`
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

function renderZodiacCelebrities(sign) {
  const signLabel = resolveZodiacSign(sign);
  const entries = Array.isArray(zodiacCelebrities[signLabel]) ? zodiacCelebrities[signLabel] : [];
  if (!entries.length) {
    return "";
  }
  return `
    <section class="section">
      <article class="card celeb-block">
        <span class="eyebrow">Zodiac network</span>
        <h2>Famous ${signLabel} Profiles</h2>
        <p>A quick reference set of public figures born under your solar sign for inspiration, style cues, and behavioral patterns.</p>
        <div class="celeb-grid">
          ${entries
            .map((item) => {
              const gender = celebrityGender(item.name);
              const genderIcon = gender === "female" ? "♀" : "♂";
              const chips = celebrityAstroChips(signLabel, item.years);
              const avatar = celebrityAvatarDataUrl(item.name, gender);
              return `
                <article class="celeb-card ${gender === "female" ? "is-female" : "is-male"}">
                  <div class="celeb-head">
                    <img class="celeb-avatar" src="${avatar}" alt="${escapeHtml(item.name)} avatar" loading="lazy" decoding="async" />
                    <div class="celeb-head-copy">
                      <h3>${item.name}</h3>
                      <p class="celeb-meta">${item.field} · ${item.years}</p>
                    </div>
                    <span class="celeb-gender" aria-label="${gender === "female" ? "female" : "male"}">${genderIcon}</span>
                  </div>
                  <div class="celeb-chip-row">
                    ${chips.map((chip) => `<span class="celeb-chip">${escapeHtml(chip)}</span>`).join("")}
                  </div>
                  <p>${item.fact}</p>
                </article>
              `;
            })
            .join("")}
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
            ? `<img class="friend-sign-image" src="${details.imageUrl}" data-zodiac-light="${details.imageUrlLight}" data-zodiac-dark="${details.imageUrlDark}" alt="${signLabel} zodiac illustration" loading="lazy" decoding="async" />`
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

function renderFriendAccordion(friend, { expanded = false, canDelete = false } = {}) {
  const score = Math.max(0, Math.min(100, Math.round(Number(friend?.score) || 0)));
  const highlights = Array.isArray(friend?.highlights) ? friend.highlights : [];
  const domains = Array.isArray(friend?.domains) ? friend.domains : [];
  const friendCore = friend?.natalMini?.core || {
    sun: friend?.friendSign || "Unknown",
    moon: "Unknown",
    rising: "Unknown"
  };
  const shareEnabled = !friend?.noShareData && (String(friend?.friendTelegram || "").trim() || String(friend?.friendEmail || "").trim());
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
        <div class="friend-mini-natal">
          <span>${zodiacIcon(friendCore.sun)} Sun: ${friendCore.sun}</span>
          <span>${zodiacIcon(friendCore.moon)} Moon: ${friendCore.moon}</span>
          <span>${zodiacIcon(friendCore.rising)} Rising: ${friendCore.rising}</span>
          <span>Birth date: ${friend.friendBirthDate || "N/A"}</span>
          <span>Birth time: ${friend.friendBirthTime || "N/A"}</span>
          <span>Birth place: ${friend.friendBirthCity || "N/A"}</span>
        </div>
        ${friend?.natalMini?.summary ? `<p class="muted">${friend.natalMini.summary}</p>` : ""}
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
          ${
            shareEnabled
              ? `<button class="btn ghost js-share-friend" type="button" data-name="${friend.friendName}" data-sign="${friend.friendSign}" data-score="${score}" data-telegram="${friend.friendTelegram || ""}" data-email="${friend.friendEmail || ""}">Share with friend</button>`
              : `<p class="muted">Sharing unavailable: no contact method saved.</p>`
          }
          ${
            canDelete
              ? `<button class="btn ghost js-delete-friend" type="button" data-id="${friend.id || ""}" data-name="${friend.friendName || "Friend"}">Remove friend</button>`
              : ""
          }
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

const solarPlanetModel = [
  { key: "Sun", label: "Sun", periodDays: Infinity, phase: 0, radius: 0, size: 0.36 },
  { key: "Mercury", label: "Mercury", periodDays: 87.97, phase: 252.25, radius: 1.25, size: 0.11 },
  { key: "Venus", label: "Venus", periodDays: 224.7, phase: 181.97, radius: 1.8, size: 0.13 },
  { key: "Earth", label: "Earth", periodDays: 365.25, phase: 100.46, radius: 2.4, size: 0.14 },
  { key: "Moon", label: "Moon", periodDays: 27.32, phase: 38.0, radius: 0.38, size: 0.055, parent: "Earth" },
  { key: "Mars", label: "Mars", periodDays: 686.98, phase: 355.45, radius: 3.15, size: 0.12 },
  { key: "Jupiter", label: "Jupiter", periodDays: 4332.59, phase: 34.4, radius: 4.25, size: 0.2 },
  { key: "Saturn", label: "Saturn", periodDays: 10759.22, phase: 49.94, radius: 5.2, size: 0.18 },
  { key: "Uranus", label: "Uranus", periodDays: 30688.5, phase: 313.23, radius: 6.05, size: 0.16 },
  { key: "Neptune", label: "Neptune", periodDays: 60182, phase: 304.88, radius: 6.9, size: 0.16 }
];

let threeRuntimePromise = null;

function clampScore(value) {
  return Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
}

function daysSinceJ2000(date = new Date()) {
  const epoch = Date.UTC(2000, 0, 1, 12, 0, 0);
  return (date.getTime() - epoch) / 86400000;
}

function meanPlanetAngle(days, periodDays, phase) {
  if (!Number.isFinite(periodDays) || periodDays <= 0) {
    return 0;
  }
  const cycle = ((days / periodDays) * 360 + phase) % 360;
  return ((cycle + 360) % 360) * (Math.PI / 180);
}

function solarPositionsAt(date = new Date()) {
  const days = daysSinceJ2000(date);
  const byKey = {};
  solarPlanetModel.forEach((planet) => {
    if (planet.key === "Sun") {
      byKey[planet.key] = { x: 0, z: 0, angle: 0 };
      return;
    }
    if (planet.parent === "Earth") {
      const earth = byKey.Earth || { x: 0, z: 0 };
      const a = meanPlanetAngle(days, planet.periodDays, planet.phase);
      byKey[planet.key] = {
        x: earth.x + Math.cos(a) * planet.radius,
        z: earth.z + Math.sin(a) * planet.radius,
        angle: a
      };
      return;
    }
    const a = meanPlanetAngle(days, planet.periodDays, planet.phase);
    byKey[planet.key] = {
      x: Math.cos(a) * planet.radius,
      z: Math.sin(a) * planet.radius,
      angle: a
    };
  });
  return byKey;
}

function solarAspectBlueprint() {
  return {
    Sun: { title: "Core Identity", desc: "Primary will, visibility, and central priorities." },
    Mercury: { title: "Communication", desc: "Decision framing, messaging quality, and timing precision." },
    Venus: { title: "Relationships", desc: "Attraction patterns, value alignment, and social ease." },
    Earth: { title: "Stability", desc: "Grounding, body rhythm, and practical continuity." },
    Moon: { title: "Emotional Signal", desc: "Mood bandwidth, intuition clarity, and reactivity load." },
    Mars: { title: "Execution Drive", desc: "Action speed, courage under pressure, and conflict heat." },
    Jupiter: { title: "Expansion", desc: "Opportunity bandwidth, growth appetite, and confidence." },
    Saturn: { title: "Structure", desc: "Discipline, boundaries, and long-cycle reliability." },
    Uranus: { title: "Innovation", desc: "Experiment rate, disruption tolerance, and originality." },
    Neptune: { title: "Meaning Field", desc: "Imagination, symbolic patterning, and narrative coherence." }
  };
}

function buildSolarAspectModel(dashboard, period) {
  const base = solarAspectBlueprint();
  const series = buildEnergySeries(dashboard, period);
  const values = Array.isArray(series?.values) ? series.values : [50];
  const today = values[todayIndexForPeriod(period, values.length)] || 50;
  const peak = values[series?.peakIndex ?? 0] || today;
  const dip = values[series?.dipIndex ?? 0] || today;
  const intensity = Number(dashboard?.periodForecast?.intensity || today);
  const friendScores = (Array.isArray(dashboard?.friendsDynamic) ? dashboard.friendsDynamic : [])
    .map((item) => Number(item?.score))
    .filter((num) => Number.isFinite(num));
  const friendAvg = friendScores.length
    ? friendScores.reduce((sum, num) => sum + num, 0) / friendScores.length
    : intensity;
  const sun = dashboard?.natalCore?.sun || "Unknown";
  const moon = dashboard?.natalCore?.moon || "Unknown";
  const rising = dashboard?.natalCore?.rising || "Unknown";

  return {
    Sun: {
      ...base.Sun,
      score: clampScore(intensity * 0.68 + peak * 0.32),
      pulse: `${sun} signal driving this cycle`,
      detail: `Your core axis is anchored by ${sun}. High-value moves today come from visible ownership and clear intent.`
    },
    Mercury: {
      ...base.Mercury,
      score: clampScore(today * 0.6 + friendAvg * 0.2 + (100 - Math.abs(peak - dip)) * 0.2),
      pulse: `${sun} wording strategy`,
      detail: `Use concise, testable language. Communication is strongest when you compress ideas into one next action.`
    },
    Venus: {
      ...base.Venus,
      score: clampScore(friendAvg * 0.62 + today * 0.38),
      pulse: `${moon} trust calibration`,
      detail: `Relational quality improves through pace-matching and explicit expectations, especially in close collaboration.`
    },
    Earth: {
      ...base.Earth,
      score: clampScore((today + intensity) / 2),
      pulse: `${rising} operational posture`,
      detail: `Grounding is your throughput multiplier today: structure blocks before responding to external noise.`
    },
    Moon: {
      ...base.Moon,
      score: clampScore(today * 0.7 + dip * 0.3),
      pulse: `${moon} emotional bandwidth`,
      detail: `Emotional load is manageable when transitions are intentional. Protect recovery windows between major tasks.`
    },
    Mars: {
      ...base.Mars,
      score: clampScore(peak * 0.7 + today * 0.3),
      pulse: `${sun} drive expression`,
      detail: `Execution velocity is available. Start from one difficult move early, then keep cadence stable.`
    },
    Jupiter: {
      ...base.Jupiter,
      score: clampScore(intensity * 0.55 + peak * 0.25 + friendAvg * 0.2),
      pulse: `${rising} expansion vector`,
      detail: `Expansion is favorable when tied to a measurable upside, not open-ended exploration.`
    },
    Saturn: {
      ...base.Saturn,
      score: clampScore((100 - Math.abs(peak - dip)) * 0.6 + intensity * 0.4),
      pulse: `${sun} discipline frame`,
      detail: `Structure quality decides outcomes today: define constraints first, then execute inside them.`
    },
    Uranus: {
      ...base.Uranus,
      score: clampScore((peak - dip + 50) * 0.55 + today * 0.45),
      pulse: `${moon} adaptation threshold`,
      detail: `Innovation works best in bounded experiments. Keep risk local and feedback loops fast.`
    },
    Neptune: {
      ...base.Neptune,
      score: clampScore(today * 0.35 + dip * 0.25 + (100 - Math.abs(today - intensity)) * 0.4),
      pulse: `${moon} symbolic coherence`,
      detail: `Intuition is useful today, but only after translation into concrete operational language.`
    }
  };
  const scores = Object.values(model).map((item) => Number(item.score) || 0);
  const avg = clampScore(scores.reduce((sum, v) => sum + v, 0) / Math.max(1, scores.length));
  model.__all__ = {
    title: "System Overview",
    desc: "Macro coherence across the full solar map.",
    score: avg,
    pulse: `${rising} global orchestration`,
    detail: `Use this mode to read the system as one field. Prioritize sequences that align execution, recovery, and communication in one cadence.`
  };
  return model;
}

function renderSolarAspectPanel(aspect, planetLabel, { focused = false } = {}) {
  if (!aspect) {
    return `<div class="solar-aspect-empty">Hover a planet to inspect your life axis for today.</div>`;
  }
  const label = planetLabel === "__all__" ? "The whole system" : planetLabel;
  return `
    <span class="eyebrow">Live aspect</span>
    <h3>${label} · ${aspect.title}</h3>
    <span class="solar-focus-mode">${focused ? "Focus locked" : "Preview"}</span>
    <div class="solar-aspect-score-row">
      <strong>${aspect.score}/100</strong>
      <span>${aspect.pulse}</span>
    </div>
    <p class="solar-aspect-desc">${aspect.desc}</p>
    <p>${aspect.detail}</p>
  `;
}

function renderSolarMobileMatrix(aspects, selectedKey = "__all__") {
  const keys = ["__all__", "Sun", "Mercury", "Venus", "Earth", "Moon", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"];
  return `
    <div class="solar-mobile-matrix">
      ${keys
        .map((key) => {
          const a = key === "__all__" ? aspects.__all__ : aspects[key];
          if (!a) {
            return "";
          }
          return `<button class="solar-mobile-pill ${key === selectedKey ? "is-active" : ""}" type="button" data-solar-planet="${key}">
            <span>${key === "__all__" ? "The whole system" : key}</span>
            <strong>${a.score}</strong>
          </button>`;
        })
        .join("")}
    </div>
  `;
}

function renderSolarSceneInfo(dashboard, period) {
  const today = new Date().toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
  const periodLabel = period === "year" ? "Year" : period === "month" ? "Month" : "Week";
  const intensity = clampScore(dashboard?.periodForecast?.intensity || 0);
  const sun = dashboard?.natalCore?.sun || "Unknown";
  const moon = dashboard?.natalCore?.moon || "Unknown";
  const rising = dashboard?.natalCore?.rising || "Unknown";
  return `
    <div class="solar-scene-meta">
      <span>${today}</span>
      <span>${periodLabel} index ${intensity}/100</span>
      <span>Sun ${sun}</span>
      <span>Moon ${moon}</span>
      <span>Rising ${rising}</span>
    </div>
  `;
}

function renderSolarSystemBlock(dashboard, period) {
  const aspects = buildSolarAspectModel(dashboard, period);
  const selected = "__all__";
  return `
    <section class="section">
      <article class="card solar-system-card">
        <span class="eyebrow">Heliocentric map</span>
        <div class="dashboard-head">
          <h2>Solar System State</h2>
          <p class="muted">Live planetary geometry mapped to today's life domains.</p>
        </div>
        <div class="solar-system-layout" id="solarSystemWidget">
          <div class="solar-canvas-wrap" id="solarCanvasWrap">
            <canvas id="solarSystemCanvas" class="solar-canvas" aria-label="Interactive solar system view"></canvas>
            <div class="solar-starfield" aria-hidden="true"></div>
            <div id="solarSystemTooltip" class="solar-tooltip" aria-hidden="true"></div>
            <div id="solarFocusBadge" class="solar-focus-badge">Focus: The whole system</div>
            <div id="solarHouseOverlay" class="solar-house-overlay"></div>
            <div id="solarObjectOverlay" class="solar-object-overlay"></div>
            <aside class="solar-aspect-panel solar-scene-panel" id="solarAspectPanel">
              ${renderSolarAspectPanel(aspects[selected], selected, { focused: true })}
            </aside>
            ${renderSolarSceneInfo(dashboard, period)}
          </div>
        </div>
        <div id="solarMobileMatrixWrap">
          ${renderSolarMobileMatrix(aspects, selected)}
        </div>
      </article>
    </section>
  `;
}

async function ensureThreeRuntime() {
  if (!threeRuntimePromise) {
    threeRuntimePromise = import("https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js");
  }
  return threeRuntimePromise;
}

function destroySolarSystemWidget() {
  const runtime = state.solarSystem;
  if (!runtime) {
    return;
  }
  if (runtime.frameId) {
    window.cancelAnimationFrame(runtime.frameId);
  }
  if (runtime.resizeHandler) {
    window.removeEventListener("resize", runtime.resizeHandler);
  }
  if (runtime.canvas) {
    runtime.canvas.onpointermove = null;
    runtime.canvas.onpointerleave = null;
    runtime.canvas.onclick = null;
    runtime.canvas.onpointerdown = null;
  }
  if (runtime.focusGrid) {
    runtime.focusGrid.geometry?.dispose?.();
    runtime.focusGrid.material?.dispose?.();
  }
  const houseOverlay = document.getElementById("solarHouseOverlay");
  const objectOverlay = document.getElementById("solarObjectOverlay");
  if (houseOverlay) {
    houseOverlay.innerHTML = "";
  }
  if (objectOverlay) {
    objectOverlay.innerHTML = "";
  }
  runtime.renderer?.dispose?.();
  state.solarSystem = null;
}

function bindSolarMobileInteractions(aspects, onSelect = null) {
  const panel = document.getElementById("solarAspectPanel");
  const matrixWrap = document.getElementById("solarMobileMatrixWrap");
  const focusBadge = document.getElementById("solarFocusBadge");
  if (!panel || !matrixWrap) {
    return;
  }
  matrixWrap.querySelectorAll("[data-solar-planet]").forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.getAttribute("data-solar-planet") || "__all__";
      panel.innerHTML = renderSolarAspectPanel(aspects[key], key, { focused: true });
      animateSolarPanelText(panel);
      if (focusBadge) {
        focusBadge.textContent = key === "__all__" ? "Focus: The whole system" : `Focus: ${key}`;
      }
      matrixWrap.querySelectorAll(".solar-mobile-pill").forEach((pill) => pill.classList.remove("is-active"));
      button.classList.add("is-active");
      if (typeof onSelect === "function") {
        onSelect(key);
      }
    });
  });
}

function animateSolarPanelText(panel) {
  if (!(panel instanceof HTMLElement)) {
    return;
  }
  const targets = panel.querySelectorAll("h3, .solar-focus-mode, .solar-aspect-score-row span, .solar-aspect-desc, p:last-of-type");
  targets.forEach((node) => {
    const full = String(node.textContent || "");
    if (!full.trim()) {
      return;
    }
    node.textContent = "";
    const duration = Math.max(180, Math.min(520, full.length * 14));
    const start = performance.now();
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration);
      const length = Math.max(1, Math.round(full.length * (t * t)));
      node.textContent = full.slice(0, length);
      if (t < 1) {
        window.requestAnimationFrame(tick);
      }
    };
    window.requestAnimationFrame(tick);
  });
}

function planetTexturePalette(key) {
  const map = {
    Sun: ["#f2f2f2", "#d8d8d8", "#a3a3a3"],
    Mercury: ["#8f949d", "#c3c8d1", "#686d77"],
    Venus: ["#b9aaa0", "#e7ded4", "#8f7f73"],
    Earth: ["#7a8ca3", "#d6dee8", "#475569"],
    Moon: ["#b8b8bb", "#e5e5e8", "#808087"],
    Mars: ["#9b7f74", "#d2beb6", "#6e564e"],
    Jupiter: ["#b8a088", "#e1d2c2", "#88735f"],
    Saturn: ["#b09c7a", "#e0d4bf", "#7f6c51"],
    Uranus: ["#7ea3a6", "#cde1e2", "#4c7074"],
    Neptune: ["#6f87a8", "#c7d6e9", "#3f5678"]
  };
  return map[key] || ["#8f8f8f", "#d5d5d5", "#656565"];
}

function createPlanetTexture(THREE, key, theme = "dark") {
  const canvas = document.createElement("canvas");
  canvas.width = 256;
  canvas.height = 256;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    return null;
  }
  const [c1, c2, c3] = planetTexturePalette(key);
  const g = ctx.createRadialGradient(70, 64, 22, 128, 128, 180);
  g.addColorStop(0, c2);
  g.addColorStop(0.55, c1);
  g.addColorStop(1, c3);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const seed = Math.abs(stringHash(`${key}:${theme}`));
  const bandCount = 10 + (seed % 10);
  for (let i = 0; i < bandCount; i += 1) {
    const y = ((i + 1) / (bandCount + 1)) * canvas.height;
    const h = 8 + ((seed + i * 13) % 22);
    const alpha = 0.12 + ((seed + i * 17) % 28) / 180;
    ctx.fillStyle = `rgba(255,255,255,${alpha.toFixed(3)})`;
    ctx.fillRect(0, y, canvas.width, h);
    if (i % 2 === 0) {
      ctx.fillStyle = `rgba(0,0,0,${(alpha * 0.58).toFixed(3)})`;
      ctx.fillRect(0, y + Math.max(2, h * 0.45), canvas.width, Math.max(2, h * 0.28));
    }
  }
  for (let i = 0; i < 64; i += 1) {
    const x = (seed * (i + 3) * 17) % canvas.width;
    const y = (seed * (i + 7) * 19) % canvas.height;
    const r = ((seed + i * 11) % 7) + 1;
    const alpha = 0.05 + ((seed + i * 5) % 16) / 180;
    ctx.beginPath();
    ctx.fillStyle = `rgba(0,0,0,${alpha.toFixed(3)})`;
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  const gloss = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
  gloss.addColorStop(0, "rgba(255,255,255,0.16)");
  gloss.addColorStop(0.42, "rgba(255,255,255,0.03)");
  gloss.addColorStop(1, "rgba(0,0,0,0.22)");
  ctx.fillStyle = gloss;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}

function createGlowTexture(THREE, color = "#ffffff") {
  const c = document.createElement("canvas");
  c.width = 256;
  c.height = 256;
  const ctx = c.getContext("2d");
  if (!ctx) {
    return null;
  }
  const g = ctx.createRadialGradient(128, 128, 10, 128, 128, 128);
  g.addColorStop(0, color);
  g.addColorStop(0.25, "rgba(255,255,255,0.75)");
  g.addColorStop(0.55, "rgba(255,255,255,0.25)");
  g.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 256, 256);
  const tx = new THREE.CanvasTexture(c);
  tx.needsUpdate = true;
  return tx;
}

async function initSolarSystemWidget(dashboard, period) {
  const canvas = document.getElementById("solarSystemCanvas");
  const wrap = document.getElementById("solarCanvasWrap");
  const panel = document.getElementById("solarAspectPanel");
  const tooltip = document.getElementById("solarSystemTooltip");
  const focusBadge = document.getElementById("solarFocusBadge");
  const houseOverlay = document.getElementById("solarHouseOverlay");
  const objectOverlay = document.getElementById("solarObjectOverlay");
  const matrixWrap = document.getElementById("solarMobileMatrixWrap");
  if (!canvas || !wrap || !panel || !tooltip || !matrixWrap || !focusBadge || !houseOverlay || !objectOverlay) {
    destroySolarSystemWidget();
    return;
  }
  const aspects = buildSolarAspectModel(dashboard, period);
  matrixWrap.innerHTML = renderSolarMobileMatrix(aspects, "__all__");
  let selectedKey = "__all__";
  let focusBoostStartedAt = performance.now();
  bindSolarMobileInteractions(aspects, (key) => {
    selectedKey = key;
    focusBoostStartedAt = performance.now();
  });
  panel.innerHTML = renderSolarAspectPanel(aspects.__all__, "__all__", { focused: true });
  focusBadge.textContent = "Focus: The whole system";

  const preferReducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
  const canHover = window.matchMedia?.("(hover: hover)")?.matches;
  const isMobileScene = window.matchMedia?.("(max-width: 900px)")?.matches;

  destroySolarSystemWidget();

  let THREE;
  try {
    THREE = await ensureThreeRuntime();
  } catch {
    return;
  }
  if (!document.body.contains(canvas)) {
    return;
  }

  const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 200);
  camera.position.set(0, 9.5, 11);
  camera.lookAt(0, 0, 0);

  const isDark = state.theme === "dark";
  const ink = isDark ? 0xf2f2f2 : 0x121417;
  const muted = isDark ? 0x848992 : 0x5a6068;
  const dim = isDark ? 0x3d424a : 0xb8bec7;

  const ambient = new THREE.AmbientLight(isDark ? 0xffffff : 0xf8f9fb, 0.9);
  scene.add(ambient);
  const keyLight = new THREE.PointLight(isDark ? 0xffffff : 0x111111, 0.78, 90, 2);
  keyLight.position.set(0, 8, 0);
  scene.add(keyLight);

  const sun = solarPlanetModel.find((p) => p.key === "Sun");
  const sunMesh = new THREE.Mesh(
    new THREE.SphereGeometry(sun.size, 28, 28),
    new THREE.MeshBasicMaterial({ color: ink })
  );
  sunMesh.userData = { key: "Sun", label: "Sun" };
  scene.add(sunMesh);
  const glowTexture = createGlowTexture(THREE, "#ffffff");
  const sunGlowInner = new THREE.Sprite(
    new THREE.SpriteMaterial({
      map: glowTexture,
      color: isDark ? 0xffffff : 0x1a1d22,
      transparent: true,
      opacity: isDark ? 0.52 : 0.3,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    })
  );
  sunGlowInner.scale.setScalar(sun.size * 11.6);
  scene.add(sunGlowInner);
  const sunGlowOuter = new THREE.Sprite(
    new THREE.SpriteMaterial({
      map: glowTexture,
      color: isDark ? 0xffffff : 0x1c2027,
      transparent: true,
      opacity: isDark ? 0.34 : 0.2,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    })
  );
  sunGlowOuter.scale.setScalar(sun.size * 18.2);
  scene.add(sunGlowOuter);

  const orbitLines = [];
  solarPlanetModel
    .filter((planet) => planet.key !== "Sun" && planet.parent !== "Earth")
    .forEach((planet) => {
      const pts = [];
      for (let i = 0; i <= 128; i += 1) {
        const a = (i / 128) * Math.PI * 2;
        pts.push(new THREE.Vector3(Math.cos(a) * planet.radius, 0, Math.sin(a) * planet.radius));
      }
      const orbitGeometry = new THREE.BufferGeometry().setFromPoints(pts);
      const orbitMaterial = new THREE.LineBasicMaterial({
        color: dim,
        transparent: true,
        opacity: planet.key === "Earth" ? 0.52 : 0.34
      });
      const orbitLine = new THREE.Line(orbitGeometry, orbitMaterial);
      orbitLine.rotation.x = Math.PI * 0.04;
      scene.add(orbitLine);
      orbitLines.push(orbitLine);
    });

  const maxOrbit = Math.max(
    ...solarPlanetModel
      .filter((planet) => planet.key !== "Sun" && planet.parent !== "Earth")
      .map((planet) => planet.radius)
  );
  const risingSign = dashboard?.natalCore?.rising || "Aries";
  const sectorOffset = ((zodiacIndex(risingSign) * 30 + 90) * Math.PI) / 180;
  const sectorGroup = new THREE.Group();
  const houseAnchors = [];
  houseOverlay.innerHTML = "";
  for (let i = 0; i < 12; i += 1) {
    const a = (i / 12) * Math.PI * 2 + sectorOffset;
    const near = new THREE.Vector3(Math.cos(a) * 0.5, 0, Math.sin(a) * 0.5);
    const far = new THREE.Vector3(Math.cos(a) * (maxOrbit + 0.42), 0, Math.sin(a) * (maxOrbit + 0.42));
    const line = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([near, far]),
      new THREE.LineBasicMaterial({ color: dim, transparent: true, opacity: i % 3 === 0 ? 0.34 : 0.2 })
    );
    sectorGroup.add(line);
    const marker = new THREE.Mesh(
      new THREE.CircleGeometry(0.028, 16),
      new THREE.MeshBasicMaterial({ color: i === 0 ? ink : dim, transparent: true, opacity: i === 0 ? 0.95 : 0.6 })
    );
    marker.position.set(Math.cos(a) * (maxOrbit + 0.46), 0, Math.sin(a) * (maxOrbit + 0.46));
    marker.rotation.x = -Math.PI / 2;
    sectorGroup.add(marker);
    const anchor = new THREE.Vector3(Math.cos(a) * (maxOrbit + 0.88), 0, Math.sin(a) * (maxOrbit + 0.88));
    houseAnchors.push({ index: i, world: anchor });
    const houseLabel = document.createElement("span");
    houseLabel.className = "solar-house-label";
    const sign = zodiacOrder[(zodiacIndex(risingSign) + i) % zodiacOrder.length] || "";
    houseLabel.textContent = `H${i + 1} ${sign}`;
    houseOverlay.appendChild(houseLabel);
  }
  sectorGroup.rotation.x = Math.PI * 0.04;
  scene.add(sectorGroup);

  const moonOrbitPts = [];
  for (let i = 0; i <= 96; i += 1) {
    const a = (i / 96) * Math.PI * 2;
    moonOrbitPts.push(new THREE.Vector3(Math.cos(a) * 0.38, 0, Math.sin(a) * 0.38));
  }
  const moonOrbitLine = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints(moonOrbitPts),
    new THREE.LineDashedMaterial({ color: muted, dashSize: 0.08, gapSize: 0.06, transparent: true, opacity: 0.65 })
  );
  moonOrbitLine.computeLineDistances();
  scene.add(moonOrbitLine);

  const driftObjects = [];
  const driftCount = 44;
  for (let i = 0; i < driftCount; i += 1) {
    const radius = 3.25 + (i % 17) * 0.19 + ((i * 13) % 10) * 0.035;
    const size = 0.008 + (i % 5) * 0.003;
    const speed = 0.035 + (i % 11) * 0.0042;
    const phase = (i * 0.81) % (Math.PI * 2);
    const wobble = 0.02 + (i % 7) * 0.01;
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(size, 8, 8),
      new THREE.MeshBasicMaterial({
        color: i % 3 === 0 ? ink : muted,
        transparent: true,
        opacity: isDark ? 0.24 : 0.2,
        depthWrite: false
      })
    );
    scene.add(mesh);
    driftObjects.push({ mesh, radius, speed, phase, wobble });
  }

  const earthSatellites = [];
  const satelliteRings = [];
  const earthOrbitalAssets = [
    { key: "ISS", shell: 0.3, speed: 0.19, phase: 0.2, incline: 0.45, size: 0.011 },
    { key: "Hubble", shell: 0.37, speed: 0.14, phase: 2.1, incline: -0.26, size: 0.0095 },
    { key: "JWST", shell: 0.46, speed: 0.11, phase: 4.2, incline: 0.18, size: 0.009 }
  ];
  earthOrbitalAssets.forEach((asset, ringIdx) => {
    const ringPoints = [];
    for (let i = 0; i <= 120; i += 1) {
      const a = (i / 120) * Math.PI * 2;
      const y = Math.sin(a * 0.45 + ringIdx * 0.7) * 0.008;
      ringPoints.push(new THREE.Vector3(Math.cos(a) * asset.shell, y, Math.sin(a) * asset.shell));
    }
    const ring = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints(ringPoints),
      new THREE.LineBasicMaterial({
        color: isDark ? 0xcfd4de : 0x3f4652,
        transparent: true,
        opacity: 0,
        depthWrite: false
      })
    );
    scene.add(ring);
    satelliteRings.push({ ring, idx: ringIdx, shell: asset.shell });

    const sat = new THREE.Mesh(
      new THREE.SphereGeometry(asset.size, 10, 10),
      new THREE.MeshBasicMaterial({
        color: isDark ? 0xf2f5fa : 0x1f2630,
        transparent: true,
        opacity: 0,
        depthWrite: false
      })
    );
    sat.renderOrder = 3;
    scene.add(sat);
    earthSatellites.push({
      key: asset.key,
      mesh: sat,
      shell: asset.shell,
      speed: asset.speed,
      phase: asset.phase,
      incline: asset.incline
    });
  });
  let earthFocusMix = 0;

  const hitTargets = [sunMesh];
  const planetMeshes = [];
  const objectLabels = new Map();
  const trailMap = new Map();
  const ringMap = new Map();
  const themeKey = isDark ? "dark" : "light";
  objectOverlay.innerHTML = "";
  const sunLabel = document.createElement("span");
  sunLabel.className = "solar-object-label";
  objectOverlay.appendChild(sunLabel);
  objectLabels.set("Sun", sunLabel);
  solarPlanetModel
    .filter((planet) => planet.key !== "Sun")
    .forEach((planet) => {
      const texture = createPlanetTexture(THREE, planet.key, themeKey);
      const mesh = new THREE.Mesh(
        new THREE.SphereGeometry(planet.size, 24, 24),
        new THREE.MeshStandardMaterial({
          color: 0xffffff,
          map: texture || null,
          roughness: 0.62,
          metalness: 0.08
        })
      );
      mesh.userData = { key: planet.key, label: planet.label };
      scene.add(mesh);
      const hitProxy = new THREE.Mesh(
        new THREE.SphereGeometry(Math.max(planet.size * 2.3, 0.18), 12, 12),
        new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false })
      );
      hitProxy.userData = { key: planet.key, label: planet.label };
      scene.add(hitProxy);
      hitTargets.push(hitProxy);
      planetMeshes.push({ planet, mesh, hitProxy });
      const label = document.createElement("span");
      label.className = "solar-object-label";
      objectOverlay.appendChild(label);
      objectLabels.set(planet.key, label);

      const trailMax = planet.key === "Moon" ? 78 : 122;
      const trailResolution = planet.key === "Moon" ? 64 : 78;
      const trailNodeCount = planet.key === "Moon" ? 18 : 24;
      const trailNodes = [];
      for (let i = 0; i < trailNodeCount; i += 1) {
        const dot = new THREE.Mesh(
          new THREE.SphereGeometry(Math.max(planet.size * 0.3, 0.014), 10, 10),
          new THREE.MeshBasicMaterial({
            color: planet.key === "Earth" ? ink : muted,
            transparent: true,
            opacity: 0,
            depthWrite: false
          })
        );
        scene.add(dot);
        trailNodes.push(dot);
      }
      trailMap.set(planet.key, {
        points: [],
        max: trailMax,
        lastSampleTs: 0,
        nodes: trailNodes,
        resolution: trailResolution,
        baseSize: Math.max(planet.size * 1.02, 0.03)
      });

      if (planet.key !== "Moon") {
        const ringPts = Array.from({ length: 129 }, () => new THREE.Vector3(0, 0, 0));
        const ringLine = new THREE.Line(
          new THREE.BufferGeometry().setFromPoints(ringPts),
          new THREE.LineBasicMaterial({
            color: planet.key === "Earth" ? ink : muted,
            transparent: true,
            opacity: 0.34
          })
        );
        scene.add(ringLine);
        ringMap.set(planet.key, { line: ringLine, points: ringPts });
      }
    });

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  let hoveredKey = null;
  const focusTarget = new THREE.Vector3(0, 0, 0);
  const cameraTarget = new THREE.Vector3(0, 9.5, 11);
  const baseOffset = new THREE.Vector3(0, 9.5, 11);

  const setPanelPlanet = (key, { focused = false } = {}) => {
    if (!aspects[key]) {
      return;
    }
    panel.innerHTML = renderSolarAspectPanel(aspects[key], key, { focused });
    animateSolarPanelText(panel);
    focusBadge.textContent = key === "__all__" ? "Focus: The whole system" : `Focus: ${key}`;
    matrixWrap.querySelectorAll(".solar-mobile-pill").forEach((pill) => {
      pill.classList.toggle("is-active", pill.getAttribute("data-solar-planet") === key);
    });
  };

  const resize = () => {
    const rect = wrap.getBoundingClientRect();
    const width = Math.max(240, Math.round(rect.width));
    const height = Math.max(280, Math.round(rect.height));
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
  };
  resize();
  window.addEventListener("resize", resize);

  canvas.onpointermove = (event) => {
    if (!canHover) {
      return;
    }
    const rect = canvas.getBoundingClientRect();
    pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(hitTargets, false);
    if (!hits.length) {
      if (hoveredKey) {
        hoveredKey = null;
        setPanelPlanet(selectedKey, { focused: true });
      }
      tooltip.style.opacity = "0";
      return;
    }
    const key = hits[0]?.object?.userData?.key || null;
    if (!key) {
      return;
    }
    if (hoveredKey !== key) {
      hoveredKey = key;
      setPanelPlanet(key, { focused: false });
    }
    tooltip.textContent = key;
    tooltip.style.left = `${event.clientX - rect.left + 12}px`;
    tooltip.style.top = `${event.clientY - rect.top + 12}px`;
    tooltip.style.opacity = "1";
  };

  canvas.onpointerleave = () => {
    if (!canHover) {
      return;
    }
    if (hoveredKey) {
      hoveredKey = null;
      setPanelPlanet(selectedKey, { focused: true });
    }
    tooltip.style.opacity = "0";
  };

  canvas.onclick = () => {
    if (!canHover) {
      return;
    }
    if (!hoveredKey) {
      return;
    }
    selectedKey = hoveredKey;
    focusBoostStartedAt = performance.now();
    setPanelPlanet(selectedKey, { focused: true });
  };

  canvas.onpointerdown = (event) => {
    if (canHover) {
      return;
    }
    const rect = canvas.getBoundingClientRect();
    pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(hitTargets, false);
    const key = hits[0]?.object?.userData?.key || "__all__";
    selectedKey = key;
    focusBoostStartedAt = performance.now();
    setPanelPlanet(selectedKey, { focused: true });
  };

  const start = performance.now();
  const runtime = {
    renderer,
    scene,
    camera,
    canvas,
    resizeHandler: resize,
    frameId: 0,
    focusGrid: null
  };

  const tick = (now) => {
    if (state.solarSystem !== runtime) {
      return;
    }
    const elapsedSec = (now - start) / 1000;
    const simDays = daysSinceJ2000(new Date()) + elapsedSec * (preferReducedMotion ? 0.18 : 3.4);
    const positions = solarPositionsAt(new Date(Date.UTC(2000, 0, 1, 12, 0, 0) + simDays * 86400000));

    planetMeshes.forEach(({ planet, mesh, hitProxy }) => {
      const p = positions[planet.key];
      if (!p) {
        return;
      }
      mesh.position.set(p.x, 0, p.z);
      hitProxy.position.copy(mesh.position);
      mesh.rotation.y += planet.key === "Moon" ? 0.008 : 0.004;
      mesh.rotation.z += 0.0015;

      const trail = trailMap.get(planet.key);
      if (trail && trail.points.length === 0) {
        const baseAngle = Math.atan2(mesh.position.z, mesh.position.x);
        for (let i = 0; i < Math.min(28, trail.max); i += 1) {
          const back = i * 0.035;
          if (planet.key === "Moon" && positions.Earth) {
            const a = (p.angle || baseAngle) - back;
            trail.points.unshift(
              new THREE.Vector3(
                positions.Earth.x + Math.cos(a) * planet.radius,
                0,
                positions.Earth.z + Math.sin(a) * planet.radius
              )
            );
          } else {
            const a = baseAngle - back;
            trail.points.unshift(new THREE.Vector3(Math.cos(a) * planet.radius, 0, Math.sin(a) * planet.radius));
          }
        }
      }
      if (trail && now - trail.lastSampleTs > (planet.key === "Moon" ? 45 : 90)) {
        trail.lastSampleTs = now;
        trail.points.push(mesh.position.clone());
        if (trail.points.length > trail.max) {
          trail.points.shift();
        }
      }
      if (trail) {
        const nodes = trail.nodes;
        if (trail.points.length > 3 && Array.isArray(nodes) && nodes.length) {
          const curve = new THREE.CatmullRomCurve3(trail.points, false, "centripetal", 0.22);
          const smoothed = curve.getPoints(Math.max(6, trail.resolution - 1));
          const focusAlpha = planet.key === selectedKey
            ? (planet.key === "Moon" ? 0.95 : 0.88)
            : (planet.key === "Moon" ? 0.56 : 0.48);
          const last = smoothed.length - 1;
          for (let i = 0; i < nodes.length; i += 1) {
            const node = nodes[i];
            const t = i / Math.max(1, nodes.length - 1);
            const idx = Math.max(0, last - Math.round(t * last));
            const pt = smoothed[idx];
            node.position.copy(pt);
            const sizeFade = Math.pow(1 - t, 0.72);
            const alphaFade = Math.pow(1 - t, 1.28);
            const scale = trail.baseSize * (0.34 + sizeFade * 1.2);
            node.scale.setScalar(scale);
            node.material.opacity = focusAlpha * alphaFade;
          }
        } else if (Array.isArray(nodes)) {
          nodes.forEach((node) => {
            node.material.opacity = 0;
          });
        }
      }

      const ring = ringMap.get(planet.key);
      if (ring && planet.radius > 0) {
        const angle = Math.atan2(mesh.position.z, mesh.position.x);
        for (let i = 0; i < ring.points.length; i += 1) {
          const t = i / (ring.points.length - 1);
          const a = angle - Math.PI * 2 * t;
          ring.points[i].set(Math.cos(a) * planet.radius, 0, Math.sin(a) * planet.radius);
        }
        ring.line.geometry.setFromPoints(ring.points);
        ring.line.rotation.x = Math.PI * 0.04;
      }
    });

    if (positions.Earth) {
      moonOrbitLine.position.set(positions.Earth.x, 0, positions.Earth.z);
    }

    driftObjects.forEach((obj, idx) => {
      const a = elapsedSec * obj.speed + obj.phase;
      const y = Math.sin(a * 1.9 + idx * 0.17) * obj.wobble;
      obj.mesh.position.set(
        Math.cos(a) * obj.radius,
        y,
        Math.sin(a) * obj.radius
      );
    });

    const earthVisible = Boolean(positions.Earth);
    const targetEarthFocusMix = selectedKey === "Earth" ? 1 : 0;
    earthFocusMix += (targetEarthFocusMix - earthFocusMix) * (preferReducedMotion ? 0.08 : 0.12);
    if (earthVisible) {
      const earthPos = positions.Earth;
      satelliteRings.forEach(({ ring, idx }) => {
        ring.position.set(earthPos.x, 0, earthPos.z);
        ring.rotation.y = elapsedSec * (0.021 + idx * 0.012);
        ring.rotation.x = Math.PI * 0.16 + idx * 0.06;
        ring.material.opacity = 0.06 + earthFocusMix * 0.4;
      });
      earthSatellites.forEach((sat, idx) => {
        const t = elapsedSec * sat.speed + sat.phase;
        const x = Math.cos(t) * sat.shell;
        const z = Math.sin(t) * sat.shell;
        const y = Math.sin(t * 1.7 + idx * 0.23) * sat.shell * 0.14;
        const cosI = Math.cos(sat.incline);
        const sinI = Math.sin(sat.incline);
        const rx = x * cosI - y * sinI;
        const ry = x * sinI + y * cosI;
        sat.mesh.position.set(earthPos.x + rx, ry, earthPos.z + z);
        sat.mesh.material.opacity = (0.04 + earthFocusMix * 0.86) * (0.88 + Math.sin(t * 2.1 + idx) * 0.08);
      });
    } else {
      satelliteRings.forEach(({ ring }) => {
        ring.material.opacity = 0;
      });
      earthSatellites.forEach((sat) => {
        sat.mesh.material.opacity = 0;
      });
    }
    sunGlowInner.scale.setScalar(1 + Math.sin(elapsedSec * 1.5) * 0.035);
    sunGlowOuter.scale.setScalar(1 + Math.sin(elapsedSec * 0.9 + 1.1) * 0.07);

    const focusSource = selectedKey === "__all__" ? { x: 0, z: 0 } : (positions[selectedKey] || { x: 0, z: 0 });
    focusTarget.set(focusSource.x, 0, focusSource.z);
    const focusPlanet = solarPlanetModel.find((p) => p.key === selectedKey);
    const focusDistance = selectedKey === "__all__"
      ? 12.8
      : focusPlanet?.key === "Sun"
        ? 8.8
        : focusPlanet?.key === "Earth"
          ? (isMobileScene ? 2.2 : 1.62)
        : Math.max(3.6, 2.3 + (focusPlanet?.size || 0.12) * 18);
    const boostT = Math.max(0, (now - focusBoostStartedAt) / 1000);
    const boost = Math.exp(-boostT * 3.2) * Math.sin(boostT * 13) * 0.18;
    const desiredCamera = focusTarget.clone().add(
      baseOffset.clone().normalize().multiplyScalar(focusDistance * (1 + boost)).add(
        new THREE.Vector3(0, focusDistance * (isMobileScene ? 0.62 : (0.48 + boost * 0.5)), 0)
      )
    );
    cameraTarget.lerp(desiredCamera, preferReducedMotion ? 0.08 : 0.14);
    camera.position.lerp(cameraTarget, preferReducedMotion ? 0.1 : 0.18);
    const framedLookTarget = focusTarget.clone();
    if (isMobileScene && selectedKey !== "__all__") {
      framedLookTarget.y -= focusDistance * 0.26;
    }
    camera.lookAt(framedLookTarget);

    orbitLines.forEach((line, idx) => {
      const pulse = 0.94 + Math.sin(elapsedSec * 0.23 + idx * 0.5) * 0.06;
      line.material.opacity = Math.max(0.18, Math.min(0.55, line.material.opacity * 0.97 + pulse * 0.03));
    });
    sectorGroup.rotation.y = Math.sin(elapsedSec * 0.03) * 0.04;

    const labels = houseOverlay.querySelectorAll(".solar-house-label");
    sectorGroup.updateMatrixWorld();
    labels.forEach((label, idx) => {
      const anchor = houseAnchors[idx];
      if (!anchor) {
        return;
      }
      const projected = anchor.world.clone().applyMatrix4(sectorGroup.matrixWorld).project(camera);
      const visible = projected.z < 1;
      const x = ((projected.x + 1) / 2) * wrap.clientWidth;
      const y = ((-projected.y + 1) / 2) * wrap.clientHeight;
      label.style.opacity = visible ? "0.88" : "0";
      label.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
    });

    const placeObjectLabel = (key, vec3, angleDeg) => {
      const label = objectLabels.get(key);
      if (!label || !vec3) {
        return;
      }
      const projected = vec3.clone().project(camera);
      const visible = projected.z < 1;
      const x = ((projected.x + 1) / 2) * wrap.clientWidth + 10;
      const y = ((-projected.y + 1) / 2) * wrap.clientHeight - 8;
      const sign = zodiacFromAngle(angleDeg);
      const iconClass = zodiacIconClasses[sign] || "mdi:circle-outline";
      label.innerHTML = `<iconify-icon icon="${iconClass}" class="solar-zodiac-icon" aria-hidden="true"></iconify-icon><span>${key} · ${sign}</span>`;
      label.style.opacity = visible ? "0.9" : "0";
      label.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
      label.classList.toggle("is-active", key === selectedKey);
    };
    const sunAngle = normalizeAngle((simDays / 365.25) * 360 + 280);
    placeObjectLabel("Sun", sunMesh.position, sunAngle);
    planetMeshes.forEach(({ planet, mesh }) => {
      const a = normalizeAngle((Math.atan2(mesh.position.z, mesh.position.x) * 180) / Math.PI);
      placeObjectLabel(planet.key, mesh.position, a);
    });

    const focusMesh = planetMeshes.find((item) => item.planet.key === selectedKey)?.mesh || sunMesh;
    if (runtime.focusGrid && selectedKey !== "__all__") {
      runtime.focusGrid.position.copy(focusMesh.position);
      const size = (focusPlanet?.size || sun.size) * 1.32;
      runtime.focusGrid.scale.setScalar(size);
      runtime.focusGrid.rotation.y += 0.006;
      runtime.focusGrid.material.opacity = 0.42 + Math.sin(elapsedSec * 2.2) * 0.12;
    } else if (runtime.focusGrid) {
      runtime.focusGrid.material.opacity = 0;
    }
    renderer.render(scene, camera);
    runtime.frameId = window.requestAnimationFrame(tick);
  };

  runtime.focusGrid = new THREE.Mesh(
    new THREE.SphereGeometry(1, 20, 20),
    new THREE.MeshBasicMaterial({
      color: isDark ? 0xffffff : 0x111111,
      wireframe: true,
      transparent: true,
      opacity: 0.45,
      depthWrite: false
    })
  );
  scene.add(runtime.focusGrid);

  runtime.frameId = window.requestAnimationFrame(tick);
  state.solarSystem = runtime;
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
  initSolarSystemWidget(dashboard, period);
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
      <article class="card tone-card">
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
  const zodiacCelebBlock = renderZodiacCelebrities(dashboard.natalCore?.sun);
  const solarSystemBlock = renderSolarSystemBlock(dashboard, period);

  return `
    <section class="hero">
      <article class="card tone-card">
        <span class="eyebrow">User Dashboard</span>
        <h1 class="dashboard-name"><span class="${nameClass}">${displayName}</span></h1>
        <div class="chip-grid">
          ${chips.map((chip) => `<span class="astro-chip">${chip}</span>`).join("")}
        </div>
        <div class="hero-actions">
          <a class="btn primary btn-natal-flicker" href="/natal-chart">Natal Profile</a>
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
    ${solarSystemBlock}
    ${zodiacCompact}
    ${zodiacCelebBlock}
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
    : state.authUser?.email || state.authUser?.firstName || "";
  const provider = String(state.authUser?.provider || "").trim();
  const providerLabel = provider ? provider.charAt(0).toUpperCase() + provider.slice(1) : "Unknown";

  if (state.authenticated) {
    return `
      <section class="section">
        <article class="card tone-card">
          <span class="eyebrow">Authentication</span>
          <h1>You are signed in</h1>
          <p>Provider: ${providerLabel} ${userLabel ? `(${userLabel})` : ""}</p>
          <div class="hero-actions">
            <a class="btn primary" href="/">Continue</a>
            <button id="logoutButton" class="btn ghost" type="button">Logout</button>
          </div>
        </article>
      </section>
    `;
  }

  const telegramEnabled = state.telegramLoginEnabled && state.telegramBotUsername;
  const googleEnabled = state.googleLoginEnabled;
  const anyEnabled = telegramEnabled || googleEnabled;

  return `
    <section class="section login-shell">
      <div class="login-left">
        <article class="card tone-card">
          <span class="eyebrow">Authentication</span>
          <h1>Sign in</h1>
          <p>This service is available only to authorized users.</p>
        </article>
        <article class="card">
          ${
            anyEnabled
              ? `
                <div class="auth-provider-row">
                  ${
                    googleEnabled
                      ? `<a class="auth-login-btn gmail" href="/api/auth/google/start?returnTo=%2F">
                           <span class="auth-login-btn-icon" aria-hidden="true">${uiIcon("google")}</span>
                           <span>Continue with Gmail</span>
                         </a>`
                      : ""
                  }
                  ${
                    telegramEnabled
                      ? `<button id="telegramLoginButton" class="auth-login-btn telegram" type="button">
                           <span class="auth-login-btn-icon" aria-hidden="true">${uiIcon("telegram")}</span>
                           <span>Continue with Telegram</span>
                         </button>
                         <div id="telegramWidgetMount" class="telegram-widget-mount-hidden"></div>`
                      : ""
                  }
                </div>
                <div class="login-copy">
                  <p>Astronautica is a precision astrology interface that turns natal geometry into practical daily decisions, relationship timing, and communication strategy.</p>
                  <p>Your profile anchors the model, so forecasts, compatibility and action guidance stay coherent over time instead of feeling like generic horoscope feed content.</p>
                </div>
                <p id="loginStatus" class="muted" style="margin-top:0.8rem"></p>
              `
              : `<p>No login providers configured yet. Configure Telegram or Google credentials in environment variables.</p>`
          }
        </article>
      </div>
      <aside class="login-visual" aria-hidden="true">
        <img src="https://basilarcana-assets.b-cdn.net/astronautica/app.png" alt="" loading="lazy" decoding="async" />
      </aside>
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
      <article class="card tone-card">
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
      <article class="card tone-card">
        <span class="eyebrow">Profile</span>
        <h1>Account</h1>
        <p>${authLabel || "Authorized user"}.</p>
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
      <article class="card tone-card">
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
      <article class="card natal-head-card tone-card">
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

function emphasizeZodiacSigns(text) {
  const source = String(text || "");
  if (!source) {
    return "";
  }
  const zodiacPattern = /\b(Aries|Taurus|Gemini|Cancer|Leo|Virgo|Libra|Scorpio|Sagittarius|Capricorn|Aquarius|Pisces)\b/g;
  return source.replace(zodiacPattern, "<strong>$1</strong>");
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
                  <span class="placement-chip placement-chip-planet">${planetIcon(item.key)} ${item.key}</span>
                  <span class="placement-chip">${zodiacIcon(item.sign)} ${item.sign}</span>
                  <span class="placement-chip">House ${Number.isFinite(item.house) ? item.house : "—"}</span>
                  <span class="placement-chip">${stateLabel}</span>
                </div>
                <p>${emphasizeZodiacSigns(interpretPlanetPlacement(item))}</p>
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
                  <td data-label="Meaning">${emphasizeZodiacSigns(interpretPlanetPlacement(item))}</td>
                </tr>
              `;
            })
            .join("")}
        </tbody>
      </table>
    </div>
  `;
}

function aspectVisualMeta(text) {
  const value = String(text || "");
  if (value.includes("Conjunction")) {
    return { label: "Conjunction", cls: "conjunction", icon: "⊙" };
  }
  if (value.includes("Trine")) {
    return { label: "Trine", cls: "trine", icon: "△" };
  }
  if (value.includes("Square")) {
    return { label: "Square", cls: "square", icon: "□" };
  }
  if (value.includes("Opposition")) {
    return { label: "Opposition", cls: "opposition", icon: "☍" };
  }
  if (value.includes("Sextile")) {
    return { label: "Sextile", cls: "sextile", icon: "✶" };
  }
  return { label: "Aspect", cls: "generic", icon: "◌" };
}

function renderAspectCards(items) {
  const safe = Array.isArray(items) ? items.slice(0, 8) : [];
  return `
    <div class="aspect-grid">
      ${safe
        .map((item) => {
          const meta = aspectVisualMeta(item);
          return `
            <article class="aspect-card ${meta.cls}">
              <span class="aspect-type">${meta.icon} ${meta.label}</span>
              <p>${item}</p>
              <svg class="aspect-corner" viewBox="0 0 64 64" role="img" aria-label="${meta.label} pattern">
                <polyline points="2,2 62,2 62,62" />
                <line x1="18" y1="18" x2="46" y2="18" />
                <line x1="46" y1="18" x2="46" y2="46" />
                <circle cx="18" cy="18" r="3.2" />
                <circle cx="46" cy="18" r="3.2" />
                <circle cx="46" cy="46" r="3.2" />
              </svg>
            </article>
          `;
        })
        .join("")}
    </div>
  `;
}

function actionPlanIcon(title, index = 0) {
  const sizes = [9.4, 8.4, 10.2];
  const size = sizes[index % sizes.length];
  const half = size / 2;
  const points = `${half},0 ${half + 2.1},${half - 2.1} ${size},${half} ${half + 2.1},${half + 2.1} ${half},${size} ${half - 2.1},${half + 2.1} 0,${half} ${half - 2.1},${half - 2.1}`;
  return `
    <svg class="action-star" viewBox="0 0 ${size} ${size}" aria-hidden="true" focusable="false">
      <polygon points="${points}" />
    </svg>
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
        ${renderAspectCards(aspects)}
      </article>
    </section>
    <section class="section" id="natal-plan">
      <article class="route-card content-panel premium-panel">
        <span class="premium-kicker">Execution</span>
        <h2>Action Plan</h2>
        <div class="action-plan-layout">
          <div class="action-plan-steps">
            ${planItems
              .map(
                (item, index) => `
                  <article class="action-step-card">
                    <div class="action-step-head">
                      <span class="action-step-icon">${actionPlanIcon(item.title, index)}</span>
                      <h3>${item.title}</h3>
                    </div>
                    <p class="action-step-main">${item.action}</p>
                    <p class="action-step-note">${item.comment}</p>
                  </article>
                `
              )
              .join("")}
          </div>
          <aside class="action-plan-visual">
            <img
              class="action-plan-ill"
              src="https://basilarcana-assets.b-cdn.net/astronautica/ill1.png"
              alt="Astronautica action plan illustration"
              loading="lazy"
              decoding="async"
            />
          </aside>
        </div>
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
      <article class="card tone-card">
        <span class="eyebrow">Step 3 · Daily</span>
        <h1>Daily focus</h1>
        <p id="dailyStatus">Building daily signal...</p>
      </article>
    </section>
  `;
}

function friendsView() {
  return `
    <section class="section">
      <article class="card tone-card">
        <span class="eyebrow">Friends</span>
        <h1>Check friends?</h1>
        <p>Fast synastry-lite view for communication quality, conflict timing and daily collaboration windows.</p>
      </article>
    </section>
    <section class="section">
      <article class="card friend-form-card">
        <span class="eyebrow">Add friend</span>
        <h2>Friend profile</h2>
        <div class="friend-form-layout">
          <form id="friendForm" class="form-grid friend-form-grid">
            <label class="field-span-2">Friend name
              <input required name="friendName" placeholder="Friend name" />
            </label>
            <label class="field-span-2">Birth date
              <input required type="date" name="friendBirthDate" />
            </label>
            <label>Birth time (optional)
              <input type="time" name="friendBirthTime" />
            </label>
            <label>Birth place (optional)
              <input id="friendBirthCity" name="friendBirthCity" placeholder="City, Country" list="friendCitySuggestions" autocomplete="off" />
            </label>
            <label>Telegram username
              <input id="friendTelegram" name="friendTelegram" placeholder="@username" />
            </label>
            <label>Email
              <input id="friendEmail" type="email" name="friendEmail" placeholder="friend@email.com" />
            </label>
            <label class="friend-no-share">
              <input id="friendNoShareData" type="checkbox" name="noShareData" />
              <span>I don't want to share data with friends</span>
            </label>
            <p class="muted friend-form-note">The more complete your friend's birth data, the more accurate the compatibility calculation.</p>
            <button class="btn primary form-submit" type="submit">Add friend</button>
          </form>
          <aside class="friend-form-art" aria-hidden="true">
            <img src="https://basilarcana-assets.b-cdn.net/astronautica/hand.png" alt="" />
          </aside>
        </div>
        <datalist id="friendCitySuggestions"></datalist>
      </article>
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
      <article class="card tone-card">
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

const zodiacHubProfiles = {
  Aries: {
    title: "Aries Zodiac Guide: Momentum, Courage, and Clean Starts",
    excerpt: "How Aries creates momentum, where impatience appears, and how to convert raw drive into strategic wins.",
    seoDescription: "Aries zodiac guide: strengths, challenges, relationships, career patterns, and practical growth protocols.",
    angle: "Aries energy starts fast. The upgrade is to pair speed with finish architecture.",
    strengths: "High activation energy, direct communication, willingness to initiate under uncertainty.",
    risk: "Impatience, premature conflict, and overcommitting before the system is ready.",
    protocol: "Use 72-hour sprint cycles with explicit completion criteria before opening new fronts."
  },
  Taurus: {
    title: "Taurus Zodiac Guide: Stability, Value, and Durable Execution",
    excerpt: "Why Taurus compounds results through consistency, and how to avoid getting stuck in comfort loops.",
    seoDescription: "Taurus zodiac guide with practical frameworks for stability, decision quality, and long-term outcomes.",
    angle: "Taurus builds trust through consistency. The upgrade is adaptive consistency, not rigidity.",
    strengths: "Patience, reliability, sensory intelligence, and strong value filters.",
    risk: "Resistance to change, delayed decisions, and staying too long in suboptimal structures.",
    protocol: "Review commitments weekly and set one controlled experiment to keep strategy adaptive."
  },
  Gemini: {
    title: "Gemini Zodiac Guide: Curiosity, Communication, and Pattern Speed",
    excerpt: "Gemini's edge is synthesis and movement. Learn to turn ideas into shipped outcomes.",
    seoDescription: "Gemini zodiac guide on communication style, focus management, and practical execution systems.",
    angle: "Gemini is strongest when curiosity is operationalized into decisions.",
    strengths: "Fast learning loops, verbal agility, context-switching, and social intelligence.",
    risk: "Fragmentation, over-analysis, and high input with low output.",
    protocol: "For every three new inputs, publish one written decision and one next action."
  },
  Cancer: {
    title: "Cancer Zodiac Guide: Emotional Precision and Protective Leadership",
    excerpt: "Cancer excels at emotional signal quality. The key is boundaries that preserve energy.",
    seoDescription: "Cancer zodiac guide with modern strategies for boundaries, relationships, and emotional regulation.",
    angle: "Cancer translates emotional data into care architecture and loyalty.",
    strengths: "Intuition, long memory, protective instinct, and deep relational commitment.",
    risk: "Mood-driven reactivity, overprotection, and indirect communication under stress.",
    protocol: "Use boundary scripts in advance: what you can give, what you cannot, and by when."
  },
  Leo: {
    title: "Leo Zodiac Guide: Visibility, Creative Power, and Responsible Leadership",
    excerpt: "Leo shines through ownership and expression. Turn recognition needs into contribution systems.",
    seoDescription: "Leo zodiac guide for leadership, creative execution, and healthy visibility in work and relationships.",
    angle: "Leo performs best when visibility is tied to measurable contribution.",
    strengths: "Presence, charisma, creative authority, and morale-building leadership.",
    risk: "Ego volatility, approval dependence, and avoiding unglamorous but critical tasks.",
    protocol: "Define impact metrics before launch so recognition follows outcomes, not noise."
  },
  Virgo: {
    title: "Virgo Zodiac Guide: Precision, Systems, and Quiet Mastery",
    excerpt: "Virgo creates leverage through refinement. Learn to avoid perfection traps and ship consistently.",
    seoDescription: "Virgo zodiac guide covering analytical strengths, stress patterns, and high-leverage growth routines.",
    angle: "Virgo turns complexity into repeatable quality through process discipline.",
    strengths: "Detail accuracy, optimization instinct, reliability under constraints.",
    risk: "Perfection paralysis, chronic self-critique, and over-focusing on minor defects.",
    protocol: "Time-box refinement and publish versioned outputs: v1 shipped beats perfect drafts."
  },
  Libra: {
    title: "Libra Zodiac Guide: Balance, Agreements, and Social Architecture",
    excerpt: "Libra thrives through calibrated agreements and relational design. Clarity is your force multiplier.",
    seoDescription: "Libra zodiac guide with practical methods for decision balance, communication, and partnership quality.",
    angle: "Libra creates durable outcomes when fairness is translated into explicit agreements.",
    strengths: "Diplomacy, perspective-taking, aesthetic judgment, and conflict de-escalation.",
    risk: "Decision delay, people-pleasing, and avoiding necessary tension.",
    protocol: "Use decision deadlines and written trade-offs to reduce ambiguity fatigue."
  },
  Scorpio: {
    title: "Scorpio Zodiac Guide: Depth, Strategy, and Transformational Focus",
    excerpt: "Scorpio works through depth and precision. Learn how to channel intensity into long-term power.",
    seoDescription: "Scorpio zodiac guide for strategic focus, trust dynamics, and sustainable high-intensity performance.",
    angle: "Scorpio is strongest when intensity is paired with emotional governance.",
    strengths: "Strategic depth, resilience, investigative thinking, and commitment under pressure.",
    risk: "Control dynamics, mistrust loops, and all-or-nothing behavior.",
    protocol: "Create explicit trust criteria and phased commitments instead of binary decisions."
  },
  Sagittarius: {
    title: "Sagittarius Zodiac Guide: Vision, Expansion, and Meaningful Risk",
    excerpt: "Sagittarius expands through exploration. The upgrade is translating vision into execution cadence.",
    seoDescription: "Sagittarius zodiac guide with frameworks for growth, exploration, and disciplined experimentation.",
    angle: "Sagittarius scales best when vision has a weekly operating rhythm.",
    strengths: "Optimism, philosophical clarity, exploratory courage, and strategic storytelling.",
    risk: "Overextension, under-detailing, and abandoning projects after initial excitement.",
    protocol: "Tie long-range goals to one measurable weekly experiment and one review checkpoint."
  },
  Capricorn: {
    title: "Capricorn Zodiac Guide: Structure, Ambition, and Long-Game Mastery",
    excerpt: "Capricorn compounds through discipline and architecture. Build systems that outlast mood.",
    seoDescription: "Capricorn zodiac guide for career architecture, resilience, and practical long-term strategy.",
    angle: "Capricorn wins by converting ambition into durable systems.",
    strengths: "Strategic discipline, accountability, delayed gratification, and strong execution ethics.",
    risk: "Overwork identity, emotional suppression, and rigid success metrics.",
    protocol: "Track recovery as seriously as output to preserve long-term performance quality."
  },
  Aquarius: {
    title: "Aquarius Zodiac Guide: Systems Thinking, Innovation, and Social Future",
    excerpt: "Aquarius sees patterns at system level. Turn originality into deployable frameworks.",
    seoDescription: "Aquarius zodiac guide on innovation style, social intelligence, and practical implementation.",
    angle: "Aquarius delivers outsized value by redesigning systems, not just tasks.",
    strengths: "Independent thinking, strategic abstraction, and community-scale perspective.",
    risk: "Emotional distance, contrarian reflexes, and execution gaps after ideation.",
    protocol: "Pair every innovation thesis with an implementation owner and timeline."
  },
  Pisces: {
    title: "Pisces Zodiac Guide: Intuition, Imagination, and Grounded Sensitivity",
    excerpt: "Pisces reads subtle signals early. Build boundaries so sensitivity becomes strategic clarity.",
    seoDescription: "Pisces zodiac guide with practical tools for intuition, boundaries, and creative execution.",
    angle: "Pisces performs best when imagination is translated into clear structure.",
    strengths: "Empathy, symbolic intelligence, creative synthesis, and emotional depth.",
    risk: "Diffuse focus, boundary blur, and escapist coping when overloaded.",
    protocol: "Use simple structure: one priority, one boundary, one completion per day."
  }
};

const coreHubArticles = [
  {
    slug: "astrology-and-astronomy-shared-roots-modern-paths",
    title: "Astrology and Astronomy: Ancient Roots, Modern Paths",
    excerpt: "From early sky-watchers to the era of telescopes and space missions: where the disciplines diverged and why both still matter today.",
    readTime: "12 min",
    publishedAt: "2026-03-01",
    category: "History",
    seoDescription: "A concise history of astrology and astronomy from antiquity to modern times: shared origins, methodological split, and current relevance.",
    content: `
      <p class="article-lead">The relationship between astrology and astronomy is the story of two languages that once shared the same grammar. In early civilizations, reading the sky meant both precise observation and meaning-making: seasons, rituals, governance, and navigation were all tied to celestial cycles.</p>
      <h2>A shared foundation: observation and calendars</h2>
      <p>In Mesopotamia, Egypt, India, China, and the classical Mediterranean world, tracking planetary and stellar motion was mission-critical for agriculture, travel, and state planning. The same records were also interpreted symbolically. At that stage, there was no hard boundary between computational sky practice and cultural interpretation.</p>
      <p>The zodiac, ephemerides, and early planetary tables emerged as tools of systematization. This was already a sophisticated data culture: measuring cycles, comparing error, and refining periodic models.</p>
      <h2>The split: mathematical physics changes everything</h2>
      <p>Copernicus, Kepler, Galileo, and Newton transformed astronomy into a discipline centered on physical laws, testability, and predictive precision. The key criterion became empirical verification.</p>
      <p>Astrology moved in a different direction: from physical cosmology to symbolic and psychological interpretation. It preserved the language of cycles, timing, and archetypal patterns, but it no longer operated as physics.</p>
      <h2>How both fields coexist today</h2>
      <p>Today, astronomy and astrology serve different aims. Astronomy asks how the universe works and relies on scientific method. Astrology asks how humans organize meaning, attention, and timing in lived experience.</p>
      <p>At Astronautica, we keep those layers explicit. The calculation layer is deterministic: date, time, location, and geometric computation. The interpretation layer translates that structure into practical behavioral signals: focus load, stress rhythm, communication timing, and recovery cadence.</p>
      <h2>Practical takeaway</h2>
      <p>The productive question is not who “wins forever,” but where each tool belongs. Use astronomy to measure external reality. Use structured astrology, if useful, to reflect on patterns, decisions, and self-regulation. What matters most is methodological transparency and clear boundaries.</p>
      <p>Continue with <a href="/astrology-hub/how-to-avoid-astrology-scams">How to Avoid Astrology Scams</a> and <a href="/astrology-hub/astrology-for-self-knowledge-and-growth">Astrology for Self-Knowledge and Growth</a>.</p>
    `
  },
  {
    slug: "how-to-avoid-astrology-scams",
    title: "How to Avoid Astrology Scams",
    excerpt: "A practical red-flag checklist: from fear-based manipulation to opaque upsells. How to choose practitioners and services safely.",
    readTime: "9 min",
    publishedAt: "2026-03-01",
    category: "Safety",
    seoDescription: "How to spot astrology scams: clear red flags, safe selection criteria, and practical due-diligence questions before any consultation.",
    content: `
      <p class="article-lead">The astrology market is large, global, and highly uneven in quality. Next to thoughtful analysts, you will also find actors who monetize anxiety. The good news: scam patterns are repetitive, and you can identify them early.</p>
      <h2>Red flags you should never ignore</h2>
      <ul class="bullet-list">
        <li><strong>Fear selling:</strong> “you are cursed,” “urgent ritual needed,” “catastrophe is coming unless you pay now.”</li>
        <li><strong>Guaranteed outcomes:</strong> “I will bring your partner back in 7 days,” “100% business success.”</li>
        <li><strong>Opaque method:</strong> no clear explanation of inputs, calculations, or reasoning.</li>
        <li><strong>Payment pressure:</strong> countdown tactics, guilt manipulation, and immediate transfer demands.</li>
        <li><strong>Boundary violations:</strong> requests for sensitive data that are not operationally necessary.</li>
      </ul>
      <h2>What professional work looks like</h2>
      <p>A serious practitioner does not sell miracles. They frame hypotheses, acknowledge uncertainty, provide testable recommendations, and do not replace legal, medical, or financial professionals.</p>
      <p>A reliable product or consultant can explain data inputs, calculation logic, and output structure. If you cannot understand what was calculated and why, pause immediately.</p>
      <h2>Questions to ask before booking</h2>
      <ul class="bullet-list">
        <li>Which data do you use, and why?</li>
        <li>How is the chart calculated (house system, geocoding source, time validation)?</li>
        <li>What are the boundaries of your service, and what do you explicitly not provide?</li>
        <li>Can I receive a written structure of findings and recommendations?</li>
        <li>What is your refund and privacy policy?</li>
      </ul>
      <h2>Digital safety baseline</h2>
      <p>Never share ID scans, banking credentials, one-time SMS codes, or messenger access under “astrology verification” pretexts. Use secure payment channels and keep sensitive communication behind two-factor authentication.</p>
      <h2>The Astronautica position</h2>
      <p>We intentionally design against scam mechanics: transparent methodology, explicit limits, no fear-based upsells, and a focus on behavioral self-observation. Astrology should increase clarity, not dependency.</p>
      <p>Then read <a href="/astrology-hub/astrology-for-self-knowledge-and-growth">Astrology for Self-Knowledge and Growth</a>.</p>
    `
  },
  {
    slug: "astrology-for-self-knowledge-and-growth",
    title: "Astrology for Self-Knowledge and Growth: The Astronautica View",
    excerpt: "Why we treat astrology as a map of behavioral patterns, not a deterministic verdict, and how signals become actionable protocols.",
    readTime: "11 min",
    publishedAt: "2026-03-01",
    category: "Methodology",
    seoDescription: "A modern Astronautica framework: astrology as a tool for self-knowledge, focus management, and practical behavioral development.",
    content: `
      <p class="article-lead">In a modern context, astrology is most useful not as fate prediction but as pattern literacy. Used correctly, it helps you identify where energy leaks happen, where stress scripts repeat, and where better structure can unlock better outcomes.</p>
      <h2>From labels to processes</h2>
      <p>The biggest weakness of mass-market astrology is identity labeling. Astronautica uses a process model instead: not “who you are forever,” but “which mechanisms activate under stress, intimacy, responsibility, and overload.”</p>
      <p>This shift removes fatalism. A chart becomes an operating map: where structure is needed, where boundaries protect energy, where recovery must be scheduled, and where communication protocols reduce friction.</p>
      <h2>The Astronautica operating stack</h2>
      <ul class="bullet-list">
        <li><strong>Computation:</strong> deterministic geometry from date, time, and birthplace.</li>
        <li><strong>Signals:</strong> interpretable models for focus, emotional regulation, social load, and execution rhythm.</li>
        <li><strong>Decisions:</strong> concise action protocols that can be tested in real life.</li>
        <li><strong>Review:</strong> cycle tracking and behavioral adjustment without mystification.</li>
      </ul>
      <h2>How to apply this in practice</h2>
      <p>Use one weekly signal, convert it into one measurable behavior, and review outcomes. For example: replace “be calmer” with a concrete communication rule, fixed windows for hard conversations, and one daily recovery marker.</p>
      <p>Within 2-4 weeks, the key shift appears: you stop thinking in “good or bad days” and start seeing your own regulation mechanics. That is what practical self-knowledge looks like.</p>
      <h2>Ethics and limits</h2>
      <p>Astronautica does not position astrology as a substitute for professional advice. It is a meta-navigation layer: where you are stable, where you are vulnerable, and where better architecture is needed. Agency always remains with the person, not with the symbol.</p>
      <p>Modern astrology is valuable when it increases clarity, discipline, and freedom of action. That is exactly the standard we apply.</p>
      <p>Next: explore our sign deep-dives starting with <a href="/astrology-hub/aries-zodiac-sign-guide">Aries</a>.</p>
    `
  },
  {
    slug: "how-to-use-astronautica-complete-practical-guide",
    title: "How to Use Astronautica: A Complete Practical Guide",
    excerpt: "A detailed walkthrough of every major module in Astronautica, with real usage scenarios, routines, and decision workflows.",
    readTime: "18 min",
    publishedAt: "2026-03-02",
    category: "Product Guide",
    seoDescription: "Complete guide to Astronautica: onboarding, natal chart, daily signals, friends compatibility, and practical weekly usage workflows.",
    content: `
      <p class="article-lead">Astronautica is designed as a decision-support system, not a passive horoscope feed. This guide shows exactly how to use each module and combine them into a weekly operating rhythm that improves clarity, communication quality, and execution consistency.</p>
      <h2>1. Start with profile precision</h2>
      <p>Your profile is the computational foundation: birth date, time, and place. Accurate inputs produce stable geometry, and stable geometry means stable interpretation. If the birth time is uncertain, keep it explicit and update later when verified.</p>
      <p>Best practice: after onboarding, check your birth location and timezone assumptions once more. Input quality is the highest-leverage action in the whole product.</p>
      <h2>2. Read the Natal Chart as an operating map</h2>
      <p>In the natal view, avoid trying to interpret everything at once. Start with core axes (Sun, Moon, Rising), then use the matrix and life-domain blocks to map where behavior tends to compound. The objective is not identity labeling, but scenario preparation.</p>
      <ul class="bullet-list">
        <li><strong>Sun:</strong> visible motivation and strategic will.</li>
        <li><strong>Moon:</strong> emotional regulation pattern.</li>
        <li><strong>Rising:</strong> behavior under pressure and social response style.</li>
      </ul>
      <p>Then move to placements and houses: ask “where will this show up in real life?” rather than “what does this mean abstractly?”.</p>
      <h2>3. Use Daily as your execution dashboard</h2>
      <p>The daily module is strongest when used for timing and load management. Treat it like a tactical panel:</p>
      <ul class="bullet-list">
        <li>Schedule complex conversations in higher-clarity windows.</li>
        <li>Place demanding work in periods with stronger execution signals.</li>
        <li>Use lower-energy windows for admin, review, and recovery tasks.</li>
      </ul>
      <p>Do not use Daily as a fatalistic “good/bad day” verdict. Use it as a context layer to sequence actions with less friction.</p>
      <h2>4. Use Friends for communication architecture</h2>
      <p>The Friends module gives practical compatibility diagnostics: communication sync, emotional stability, and friction load. In expanded cards, read the domain-level details and convert them into protocol-level agreements.</p>
      <p>Example: if communication sync is high but friction load increases under deadlines, define async check-ins and explicit ownership before sprint starts. Compatibility is useful only when translated into shared operating rules.</p>
      <h2>5. Build a weekly loop (the highest-ROI flow)</h2>
      <p>A simple loop used by power users:</p>
      <ul class="bullet-list">
        <li><strong>Monday:</strong> review Daily + choose one strategic focus signal.</li>
        <li><strong>Midweek:</strong> check Friends dynamics for key interactions.</li>
        <li><strong>Friday:</strong> compare planned vs. executed decisions.</li>
        <li><strong>Sunday:</strong> update one protocol for next week.</li>
      </ul>
      <p>Over 4-6 weeks, this loop reveals your real pattern mechanics and improves decision quality faster than random intuition alone.</p>
      <h2>6. Common mistakes to avoid</h2>
      <ul class="bullet-list">
        <li>Reading symbolism without converting it into behavior.</li>
        <li>Changing too many variables at once.</li>
        <li>Using compatibility as a label instead of a protocol input.</li>
        <li>Ignoring recovery windows while optimizing only output windows.</li>
      </ul>
      <h2>7. A practical template you can copy</h2>
      <p>Each week, write three lines:</p>
      <ul class="bullet-list">
        <li><strong>Signal:</strong> what pattern is active?</li>
        <li><strong>Action:</strong> what one measurable behavior will you run?</li>
        <li><strong>Review:</strong> what changed in clarity, conflict, or completion?</li>
      </ul>
      <p>That is the core of Astronautica usage: insight -> protocol -> measurable outcome.</p>
      <h2>Where to continue</h2>
      <p>Next, read <a href="/astrology-hub/astrology-for-self-knowledge-and-growth">Astrology for Self-Knowledge and Growth</a> and browse the 12 sign guides in <a href="/astrology-hub">Astrology Hub</a> to tune your model further.</p>
    `
  },
  {
    slug: "tarot-for-self-discovery-modern-practice-and-basilarcana-app",
    title: "Tarot for Self-Discovery: A Modern Practice and the Basilarcana App",
    excerpt: "A practical, non-mystifying way to use Tarot for reflection, decision framing, and emotional clarity — and where to start in the Basilarcana app.",
    readTime: "14 min",
    publishedAt: "2026-03-02",
    category: "Tarot",
    seoDescription: "Learn how to use Tarot for self-discovery with practical prompts and routines, and discover the Basilarcana Tarot app at basilarcana.com.",
    content: `
      <p class="article-lead">Tarot can be used as a powerful reflective interface: not fortune telling, but a structured prompt system for attention, emotional literacy, and better decisions. This article explains the modern approach and how to start with the Basilarcana Tarot app.</p>
      <h2>Tarot as a cognitive mirror</h2>
      <p>When used well, a spread helps you externalize hidden assumptions. Cards create distance from immediate emotion and allow clearer naming of fear, desire, conflict, and next action. The value is not in magical certainty; it is in better questions.</p>
      <h2>A practical 3-step Tarot method</h2>
      <ul class="bullet-list">
        <li><strong>Context:</strong> define one concrete question (“What blocks this decision?”).</li>
        <li><strong>Structure:</strong> use a fixed spread format (e.g., Situation -> Friction -> Action).</li>
        <li><strong>Translation:</strong> convert symbolic insight into one behavioral experiment.</li>
      </ul>
      <p>This method keeps Tarot grounded and measurable. If you cannot name an action after a reading, the reading is incomplete.</p>
      <h2>What makes a reading useful</h2>
      <p>Useful readings are specific, time-bound, and emotionally honest. They reduce ambiguity rather than inflate it. A strong reading ends with one decision, one boundary, and one review point.</p>
      <h2>What to avoid</h2>
      <ul class="bullet-list">
        <li>Using Tarot to avoid responsibility (“the card told me, so I have no choice”).</li>
        <li>Repeating the same question many times until anxiety drops.</li>
        <li>Treating symbolic language as literal prediction.</li>
      </ul>
      <h2>How Basilarcana approaches Tarot</h2>
      <p>Our Tarot product focuses on self-discovery and behavioral clarity. We design spreads and interpretations to help users reflect, decide, and act. The product now also includes multilingual support, so users can work in the language that feels natural for deeper reflection.</p>
      <p>If you want to explore it directly, visit <a href="https://basilarcana.com" target="_blank" rel="noopener noreferrer">basilarcana.com</a>.</p>
      <h2>Suggested weekly Tarot routine</h2>
      <ul class="bullet-list">
        <li><strong>Monday:</strong> one card for strategic focus.</li>
        <li><strong>Midweek:</strong> three-card spread for conflict resolution.</li>
        <li><strong>Weekend:</strong> retrospective spread (what worked / what drained / what to adjust).</li>
      </ul>
      <p>Combined with Astrology Hub insights, Tarot becomes a second lens for reflection: astrology maps pattern architecture, Tarot sharpens present-tense awareness.</p>
      <p>Continue with <a href="/astrology-hub/how-to-use-astronautica-complete-practical-guide">How to Use Astronautica: A Complete Practical Guide</a>.</p>
    `
  },
  {
    slug: "solar-system-planets-astrology-and-the-battlestar-galactica-inspiration",
    title: "Solar System Planets, Astrology, and the Battlestar Galactica Spark Behind Astronautica",
    excerpt: "A deep longread on planetary symbolism, practical astrology, and the science-fiction inspiration that shaped Astronautica's product vision.",
    readTime: "22 min",
    publishedAt: "2026-03-02",
    category: "Longread",
    seoDescription: "A long-form guide to Solar System planets and their astrological meaning, plus the Battlestar Galactica inspiration behind the Astronautica product vision.",
    content: `
      <p class="article-lead">The Solar System can be read in two complementary ways. Astronomy gives us physical reality: mass, orbit, velocity, magnetic field, temperature, distance. Astrology gives us symbolic reality: identity, regulation, desire, structure, expansion, disruption, and meaning. Astronautica exists at that intersection, and this longread explains why.</p>
      <h2>Why planets still matter in modern product thinking</h2>
      <p>In product work, we constantly model systems: user behavior, decision latency, friction points, momentum curves, failure loops. Planetary language maps surprisingly well to this systems thinking. Not as literal causation, but as a shared symbolic grammar for pattern recognition.</p>
      <p>That is the design philosophy behind Astronautica: deterministic computation for chart geometry, then structured interpretation for actionable behavior.</p>
      <h2>Sun: identity, direction, and core signal</h2>
      <p>Astronomically, the Sun is the central energy source of the Solar System. Astrologically, it maps to core will, identity coherence, and directional force. In practical usage, Sun-sign intelligence answers one question: what kind of goal architecture keeps your motivation stable over time?</p>
      <p>In Astronautica, we treat Sun signals as strategic orientation, not personality slogans.</p>
      <h2>Moon: regulation, rhythm, and recovery</h2>
      <p>The Moon's physical pull affects tides; symbolically it maps to emotional cycles and regulation bandwidth. Productively, Moon patterns help answer: when does your clarity degrade, and what recovery protocol restores signal quality?</p>
      <p>This is why Daily timing and recovery windows are central in our system.</p>
      <h2>Mercury and Venus: communication + values</h2>
      <p>Mercury governs framing, language precision, and decision speed. Venus maps to preferences, attraction patterns, and relational economics. Together, they are crucial for how teams align and how relationships avoid unnecessary friction.</p>
      <p>In the Friends module, this becomes practical: communication sync, emotional stability, and friction load are not abstractions, they are coordination metrics.</p>
      <h2>Mars: action, risk, and conflict heat</h2>
      <p>Mars is execution pressure. High Mars phases can produce fast output or avoidable conflict, depending on process quality. The practical question is not “is Mars good or bad?”, but “what constraints make action efficient and non-destructive?”.</p>
      <h2>Jupiter and Saturn: expansion vs. structure</h2>
      <p>Jupiter represents scaling, confidence, and opportunity appetite. Saturn represents boundaries, discipline, and reliability under long cycles. Every serious strategy needs both: expansion without structure burns out; structure without expansion stagnates.</p>
      <p>A strong weekly routine balances Jupiter-style exploration with Saturn-style completion criteria.</p>
      <h2>Uranus, Neptune, Pluto: change, meaning, transformation</h2>
      <p>These outer planets are slower and often felt through long-cycle themes. Uranus is system disruption and innovation. Neptune is narrative, imagination, and ambiguity management. Pluto is deep transformation, power dynamics, and irreversible transitions.</p>
      <p>In product terms, these are architecture-level forces, not day-level tactics.</p>
      <h2>Astronomy and astrology are not enemies here</h2>
      <p>Astronomy gives us precision coordinates and orbital truth. Astrology gives us a symbolic interface for human pattern interpretation. We deliberately keep both layers separate and explicit. Inputs and calculations are deterministic. Interpretations are operational guidance, validated through behavior and outcomes.</p>
      <p>If you want the broader history, continue with <a href="/astrology-hub/astrology-and-astronomy-shared-roots-modern-paths">Astrology and Astronomy: Ancient Roots, Modern Paths</a>.</p>
      <h2>The Battlestar Galactica moment</h2>
      <p>Now the personal part. The spark behind this product came from one source: <em>Battlestar Galactica</em>. Not because it is “about astrology,” but because it is one of the strongest narratives ever built around systems under pressure, identity under uncertainty, and decisions made with incomplete information.</p>
      <p>That series repeatedly asks the same product question we ask in Astronautica: how do humans maintain agency, coherence, and ethics when signal is noisy and stakes are high?</p>
      <p>That mindset shaped the core: build tools that reduce noise, surface structure, and help people decide better in real life.</p>
      <h2>How this inspiration became product decisions</h2>
      <ul class="bullet-list">
        <li><strong>Deterministic core:</strong> no opaque “magic score,” clear computation from input data.</li>
        <li><strong>Operational outputs:</strong> every insight should convert into a protocol, not a mood.</li>
        <li><strong>Weekly cadence:</strong> behavior changes through loops, not one-time revelations.</li>
        <li><strong>Human agency first:</strong> symbols guide reflection; decisions remain yours.</li>
      </ul>
      <h2>How to read planets inside Astronautica today</h2>
      <p>Use a three-step routine:</p>
      <ul class="bullet-list">
        <li><strong>Map:</strong> identify active planetary patterns in Natal + Daily.</li>
        <li><strong>Translate:</strong> choose one behavior protocol for the week.</li>
        <li><strong>Review:</strong> track whether conflict, clarity, or completion improved.</li>
      </ul>
      <p>This creates a closed loop from symbolism to action to measurable feedback.</p>
      <h2>Final note</h2>
      <p>Astronautica is our attempt to build a world-class astrology/astronomy companion that treats users like thinking adults: transparent methods, high signal, and practical outcomes.</p>
      <p>Continue with <a href="/astrology-hub/how-to-use-astronautica-complete-practical-guide">How to Use Astronautica: A Complete Practical Guide</a> and <a href="/astrology-hub/astrology-for-self-knowledge-and-growth">Astrology for Self-Knowledge and Growth</a>.</p>
    `
  }
];

function buildSignHubArticle(sign) {
  const idx = zodiacOrder.indexOf(sign);
  const prev = zodiacOrder[(idx + zodiacOrder.length - 1) % zodiacOrder.length];
  const next = zodiacOrder[(idx + 1) % zodiacOrder.length];
  const opposite = zodiacOrder[(idx + 6) % zodiacOrder.length];
  const profile = zodiacHubProfiles[sign];
  const details = zodiacDetails(sign);
  const slug = `${String(sign).toLowerCase()}-zodiac-sign-guide`;
  return {
    slug,
    title: profile.title,
    excerpt: profile.excerpt,
    readTime: "8 min",
    publishedAt: "2026-03-02",
    category: "Sign Guide",
    seoDescription: profile.seoDescription,
    sign,
    imageLight: details.imageUrlLight,
    imageDark: details.imageUrlDark,
    content: `
      <p class="article-lead">${profile.angle}</p>
      <h2>Core operating pattern</h2>
      <p>${sign} belongs to ${details.element} element and ${details.modality} mode. In practical terms, this means your default strategy is shaped by how you start, stabilize, and adapt under pressure. The best outcomes appear when this pattern is named explicitly and converted into rituals.</p>
      <h2>Strength profile</h2>
      <p>${profile.strengths}</p>
      <h2>Where friction usually appears</h2>
      <p>${profile.risk}</p>
      <h2>Execution protocol for this sign</h2>
      <p>${profile.protocol}</p>
      <h2>Relationship and collaboration note</h2>
      <p>In teams and relationships, ${sign} works best with transparent commitments and time boundaries. If your default style is understood and communicated early, conflict cost goes down and trust speed goes up.</p>
      <h2>Cross-sign navigation</h2>
      <p>For contrast and growth, compare this profile with <a href="/astrology-hub/${String(opposite).toLowerCase()}-zodiac-sign-guide">${opposite}</a>. For sequence reading, continue with <a href="/astrology-hub/${String(next).toLowerCase()}-zodiac-sign-guide">${next}</a> or review <a href="/astrology-hub/${String(prev).toLowerCase()}-zodiac-sign-guide">${prev}</a>.</p>
      <p>Also read: <a href="/astrology-hub/how-to-avoid-astrology-scams">How to Avoid Astrology Scams</a>.</p>
    `
  };
}

const signHubArticles = zodiacOrder.map((sign) => buildSignHubArticle(sign));
const astrologyHubArticles = [...coreHubArticles, ...signHubArticles];

const astrologyHubBySlug = astrologyHubArticles.reduce((acc, article) => {
  acc[article.slug] = article;
  return acc;
}, {});

function astrologyHubView() {
  return `
    <section class="section">
      <article class="card tone-card">
        <span class="eyebrow">Astrology Hub</span>
        <h1>Research + insight journal</h1>
        <p>Public long-form pieces from Astronautica: method, history, safety standards, and practical models for reflective decision-making.</p>
      </article>
    </section>
    <section class="section">
      <div class="hub-grid">
        ${astrologyHubArticles
          .map((article) => `
            <article class="card hub-card">
              ${
                article.sign
                  ? `<a class="hub-sign-thumb-link" href="/astrology-hub/${article.slug}">
                      <img
                        class="hub-sign-thumb"
                        src="${state.theme === "light" ? article.imageLight : article.imageDark}"
                        data-zodiac-light="${article.imageLight}"
                        data-zodiac-dark="${article.imageDark}"
                        alt="${article.sign} zodiac illustration"
                        loading="lazy"
                        decoding="async"
                      />
                    </a>`
                  : ""
              }
              <div class="hub-card-head">
                <span class="hub-chip">${article.category}</span>
                <span class="hub-meta">${article.readTime}</span>
              </div>
              <h2>${article.title}</h2>
              <p>${article.excerpt}</p>
              <div class="hub-card-footer">
                <time datetime="${article.publishedAt}">${new Date(article.publishedAt).toLocaleDateString("en-US", { day: "2-digit", month: "long", year: "numeric" })}</time>
                <a class="hub-link" href="/astrology-hub/${article.slug}">Read article</a>
              </div>
            </article>
          `)
          .join("")}
      </div>
    </section>
  `;
}

function astrologyHubArticleView(slug) {
  const article = astrologyHubBySlug[slug];
  if (!article) {
    return `
      <section class="section">
        <article class="card">
          <h1>Article not found</h1>
          <p class="muted">This article is unavailable. Return to <a href="/astrology-hub">Astrology Hub</a>.</p>
        </article>
      </section>
    `;
  }
  const related = astrologyHubArticles.filter((item) => item.slug !== slug).slice(0, 2);
  return `
    <section class="section">
      <article class="card tone-card article-hero">
        <div class="article-hero-grid">
          <div class="article-hero-copy">
            <span class="eyebrow">Astrology Hub</span>
            <h1>${article.title}</h1>
            <div class="hub-card-footer">
              <span class="hub-chip">${article.category}</span>
              <time datetime="${article.publishedAt}">${new Date(article.publishedAt).toLocaleDateString("en-US", { day: "2-digit", month: "long", year: "numeric" })}</time>
              <span class="hub-meta">${article.readTime}</span>
            </div>
          </div>
          ${
            article.sign
              ? `<img
                  class="article-sign-hero"
                  src="${state.theme === "light" ? article.imageLight : article.imageDark}"
                  data-zodiac-light="${article.imageLight}"
                  data-zodiac-dark="${article.imageDark}"
                  alt="${article.sign} zodiac illustration"
                  loading="lazy"
                  decoding="async"
                />`
              : ""
          }
        </div>
      </article>
    </section>
    <section class="section">
      <article class="card article-body">
        ${article.content}
      </article>
    </section>
    <section class="section">
      <article class="card">
        <h2>Related Articles</h2>
        <div class="hub-grid related-grid">
          ${related
            .map((item) => `
              <article class="hub-card">
                <div class="hub-card-head">
                  <span class="hub-chip">${item.category}</span>
                  <span class="hub-meta">${item.readTime}</span>
                </div>
                <h2>${item.title}</h2>
                <p>${item.excerpt}</p>
                <div class="hub-card-footer">
                  <time datetime="${item.publishedAt}">${new Date(item.publishedAt).toLocaleDateString("en-US", { day: "2-digit", month: "long", year: "numeric" })}</time>
                  <a class="hub-link" href="/astrology-hub/${item.slug}">Read article</a>
                </div>
              </article>
            `)
            .join("")}
        </div>
      </article>
    </section>
    <section class="section">
      <article class="card article-cta">
        <h2>Explore more from Astrology Hub</h2>
        <p class="muted">Continue reading: history, safety, and practical frameworks for modern reflective astrology.</p>
        <a class="btn ghost" href="/astrology-hub">Back to all articles</a>
      </article>
    </section>
  `;
}

function privacyPolicyView() {
  return `
    <section class="section">
      <article class="card tone-card">
        <span class="eyebrow">Legal</span>
        <h1>Privacy Policy</h1>
        <p>Effective date: February 28, 2026. This policy explains how Astronautica processes personal data for users in the European Economic Area (EEA), the UK and Switzerland.</p>
      </article>
    </section>
    <section class="section">
      <article class="card faq legal-doc">
        <article class="faq-item">
          <h3>1. Data controller</h3>
          <p>Astronautica is operated by Basilarcana. For privacy requests, contact us at <a href="mailto:privacy@basilarcana.com">privacy@basilarcana.com</a>.</p>
        </article>
        <article class="faq-item">
          <h3>2. What data we collect</h3>
          <p>We may process account data (name, username, email), authentication data (Telegram, GitHub or Google login identifiers), profile data (birth date, birth time, birth place, timezone), friends data you add, and technical logs required for security and service reliability.</p>
        </article>
        <article class="faq-item">
          <h3>3. Why we process data (GDPR legal bases)</h3>
          <ul class="bullet-list">
            <li>Contract performance (Article 6(1)(b)): to provide the app, generate natal analytics, daily insights and friend compatibility features.</li>
            <li>Legitimate interests (Article 6(1)(f)): fraud prevention, abuse prevention, platform security and service quality diagnostics.</li>
            <li>Legal obligations (Article 6(1)(c)): compliance with applicable laws and regulatory obligations.</li>
            <li>Consent (Article 6(1)(a)), where required: optional communications and optional product analytics/cookies.</li>
          </ul>
        </article>
        <article class="faq-item">
          <h3>4. Sensitive data and user responsibility</h3>
          <p>Birth and relationship-related data can be sensitive in context. Please add only data you are authorized to share. You are responsible for obtaining your friends’ permission before entering their personal data in the service.</p>
        </article>
        <article class="faq-item">
          <h3>5. Data retention</h3>
          <p>We keep account and profile data while your account is active. We delete or anonymize data when it is no longer necessary for the original purpose, unless longer retention is required by law (for example, security, tax, accounting, or dispute resolution requirements).</p>
        </article>
        <article class="faq-item">
          <h3>6. International data transfers</h3>
          <p>If we transfer personal data outside the EEA/UK/Switzerland, we apply appropriate safeguards, including Standard Contractual Clauses (SCCs) where applicable, and additional technical and organizational protections.</p>
        </article>
        <article class="faq-item">
          <h3>7. Your rights in Europe</h3>
          <ul class="bullet-list">
            <li>Right of access, rectification and erasure.</li>
            <li>Right to restriction and right to object to certain processing.</li>
            <li>Right to data portability where applicable.</li>
            <li>Right to withdraw consent at any time for consent-based processing.</li>
            <li>Right to lodge a complaint with your local data protection authority.</li>
          </ul>
        </article>
        <article class="faq-item">
          <h3>8. Security</h3>
          <p>We use organizational and technical measures to protect personal data, including access controls, transport security, and monitoring. No system is perfectly secure, so users should protect account credentials and report suspected abuse immediately.</p>
        </article>
        <article class="faq-item">
          <h3>9. Automated processing</h3>
          <p>Astronautica generates automated analytical outputs based on user-provided data and deterministic computation models. Outputs are informational and planning-oriented and are not intended as medical, legal, or financial advice.</p>
        </article>
        <article class="faq-item">
          <h3>10. Contact and updates</h3>
          <p>For privacy requests, contact <a href="mailto:privacy@basilarcana.com">privacy@basilarcana.com</a>. We may update this policy from time to time; material updates will be reflected by a revised effective date.</p>
        </article>
      </article>
    </section>
  `;
}

function termsOfServiceView() {
  return `
    <section class="section">
      <article class="card tone-card">
        <span class="eyebrow">Legal</span>
        <h1>Terms of Service</h1>
        <p>Effective date: February 28, 2026. These Terms govern your use of Astronautica in the EEA, UK and Switzerland.</p>
      </article>
    </section>
    <section class="section">
      <article class="card faq legal-doc">
        <article class="faq-item">
          <h3>1. Agreement and eligibility</h3>
          <p>By using Astronautica, you agree to these Terms. You must be legally able to enter into a binding agreement under applicable law. If you use the service on behalf of an organization, you confirm authority to bind that organization.</p>
        </article>
        <article class="faq-item">
          <h3>2. Service scope</h3>
          <p>Astronautica provides astrology-based analytical tools, profile features, daily insights, and compatibility workflows. The service is informational and reflective; it does not replace professional medical, legal, financial, or mental health advice.</p>
        </article>
        <article class="faq-item">
          <h3>3. Accounts and access</h3>
          <p>Accounts may be created through Telegram, GitHub, or Google authentication. You are responsible for account activity, security of connected identities, and accuracy of data provided in your profile and friend entries.</p>
        </article>
        <article class="faq-item">
          <h3>4. Acceptable use</h3>
          <ul class="bullet-list">
            <li>No unlawful use, harassment, fraud, or abuse of the service.</li>
            <li>No attempts to bypass security, reverse engineer restricted components, or overload infrastructure.</li>
            <li>No submission of personal data you are not authorized to share.</li>
          </ul>
        </article>
        <article class="faq-item">
          <h3>5. User content and permissions</h3>
          <p>You retain rights to content and data you submit, while granting Astronautica a limited license to process that data for service delivery, security, and improvement. You can delete your profile/friends data from the app interface where available.</p>
        </article>
        <article class="faq-item">
          <h3>6. Fees and changes</h3>
          <p>Unless explicitly stated otherwise, current features are provided without guaranteed paid SLA. We may change, improve, or discontinue features to maintain product quality, security, and legal compliance.</p>
        </article>
        <article class="faq-item">
          <h3>7. Suspension and termination</h3>
          <p>We may suspend or terminate access for material violations of these Terms, security risk, abuse, or legal necessity. You may stop using the service at any time.</p>
        </article>
        <article class="faq-item">
          <h3>8. Warranties and liability</h3>
          <p>The service is provided on an “as is” and “as available” basis to the extent permitted by law. We do not guarantee uninterrupted availability or specific outcomes. Nothing in these Terms excludes liability that cannot be excluded under applicable consumer or data protection law.</p>
        </article>
        <article class="faq-item">
          <h3>9. Governing law and disputes</h3>
          <p>These Terms are governed by the laws of the operator’s country of establishment, without prejudice to mandatory consumer protections in your country of residence within the EEA/UK/Switzerland.</p>
        </article>
        <article class="faq-item">
          <h3>10. Contact</h3>
          <p>For legal requests, contact <a href="mailto:legal@basilarcana.com">legal@basilarcana.com</a>. For privacy matters, see the Privacy Policy and contact <a href="mailto:privacy@basilarcana.com">privacy@basilarcana.com</a>.</p>
        </article>
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
  "/faq": faqView,
  "/astrology-hub": astrologyHubView,
  "/privacy-policy": privacyPolicyView,
  "/terms-of-service": termsOfServiceView
};

function applySeoMeta(path) {
  const defaultMeta = {
    title: "Astronautica",
    description: "Astronautica: precision natal intelligence, daily guidance and compatibility insights."
  };
  const pageMeta = {
    "/faq": {
      title: "FAQ - Astronautica",
      description: "Astronautica FAQ: methodology, natal chart calculations, compatibility logic and product boundaries."
    },
    "/astrology-hub": {
      title: "Astrology Hub - Astronautica",
      description: "Astrology Hub by Astronautica: in-depth sign guides, method papers, safety standards, and applied astrological strategy."
    },
    "/privacy-policy": {
      title: "Privacy Policy - Astronautica",
      description: "Astronautica Privacy Policy for EEA, UK and Switzerland users."
    },
    "/terms-of-service": {
      title: "Terms of Service - Astronautica",
      description: "Astronautica Terms of Service for EEA, UK and Switzerland users."
    }
  };
  const articleSlug = path.startsWith("/astrology-hub/") ? path.replace("/astrology-hub/", "") : null;
  const article = articleSlug ? astrologyHubBySlug[articleSlug] : null;
  const meta = article
    ? {
        title: `${article.title} - Astrology Hub`,
        description: article.seoDescription || defaultMeta.description
      }
    : (pageMeta[path] || defaultMeta);
  document.title = meta.title;

  const setMeta = (selector, content) => {
    const element = document.querySelector(selector);
    if (element) {
      element.setAttribute("content", content);
    }
  };
  setMeta('meta[name="description"]', meta.description);
  setMeta('meta[property="og:title"]', meta.title);
  setMeta('meta[property="og:description"]', meta.description);
  setMeta('meta[name="twitter:title"]', meta.title);
  setMeta('meta[name="twitter:description"]', meta.description);

  const canonical = document.querySelector('link[rel="canonical"]');
  const canonicalUrl = `https://app.basilarcana.com${path === "/" ? "/" : path}`;
  if (canonical) {
    canonical.setAttribute("href", canonicalUrl);
  }
  setMeta('meta[property="og:url"]', canonicalUrl);

  const schemaId = "page-structured-data";
  document.getElementById(schemaId)?.remove();
  if (article) {
    const script = document.createElement("script");
    script.id = schemaId;
    script.type = "application/ld+json";
    script.textContent = JSON.stringify({
      "@context": "https://schema.org",
      "@type": "Article",
      headline: article.title,
      description: article.seoDescription,
      datePublished: article.publishedAt,
      dateModified: article.publishedAt,
      inLanguage: "en",
      author: {
        "@type": "Organization",
        name: "Astronautica"
      },
      publisher: {
        "@type": "Organization",
        name: "Astronautica"
      },
      mainEntityOfPage: canonicalUrl
    });
    document.head.appendChild(script);
  }
}

function markActiveNav(path) {
  document.querySelectorAll(".nav a").forEach((link) => {
    const href = link.getAttribute("href");
    const isHub = href === "/astrology-hub" && path.startsWith("/astrology-hub");
    link.classList.toggle("active", href === path || isHub);
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
        return renderFriendAccordion({ ...friend, ...insight }, { canDelete: true });
      })
      .join("")
  }</div>`;
}

function bindFriendAccordionInteractions(root = document) {
  const closeCard = (card) => {
    if (!(card instanceof HTMLElement)) {
      return;
    }
    const button = card.querySelector(".friend-accordion-trigger");
    const body = card.querySelector(".friend-accordion-body");
    card.classList.remove("open");
    if (button instanceof HTMLElement) {
      button.setAttribute("aria-expanded", "false");
    }
    if (body instanceof HTMLElement) {
      if (body.style.maxHeight === "none") {
        body.style.maxHeight = `${body.scrollHeight}px`;
      }
      window.requestAnimationFrame(() => {
        body.style.maxHeight = "0px";
      });
    }
  };

  const openCard = (card) => {
    if (!(card instanceof HTMLElement)) {
      return;
    }
    const button = card.querySelector(".friend-accordion-trigger");
    const body = card.querySelector(".friend-accordion-body");
    card.classList.add("open");
    if (button instanceof HTMLElement) {
      button.setAttribute("aria-expanded", "true");
    }
    if (body instanceof HTMLElement) {
      body.style.maxHeight = "0px";
      window.requestAnimationFrame(() => {
        body.style.maxHeight = `${body.scrollHeight + 48}px`;
      });
      body.addEventListener("transitionend", () => {
        if (card.classList.contains("open")) {
          body.style.maxHeight = "none";
        }
      }, { once: true });
    }
  };

  root.querySelectorAll(".friend-accordion-trigger").forEach((button) => {
    button.addEventListener("click", () => {
      const card = button.closest(".friend-accordion");
      if (!(card instanceof HTMLElement)) {
        return;
      }
      const isAlreadyOpen = card.classList.contains("open");
      root.querySelectorAll(".friend-accordion.open").forEach((openCardNode) => {
        if (openCardNode !== card) {
          closeCard(openCardNode);
        }
      });
      if (isAlreadyOpen) {
        closeCard(card);
        return;
      }
      openCard(card);
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
      const telegram = target.getAttribute("data-telegram") || "";
      const email = target.getAttribute("data-email") || "";
      shareFriendCompatibility(friendName, friendSign, score, { telegram, email });
    });
  });
}

function bindDeleteFriendButtons(root = document, { onDeleted } = {}) {
  root.querySelectorAll(".js-delete-friend").forEach((button) => {
    button.addEventListener("click", async (event) => {
      event.stopPropagation();
      const target = event.currentTarget;
      if (!(target instanceof HTMLElement)) {
        return;
      }
      const friendId = String(target.getAttribute("data-id") || "").trim();
      const friendName = String(target.getAttribute("data-name") || "Friend").trim();
      if (!friendId) {
        return;
      }
      const confirmed = await openFriendDeleteModal(friendName);
      if (!confirmed) {
        return;
      }
      try {
        const payload = await fetchJson(`/api/friends/${encodeURIComponent(friendId)}`, { method: "DELETE" });
        state.friends = Array.isArray(payload?.friends) ? payload.friends : [];
        delete state.friendInsights[friendId];
        if (typeof onDeleted === "function") {
          await onDeleted();
        }
      } catch (error) {
        if (error.status === 401) {
          await refreshAuthState();
          navigate("/login", { replace: true });
          return;
        }
        alert(`Failed to remove friend: ${error.message}`);
      }
    });
  });
}

function closeFriendDeleteModal() {
  document.querySelector(".friend-delete-modal-backdrop")?.remove();
}

function openFriendDeleteModal(friendName) {
  return new Promise((resolve) => {
    closeFriendDeleteModal();
    const safeName = String(friendName || "Friend")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;")
      .replaceAll("'", "&#39;");
    const modal = document.createElement("div");
    modal.className = "friend-delete-modal-backdrop";
    modal.innerHTML = `
      <div class="friend-delete-modal card" role="dialog" aria-modal="true" aria-label="Remove friend">
        <span class="eyebrow">Remove friend</span>
        <h2>Confirm action</h2>
        <p>Remove ${safeName} from friends list?</p>
        <div class="friend-delete-modal-actions">
          <button class="btn ghost js-delete-cancel" type="button">Cancel</button>
          <button class="btn primary js-delete-confirm" type="button">Remove</button>
        </div>
      </div>
    `;
    const cleanup = (result) => {
      closeFriendDeleteModal();
      resolve(Boolean(result));
    };
    modal.addEventListener("click", (event) => {
      if (event.target === modal) {
        cleanup(false);
      }
    });
    modal.querySelector(".js-delete-cancel")?.addEventListener("click", () => cleanup(false));
    modal.querySelector(".js-delete-confirm")?.addEventListener("click", () => cleanup(true));
    document.body.appendChild(modal);
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

function normalizeEmail(value) {
  const raw = String(value || "").trim().toLowerCase();
  return looksLikeEmail(raw) ? raw : "";
}

function shareFriendCompatibility(friendName, friendSign, score, contact = {}) {
  const pct = Math.max(0, Math.min(100, Math.round(Number(score) || 0)));
  const reason = pct >= 75
    ? "strong communication sync and stable emotional rhythm"
    : pct >= 62
      ? "moderate alignment with clear communication requirements"
      : "higher friction load that needs explicit boundaries";
  const shareUrl = `https://app.basilarcana.com/share.html?score=${encodeURIComponent(String(pct))}&sign=${encodeURIComponent(String(friendSign || ""))}`;
  const subject = "Compatibility check from Astronautica";
  const summary = `I checked our compatibility on app.basilarcana.com: ${pct}%.`;
  const reasonText = `Why this score: ${reason}.`;
  const body = `${shareUrl}\n\n${summary}\n${reasonText}`;
  const telegram = normalizeTelegramHandle(contact.telegram || "");
  const email = normalizeEmail(contact.email || "");
  if (telegram) {
    fetchJson("/api/metrics/share-invite", { method: "POST", body: JSON.stringify({}) }).catch(() => {});
    window.open(`https://t.me/${encodeURIComponent(telegram)}?text=${encodeURIComponent(body)}`, "_blank", "noopener,noreferrer");
    return;
  }
  if (email) {
    fetchJson("/api/metrics/share-invite", { method: "POST", body: JSON.stringify({}) }).catch(() => {});
    window.location.href = `mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  }
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

    const personalizedHistory = personalizeDailyHistory(data.history, {
      core: state.dashboard?.natalCore,
      profile: state.profile
    });

    app.innerHTML = `
      <section class="hero">
        <article class="card daily-hero-main tone-card">
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
            <ul class="bullet-list">${personalizedHistory
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
  script.setAttribute("data-radius", "999");
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

function bindCityAutocomplete(form, cityInputId, options = {}) {
  const cityInput = document.getElementById(cityInputId);
  const datalistId = String(options?.datalistId || "citySuggestions");
  const strictSelection = Boolean(options?.strictSelection);
  const datalist = form?.querySelector(`#${datalistId}`);
  const latitudeInput = form?.querySelector('input[name="latitude"]');
  const longitudeInput = form?.querySelector('input[name="longitude"]');
  const timezoneIanaInput = form?.querySelector('input[name="timezoneIana"]');
  const timezoneInput = form?.querySelector('input[name="timezone"]');

  if (!form || !cityInput || !datalist) {
    return;
  }

  const applySelectedMeta = () => {
    const normalizedValue = String(cityInput.value || "").trim();
    const selected = citySuggestionMeta.get(normalizedValue);
    if (strictSelection) {
      if (normalizedValue && !selected) {
        cityInput.setCustomValidity("Select a city from suggestions.");
      } else {
        cityInput.setCustomValidity("");
      }
    }
    if (!selected) {
      if (latitudeInput) latitudeInput.value = "";
      if (longitudeInput) longitudeInput.value = "";
      if (timezoneIanaInput) timezoneIanaInput.value = "";
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
    if (strictSelection) {
      const currentValue = String(cityInput.value || "").trim();
      cityInput.setCustomValidity(currentValue && !citySuggestionMeta.has(currentValue) ? "Select a city from suggestions." : "");
    } else {
      cityInput.setCustomValidity("");
    }
    if (latitudeInput) latitudeInput.value = "";
    if (longitudeInput) longitudeInput.value = "";
    if (timezoneIanaInput) timezoneIanaInput.value = "";
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
    if (!state.authenticated && state.telegramLoginEnabled && state.telegramBotUsername) {
      mountTelegramWidget();
      const telegramLoginButton = document.getElementById("telegramLoginButton");
      telegramLoginButton?.addEventListener("click", handleSwitchTelegramAccount);
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
    const bindFriendListHandlers = () => {
      const list = document.getElementById("friendsList");
      if (!list) {
        return;
      }
      bindFriendAccordionInteractions(list);
      bindShareFriendButtons(list);
      bindDeleteFriendButtons(list, {
        onDeleted: async () => {
          await refreshFriendInsights();
          renderFriendsList();
          bindFriendListHandlers();
        }
      });
    };
    refreshFriendInsights().finally(() => {
      renderFriendsList();
      bindFriendListHandlers();
    });

    const form = document.getElementById("friendForm");
    bindCityAutocomplete(form, "friendBirthCity", { datalistId: "friendCitySuggestions", strictSelection: true });
    const telegramInput = document.getElementById("friendTelegram");
    const emailInput = document.getElementById("friendEmail");
    const noShareCheckbox = document.getElementById("friendNoShareData");
    const syncFriendContactRules = () => {
      const noShare = Boolean(noShareCheckbox?.checked);
      if (telegramInput) {
        telegramInput.required = !noShare && !(emailInput?.value || "").trim();
      }
      if (emailInput) {
        emailInput.required = !noShare && !(telegramInput?.value || "").trim();
      }
    };
    telegramInput?.addEventListener("input", syncFriendContactRules);
    emailInput?.addEventListener("input", syncFriendContactRules);
    noShareCheckbox?.addEventListener("change", syncFriendContactRules);
    syncFriendContactRules();
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!form.reportValidity()) {
        return;
      }
      const formData = new FormData(form);
      const friend = Object.fromEntries(formData.entries());
      friend.noShareData = Boolean(noShareCheckbox?.checked);
      try {
        const payload = await fetchJson("/api/friends", {
          method: "POST",
          body: JSON.stringify(friend)
        });
        state.friends = payload.friends || [];
        form.reset();
        syncFriendContactRules();
        await refreshFriendInsights();
        renderFriendsList();
        bindFriendListHandlers();
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
  state.googleLoginEnabled = Boolean(auth.googleLoginEnabled);
  state.githubLoginEnabled = Boolean(auth.githubLoginEnabled);
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
  const hubSlug = path.startsWith("/astrology-hub/") ? path.replace("/astrology-hub/", "") : "";
  const isPublicHubArticle = Boolean(hubSlug && astrologyHubBySlug[hubSlug]);
  const publicPaths = new Set([
    "/login",
    "/faq",
    "/astrology-hub",
    "/privacy-policy",
    "/terms-of-service"
  ]);
  if (path !== "/profile") {
    state.profileEditMode = false;
  }
  const profileExists = hasProfile();

  if (state.authRequired && !state.authenticated && !publicPaths.has(path) && !isPublicHubArticle) {
    path = "/login";
    window.history.replaceState({}, "", path);
  }

  if (state.authRequired && state.authenticated && !profileExists && !["/onboarding", ...publicPaths].includes(path) && !isPublicHubArticle) {
    path = "/onboarding";
    window.history.replaceState({}, "", path);
  }

  if (state.authRequired && state.authenticated && profileExists && path === "/onboarding") {
    path = "/";
    window.history.replaceState({}, "", path);
  }

  if (path !== "/") {
    destroySolarSystemWidget();
  }

  const makeView = routes[path] || (isPublicHubArticle ? () => astrologyHubArticleView(hubSlug) : homeViewLoading);
  app.innerHTML = makeView();
  syncZodiacThemeImages(state.theme);
  applySeoMeta(path);
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
  if (!href || href.startsWith("http") || href.startsWith("mailto:") || href.startsWith("/api/")) {
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
