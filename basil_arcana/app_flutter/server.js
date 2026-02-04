const express = require("express");
const path = require("path");

const app = express();
const port = process.env.PORT || 3000;
const apiBaseUrl = process.env.ARCANA_API_BASE_URL || "https://api.basilarcana.com";
const apiKey = process.env.ARCANA_API_KEY;

const fetchImpl =
  typeof fetch === "function"
    ? fetch
    : (...args) =>
        import("node-fetch").then(({ default: fetchFn }) => fetchFn(...args));

app.use(express.json({ limit: "1mb" }));

function buildProxyUrl(targetPath, query) {
  const url = new URL(targetPath, apiBaseUrl);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (Array.isArray(value)) {
        value.forEach((entry) => url.searchParams.append(key, String(entry)));
      } else if (value !== undefined) {
        url.searchParams.set(key, String(value));
      }
    }
  }
  return url;
}

async function handleProxy(req, res, targetPath) {
  if (!apiKey) {
    res.status(500).json({ error: "ARCANA_API_KEY is not configured." });
    return;
  }

  try {
    const url = buildProxyUrl(targetPath, req.query);
    const response = await fetchImpl(url.toString(), {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        ...(req.headers["x-request-id"]
          ? { "x-request-id": req.headers["x-request-id"] }
          : {}),
      },
      body: JSON.stringify(req.body ?? {}),
    });
    const body = await response.text();
    res.status(response.status);
    if (response.headers.get("content-type")) {
      res.set("content-type", response.headers.get("content-type"));
    }
    res.send(body);
  } catch (error) {
    console.error("Proxy error", error);
    res.status(502).json({ error: "Proxy request failed." });
  }
}

app.post("/proxy/reading/generate", (req, res) =>
  handleProxy(req, res, "/api/reading/generate")
);
app.post("/proxy/reading/details", (req, res) =>
  handleProxy(req, res, "/api/reading/details")
);

const webRoot = path.join(__dirname, "build", "web");
app.use(express.static(webRoot));
app.get("*", (_req, res) => {
  res.sendFile(path.join(webRoot, "index.html"));
});

app.listen(port, () => {
  console.log(`Webapp server listening on ${port}`);
});
