#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build/web}"
APP_VERSION="${2:-${APP_VERSION:-}}"

if [[ -z "${APP_VERSION}" ]]; then
  echo "APP_VERSION is required" >&2
  exit 1
fi

INDEX_HTML="${BUILD_DIR}/index.html"
BOOTSTRAP_JS="${BUILD_DIR}/flutter_bootstrap.js"

if [[ ! -f "${INDEX_HTML}" ]]; then
  echo "Missing ${INDEX_HTML}" >&2
  exit 1
fi

python3 - <<'PY' "${INDEX_HTML}" "${APP_VERSION}"
from pathlib import Path
import re
import sys

index_path = Path(sys.argv[1])
app_version = sys.argv[2]
text = index_path.read_text(encoding='utf-8')

text = text.replace("{{BUILD_ID}}", app_version)
text = text.replace("__BUILD_ID__", app_version)
text = text.replace("{{flutter_service_worker_version}}", app_version)

def ensure_versioned(content: str, asset: str, version: str) -> str:
    pattern = rf"{re.escape(asset)}(?!\?v=)"
    return re.sub(pattern, f"{asset}?v={version}", content)

for asset_name in (
    "main.dart.js",
    "flutter.js",
    "flutter_bootstrap.js",
    "telegram_bridge.js",
    "config.json",
):
    text = ensure_versioned(text, asset_name, app_version)

index_path.write_text(text, encoding='utf-8')
PY

if [[ -f "${BOOTSTRAP_JS}" ]]; then
  python3 - <<'PY' "${BOOTSTRAP_JS}" "${APP_VERSION}"
from pathlib import Path
import re
import sys

bootstrap_path = Path(sys.argv[1])
app_version = sys.argv[2]
text = bootstrap_path.read_text(encoding='utf-8')

text = text.replace("{{flutter_service_worker_version}}", app_version)
text = re.sub(r"(const|var) serviceWorkerVersion = null", r"\1 serviceWorkerVersion = \"%s\"" % app_version, text)
text = re.sub(r"main\.dart\.js(?!\?v=)", f"main.dart.js?v={app_version}", text)

bootstrap_path.write_text(text, encoding='utf-8')
PY
fi

echo "Patched web build version to ${APP_VERSION} in ${BUILD_DIR}"
