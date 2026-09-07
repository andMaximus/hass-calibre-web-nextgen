ARG BUILD_FROM
FROM ${BUILD_FROM}

# cifs-utils: mount the library from an SMB/CIFS share (optional feature).
# nginx: translate HA Ingress' X-Ingress-Path into the X-Script-Name /
#        X-Forwarded-Prefix headers calibre-web understands.
# tzdata: resolve a custom TZ option.
# Options themselves are parsed with the image's own python3 (no extra deps).
RUN \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update \
        && apt-get install -y --no-install-recommends cifs-utils nginx-light tzdata \
        && rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache cifs-utils nginx tzdata; \
    fi

COPY nginx-ingress.conf /etc/nginx-ingress.conf
COPY run.sh /ha-run.sh
RUN chmod a+x /ha-run.sh

# Translate add-on options to env vars, mount any configured SMB shares, start
# the Ingress nginx shim, then exec the upstream s6-overlay init (/init) as PID 1.
ENTRYPOINT ["/ha-run.sh"]
CMD []
