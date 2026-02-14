import functools
import hashlib
import json
import os
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

NO_STORE_FILES = {
    "index.html",
    "config.json",
    "flutter_service_worker.js",
}

LONG_CACHE_EXTENSIONS = {
    ".js",
    ".css",
    ".wasm",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".svg",
    ".ico",
    ".webp",
    ".json",
    ".ttf",
    ".otf",
    ".woff",
    ".woff2",
    ".map",
}


def _is_client_disconnect(exc: BaseException) -> bool:
    if isinstance(exc, (BrokenPipeError, ConnectionResetError, ConnectionAbortedError)):
        return True
    if isinstance(exc, OSError):
        return exc.errno in {32, 54, 104}
    return False


def _read_env(*keys: str) -> str:
    for key in keys:
        value = os.environ.get(key)
        if value is not None and value.strip():
            return value.strip()
    return ""


def build_config_payload() -> dict[str, str]:
    api_base_url = _read_env("API_BASE_URL", "BASE_URL")
    assets_base_url = _read_env("ASSETS_BASE_URL")
    app_version = _read_env("APP_VERSION")
    if not assets_base_url:
        assets_base_url = "https://cdn.basilarcana.com"
    payload: dict[str, str] = {
        "apiBaseUrl": api_base_url,
        "assetsBaseUrl": assets_base_url,
        "appVersion": app_version,
    }
    return payload


def log_config_presence() -> None:
    api_base_url_present = bool(_read_env("API_BASE_URL", "BASE_URL"))
    assets_base_url_present = bool(_read_env("ASSETS_BASE_URL"))
    app_version_present = bool(_read_env("APP_VERSION"))
    print(
        "Config env presence - API_BASE_URL/BASE_URL: "
        f"{'present' if api_base_url_present else 'missing'}, "
        "ASSETS_BASE_URL: "
        f"{'present' if assets_base_url_present else 'missing'}, "
        "APP_VERSION: "
        f"{'present' if app_version_present else 'missing'}"
    )


class WebAppHandler(SimpleHTTPRequestHandler):
    app_version: str = ""
    _request_path: str = ""

    @classmethod
    def _effective_app_version(cls) -> str:
        return (cls.app_version or "dev").strip() or "dev"

    def _serve_index_html(self) -> None:
        file_path = self.translate_path("/index.html")
        if not os.path.isfile(file_path):
            self.send_error(404, "index.html not found")
            return
        try:
            with open(file_path, "r", encoding="utf-8") as handle:
                text = handle.read()
        except OSError:
            self.send_error(500, "Failed to read index.html")
            return

        version = self._effective_app_version()
        text = text.replace("{{BUILD_ID}}", version)
        text = text.replace("__BUILD_ID__", version)
        text = text.replace("{{flutter_service_worker_version}}", version)
        body = text.encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header(
            "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"
        )
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except Exception as exc:
            if _is_client_disconnect(exc):
                print("Client disconnected while writing index.html response.")
                return
            raise

    def _handle_video_range(self, file_path: str) -> bool:
        range_header = self.headers.get("Range")
        if not range_header:
            return False
        try:
            file_size = os.path.getsize(file_path)
        except OSError:
            return False
        match = re.match(r"bytes=(\d*)-(\d*)", range_header)
        if not match:
            return False
        start_str, end_str = match.groups()
        if not start_str and not end_str:
            return False
        if start_str:
            start = int(start_str)
            end = int(end_str) if end_str else file_size - 1
        else:
            suffix = int(end_str)
            start = max(file_size - suffix, 0)
            end = file_size - 1
        if start >= file_size or end < start:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{file_size}")
            self.end_headers()
            return True
        end = min(end, file_size - 1)
        length = end - start + 1
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(file_path))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
        self.send_header("Content-Length", str(length))
        self.end_headers()
        try:
            with open(file_path, "rb") as handle:
                handle.seek(start)
                self.wfile.write(handle.read(length))
        except Exception as exc:
            if _is_client_disconnect(exc):
                print("Client disconnected while streaming video range.")
                return True
            raise
        return True

    def do_GET(self):
        parsed = urlparse(self.path)
        self._request_path = parsed.path
        if parsed.path == "/" or parsed.path == "/index.html":
            self._serve_index_html()
            return
        if parsed.path == "/healthz":
            body = b"ok"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except Exception as exc:
                if _is_client_disconnect(exc):
                    print("Client disconnected while writing /healthz response.")
                else:
                    raise
            return
        if parsed.path == "/flutter_service_worker.js":
            body = b"service worker disabled"
            self.send_response(404)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except Exception as exc:
                if _is_client_disconnect(exc):
                    print(
                        "Client disconnected while writing /flutter_service_worker.js response."
                    )
                else:
                    raise
            return
        if parsed.path == "/config.json":
            payload = build_config_payload()
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header(
                "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"
            )
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except Exception as exc:
                if _is_client_disconnect(exc):
                    print("Client disconnected while writing /config.json response.")
                else:
                    raise
            return
        if parsed.path.endswith(".mp4"):
            file_path = self.translate_path(parsed.path)
            if os.path.isfile(file_path) and self._handle_video_range(file_path):
                return
        if not os.path.splitext(parsed.path)[1]:
            file_path = self.translate_path(parsed.path)
            if not os.path.isfile(file_path):
                self._serve_index_html()
                return
        try:
            super().do_GET()
        except Exception as exc:
            if _is_client_disconnect(exc):
                print("Client disconnected while serving static content.")
                return
            raise

    def end_headers(self):
        path = self._request_path or urlparse(self.path).path
        filename = os.path.basename(path)
        _, extension = os.path.splitext(filename)
        if path == "/" or path == "/config.json" or filename in NO_STORE_FILES:
            self.send_header(
                "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"
            )
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
        elif path.startswith("/assets/") or extension in LONG_CACHE_EXTENSIONS:
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        else:
            self.send_header("Cache-Control", "public, max-age=3600")
        if path.endswith(".mp4"):
            self.send_header("Accept-Ranges", "bytes")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    directory = os.environ.get("WEB_ROOT", "/app/static")
    app_version = _read_env("APP_VERSION")
    if not app_version:
        # Derive a stable version from built assets so cache-busting works even
        # when APP_VERSION is not configured. This value is identical across
        # replicas for the same image and changes when assets change.
        hasher = hashlib.sha1()
        has_data = False
        for filename in ("main.dart.js", "flutter_bootstrap.js", "index.html"):
            file_path = os.path.join(directory, filename)
            if not os.path.isfile(file_path):
                continue
            try:
                with open(file_path, "rb") as handle:
                    while True:
                        chunk = handle.read(1024 * 1024)
                        if not chunk:
                            break
                        hasher.update(chunk)
                        has_data = True
            except OSError:
                continue
        if has_data:
            app_version = f"build-{hasher.hexdigest()[:12]}"
        else:
            app_version = "dev"

    required_files = ("index.html", "manifest.json", "flutter.js", "main.dart.js")
    missing_files = [
        name
        for name in required_files
        if not os.path.isfile(os.path.join(directory, name))
    ]
    if missing_files:
        print(
            "Warning: missing static files in "
            f"{directory}: "
            f"{', '.join(missing_files)}"
        )
    else:
        print(
            "Static files present in "
            f"{directory}: "
            f"{', '.join(required_files)}"
        )
    log_config_presence()
    WebAppHandler.app_version = app_version
    handler = functools.partial(WebAppHandler, directory=directory)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(
        f"Listening on 0.0.0.0:{port}, serving {directory} "
        f"(app_version={app_version or 'none'})"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
