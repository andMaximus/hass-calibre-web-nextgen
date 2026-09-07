# Calibre-Web-NextGen — Home Assistant add-on

A Home Assistant add-on that runs
[Calibre-Web-NextGen](https://github.com/new-usemame/Calibre-Web-NextGen), the
actively-maintained community continuation of Calibre-Web-Automated.

There is no official HA add-on for CWA / NextGen — this is a thin local wrapper
(`Dockerfile` = `FROM ghcr.io/new-usemame/calibre-web-nextgen:<pinned>` + a small
shim that maps options to env vars and mounts optional SMB/NFS shares). Supervisor
builds it on install; no registry account needed.

## What you get over plain calibre-web

- Kobo Sync
- **KOReader kosync server** — sync reading position across KOReader devices
- **Hardcover sync** — status + progress + dates + annotations, one toggle,
  fed by both Kobo Sync and kosync
- bundled Calibre binaries (auto-ingest, conversion, metadata enforcement)
- optional **SMB/CIFS or NFS library mounting** (`nfsdisks` / `networkdisks`)

## Versioning & updates

The add-on `version:` tracks upstream 1:1 — `4.1.43` = NextGen `v4.1.43`, pinned
in the Dockerfile. A scheduled workflow
([`.github/workflows/upstream-sync.yml`](.github/workflows/upstream-sync.yml))
checks for new NextGen releases every 6 h and, when there's one, bumps the pin +
`version:` + changelog and pushes. Home Assistant then shows an **Update** for the
add-on like any other; clicking it rebuilds against the new pinned image.

## Add to Home Assistant

**Settings → Add-ons → Add-on Store → ⋮ (top-right) → Repositories**, paste:

```
https://github.com/andMaximus/hass-calibre-web-nextgen
```

then install **Calibre-Web-NextGen**. Full setup, storage layout, migration from
an existing calibre-web/CWA add-on, and Kobo / KOReader / Hardcover wiring are in
[`calibre-web-nextgen/DOCS.md`](calibre-web-nextgen/DOCS.md).

## Supported architectures

`amd64`, `aarch64`. The upstream image has no armv7 build.

## Licence

Wrapper: MIT. Upstream Calibre-Web-NextGen: GPL-3.0.
