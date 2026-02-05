import functools
import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

NO_STORE_FILES = {
    "index.html",
    "flutter.js",
    "flutter_bootstrap.js",
    "main.dart.js",
    "FontManifest.json",
    "version.json",
    "manifest.json",
}

ASSET_PREFIXES = ("AssetManifest",)


class WebAppHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/config.json":
            payload = {
                "apiBaseUrl": os.environ.get("API_BASE_URL", ""),
                "apiKey": os.environ.get("API_KEY", ""),
            }
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def end_headers(self):
        path = urlparse(self.path).path
        filename = os.path.basename(path)
        if filename in NO_STORE_FILES or filename.startswith(ASSET_PREFIXES) or filename == "flutter_service_worker.js":
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
        else:
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        super().end_headers()


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    directory = os.environ.get("WEB_ROOT", "/app")
    handler = functools.partial(WebAppHandler, directory=directory)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"Serving {directory} on port {port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
