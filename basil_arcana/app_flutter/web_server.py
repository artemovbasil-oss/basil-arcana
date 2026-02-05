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


CONFIG_PATH: str | None = None


class WebAppHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/manifest.json", "/flutter.js"):
            print(f"Request for {parsed.path}")
        if parsed.path == "/healthz":
            body = b"ok"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if parsed.path == "/config.json":
            if not CONFIG_PATH:
                self.send_error(500, "config.json is not initialized")
                return
            try:
                with open(CONFIG_PATH, "rb") as handle:
                    body = handle.read()
            except OSError as exc:
                self.send_error(500, f"Failed to read config.json: {exc}")
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def end_headers(self):
        path = urlparse(self.path).path
        if path == "/config.json":
            super().end_headers()
            return
        filename = os.path.basename(path)
        if filename in NO_STORE_FILES or filename.startswith(ASSET_PREFIXES) or filename == "flutter_service_worker.js":
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
        else:
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        super().end_headers()


def resolve_config_dir(preferred: str, fallback: str) -> str:
    attempts = [preferred, fallback]
    if os.path.isdir(preferred) and os.access(preferred, os.W_OK):
        return preferred
    if not os.path.isdir(fallback):
        try:
            os.makedirs(fallback, exist_ok=True)
        except OSError:
            pass
    if os.path.isdir(fallback) and os.access(fallback, os.W_OK):
        return fallback
    raise RuntimeError(f"No writable config directory found (attempted: {attempts})")


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    directory = os.environ.get("WEB_ROOT", "/app/static")
    preferred_dir = os.environ.get("CONFIG_DIR", "/app/static")
    config_dir = resolve_config_dir(preferred_dir, "/tmp/static")
    required_files = ("index.html", "manifest.json", "flutter.js", "main.dart.js")
    missing_files = [
        name
        for name in required_files
        if not os.path.isfile(os.path.join(directory, name))
    ]
    if missing_files:
        print(
            f"Warning: missing static files in {directory}: {', '.join(missing_files)}"
        )
    else:
        print(f"Static files present in {directory}: {', '.join(required_files)}")
    build_id = (
        os.environ.get("WEB_BUILD")
        or os.environ.get("RAILWAY_GIT_COMMIT_SHA")
        or os.environ.get("GIT_SHA")
        or ""
    )
    config_path = os.path.join(config_dir, "config.json")
    payload = {
        "apiBaseUrl": os.environ.get("API_BASE_URL", ""),
        "build": build_id,
    }
    try:
        with open(config_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
        with open(config_path, "rb") as handle:
            config_size = len(handle.read())
    except OSError as exc:
        raise RuntimeError(
            f"Failed to write/read config.json (attempted: {config_path})"
        ) from exc
    print(f"Resolved config dir: {config_dir} (cwd: {os.getcwd()})")
    print(f"config.json size: {config_size} bytes")
    global CONFIG_PATH
    CONFIG_PATH = config_path
    handler = functools.partial(WebAppHandler, directory=directory)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"Listening on 0.0.0.0:{port}, serving {directory}")
    server.serve_forever()


if __name__ == "__main__":
    main()
