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
CONFIG_BUILD: str = ""


def _read_env(*keys: str) -> str:
    for key in keys:
        value = os.environ.get(key)
        if value is not None and value.strip():
            return value.strip()
    return ""


def build_config_payload() -> dict[str, str]:
    api_base_url = _read_env("API_BASE_URL", "BASE_URL")
    api_key = _read_env("API_KEY", "ARCANA_API_KEY")
    payload: dict[str, str] = {
        "apiBaseUrl": api_base_url,
        "apiKey": api_key,
        "build": CONFIG_BUILD,
    }
    if not api_base_url or not api_key:
        missing = []
        if not api_base_url:
            missing.append("API_BASE_URL/BASE_URL")
        if not api_key:
            missing.append("API_KEY/ARCANA_API_KEY")
        payload["message"] = (
            "Missing runtime configuration: " + ", ".join(missing)
        )
    return payload


def log_config_presence() -> None:
    api_base_url_present = bool(_read_env("API_BASE_URL", "BASE_URL"))
    api_key_present = bool(_read_env("API_KEY", "ARCANA_API_KEY"))
    print(
        "Config env presence - API_BASE_URL/BASE_URL: "
        f"{'present' if api_base_url_present else 'missing'}, "
        "API_KEY/ARCANA_API_KEY: "
        f"{'present' if api_key_present else 'missing'}"
    )


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
            payload = build_config_payload()
            body = json.dumps(payload).encode("utf-8")
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
    global CONFIG_PATH
    global CONFIG_BUILD
    CONFIG_BUILD = build_id
    payload = build_config_payload()
    try:
        with open(config_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
        with open(config_path, "rb") as handle:
            config_size = len(handle.read())
        print(f"config.json size: {config_size} bytes")
        CONFIG_PATH = config_path
    except OSError as exc:
        print(
            "Warning: failed to write config.json "
            f"(attempted: {config_path}): {exc}"
        )
        CONFIG_PATH = None
    print(f"Resolved config dir: {config_dir} (cwd: {os.getcwd()})")
    log_config_presence()
    handler = functools.partial(WebAppHandler, directory=directory)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"Listening on 0.0.0.0:{port}, serving {directory}")
    server.serve_forever()


if __name__ == "__main__":
    main()
