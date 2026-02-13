import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const port = Number(process.env.PORT || 8080);

const mimeByExt = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".webm": "video/webm",
};

function contentTypeFor(filePath) {
  return mimeByExt[extname(filePath).toLowerCase()] || "application/octet-stream";
}

const server = createServer(async (req, res) => {
  try {
    const path = req.url === "/" ? "/index.html" : req.url || "/index.html";
    const safePath = path.includes("..") ? "/index.html" : path;
    const fullPath = join(__dirname, safePath);
    const body = await readFile(fullPath);
    res.writeHead(200, {
      "Content-Type": contentTypeFor(fullPath),
      "Cache-Control": "public, max-age=300",
    });
    res.end(body);
  } catch {
    const body = await readFile(join(__dirname, "index.html"));
    res.writeHead(200, {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    });
    res.end(body);
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Landing is listening on :${port}`);
});
