ARG BUILD_FROM
FROM ${BUILD_FROM}

# cifs-utils: mount the library from an SMB/CIFS share (optional feature).
# tzdata: resolve a custom TZ option.
# Options themselves are parsed with the image's own python3 (no extra deps).
RUN \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update \
        && apt-get install -y --no-install-recommends cifs-utils tzdata \
        && rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache cifs-utils tzdata; \
    fi

COPY run.sh /ha-run.sh
RUN chmod a+x /ha-run.sh

# Translate add-on options to env vars, mount any configured SMB shares,
# then exec the upstream s6-overlay init (/init) as PID 1.
ENTRYPOINT ["/ha-run.sh"]
CMD []
