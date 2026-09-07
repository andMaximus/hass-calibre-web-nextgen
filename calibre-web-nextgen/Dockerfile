# Thin wrapper over the upstream multi-arch image (amd64 + arm64). The pinned tag
# below is bumped automatically by .github/workflows/upstream-sync.yml whenever
# Calibre-Web-NextGen cuts a release; the add-on `version:` tracks it 1:1.
# Docker resolves the right platform from the multi-arch manifest.
ARG BUILD_FROM="ghcr.io/new-usemame/calibre-web-nextgen:v4.1.43"
FROM ${BUILD_FROM}

# cifs-utils / nfs-common: mount the library from an SMB or NFS share (optional).
# nginx: translate HA Ingress' X-Ingress-Path into the X-Script-Name /
#        X-Forwarded-Prefix headers calibre-web understands.
# tzdata: resolve a custom TZ option.
# Options themselves are parsed with the image's own python3 (no extra deps).
RUN \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update \
        && apt-get install -y --no-install-recommends cifs-utils nfs-common nginx-light tzdata \
        && rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache cifs-utils nfs-utils nginx tzdata; \
    fi

COPY nginx-ingress.conf /etc/nginx-ingress.conf
COPY run.sh /ha-run.sh
RUN chmod a+x /ha-run.sh

LABEL \
    org.opencontainers.image.title="Calibre-Web-NextGen (Home Assistant add-on)" \
    org.opencontainers.image.description="HA add-on wrapper around ghcr.io/new-usemame/calibre-web-nextgen" \
    org.opencontainers.image.source="https://github.com/andMaximus/hass-calibre-web-nextgen" \
    org.opencontainers.image.licenses="GPL-3.0-only"

# Translate add-on options to env vars, mount any configured SMB shares, start
# the Ingress nginx shim, then exec the upstream s6-overlay init (/init) as PID 1.
ENTRYPOINT ["/ha-run.sh"]
CMD []
