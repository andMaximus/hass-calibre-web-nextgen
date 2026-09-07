ARG BUILD_FROM
FROM ${BUILD_FROM}

# tzdata so a custom TZ option resolves. Options are parsed with the image's
# own python3 (no extra packages needed).
RUN \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update \
        && apt-get install -y --no-install-recommends tzdata \
        && rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache tzdata; \
    fi

COPY run.sh /ha-run.sh
RUN chmod a+x /ha-run.sh

# Translate add-on options to env vars the upstream image understands,
# then exec its own s6-overlay init (/init) as PID 1.
ENTRYPOINT ["/ha-run.sh"]
CMD []
