#!/usr/bin/env bash
# Entrypoint shim: map Home Assistant add-on options -> env vars for the
# upstream LinuxServer-style image, then hand off to its s6-overlay init.
set -eu

# python3 is always present (calibre-web is a python app) - no extra deps.
eval "$(python3 - <<'PY'
import json
try:
    o = json.load(open("/data/options.json"))
except Exception:
    o = {}
print("export PUID=%d" % int(o.get("puid") or 1000))
print("export PGID=%d" % int(o.get("pgid") or 1000))
tz = str(o.get("TZ") or "").strip()
if tz and all(c.isalnum() or c in "/_+-" for c in tz):
    print("export TZ=%s" % tz)
PY
)"

echo "[calibre-web-nextgen] PUID=${PUID} PGID=${PGID} TZ=${TZ:-<system>}"
echo "[calibre-web-nextgen] starting upstream init (/init)"

exec /init
