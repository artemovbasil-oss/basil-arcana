import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();
const port = Number(process.env.PORT || 8080);
const publicDir = path.join(__dirname, "public");

app.use(express.static(publicDir, {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith("index.html")) {
      res.setHeader("Cache-Control", "no-store");
      return;
    }
    res.setHeader("Cache-Control", "public, max-age=300");
  }
}));

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "astro-web" });
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(publicDir, "index.html"));
});

app.listen(port, "0.0.0.0", () => {
  console.log(`astro-web listening on :${port}`);
});
