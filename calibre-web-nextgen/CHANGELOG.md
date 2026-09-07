# Changelog

The add-on version now tracks upstream Calibre-Web-NextGen 1:1 (e.g. `4.1.43` =
NextGen `v4.1.43`). `.github/workflows/upstream-sync.yml` bumps it automatically
on every upstream release, so Home Assistant shows an update. History below the
switch is the wrapper's own `0.x` line.

## 4.1.43.1

- Ingest watcher: set `NETWORK_SHARE_MODE=true` automatically when an NFS or
  SMB share is configured, so NextGen polls the ingest folder instead of using
  inotify. inotify does not see files written to a network mount by another
  host (e.g. a script dropping epubs in over SMB), so those were never ingested.

## 4.1.43

- Version scheme switched to track upstream. Pinned to
  [`v4.1.43`](https://github.com/new-usemame/Calibre-Web-NextGen/releases/tag/v4.1.43);
  auto-bumped from here on.


## 0.8.1

- NFS mount: use `vers=4` (auto-negotiate the v4 minor) instead of a hardcoded
  4.2->4.1->4.0 ladder. Tested end-to-end against a QNAP NFSv4.1 export:
  mount + SQLite write-lock + integrity_check all pass.

## 0.8.0

- Add `nfsdisks` option + `nfs-common` in the image. NFSv4 gives SQLite
  reliable file locking, unlike CIFS - use it when `metadata.db` is on the
  share. Mount tries vers 4.2 -> 4.1 -> 4.0, warns on a v3 fallback.
- DOCS: SMB-vs-NFS guidance for a network library.

## 0.7.1

- CIFS mounts now use `nobrl` - the NAS's SMB byte-range locking made SQLite
  (`metadata.db`) throw persistent "database is locked" (kepub_package_repair,
  KOReader checksum tables). Standard SQLite-on-CIFS fix; safe while the add-on
  is the only writer of the library.

## 0.7.0

- Add an optional `ingest` option: bind-mounts a drop folder to
  `/cwa-book-ingest` for CWA auto-import.
- DOCS: drop the app.db-migration section (start fresh instead - a half-copied
  SQLite db corrupts); note SQLite-over-SMB single-writer caveat.

## 0.6.0

- Add a `library` option: bind-mounts the folder holding your `metadata.db` to
  `/calibre-library` so CWA auto-detects an existing library (its "Location of
  Calibre database" UI field is disabled by design). Verified: bind + detection.

## 0.5.0

- Drop `build.yaml` (Supervisor deprecated it). `BUILD_FROM` is now an `ARG`
  default in the Dockerfile; labels moved to `LABEL` instructions.
- `map` type `addon_config` -> `app_config` (Supervisor renamed it). Same
  `/config` mount, same data - no migration needed.

## 0.4.2

- Icon: rounded corners (transparent) + sharpened.

## 0.4.1

- Add `icon.png` (NextGen app icon) and `logo.png` (NextGen banner) for the
  add-on store.
- Fuller store description; `stage: stable`.

## 0.4.0

- Fix Ingress 404: add an in-container nginx shim (`nginx-light`) on port 8099
  that maps HA's `X-Ingress-Path` to the `X-Script-Name` / `X-Forwarded-Prefix`
  headers calibre-web needs, so the "Open Web UI" button and sidebar panel work
  under the dynamic ingress subpath. Verified: redirects and static asset URLs
  come back correctly prefixed. The mapped host port 8083 still serves
  calibre-web directly (needed for Kobo / KOReader sync from outside HA).

## 0.3.1

- Fix: `apparmor` config key must be a boolean, not a profile name (Supervisor
  rejected 0.3.0 with "expected boolean"). `apparmor.txt` is auto-loaded by its
  filename; the key just toggles it. Now `apparmor: true`.

## 0.3.0

- Ship a custom AppArmor profile (`apparmor.txt`) instead of `apparmor: false`.
  It permits `mount` (for the CIFS share) but keeps AppArmor enabled and
  confining everything else - restores the security rating that disabling
  AppArmor had cost. `SYS_ADMIN` is still required and can't be dropped.

## 0.2.0

- Optional SMB/CIFS library mounting: `networkdisks`, `cifsusername`,
  `cifspassword`, `cifsdomain` options. Shares mount at `/mnt/<name>` with an
  SMB-dialect + `noserverino` retry ladder. Carries over from the alexbelgium
  calibre-web add-on's options.
- Adds `cifs-utils` to the image; `privileged: [SYS_ADMIN, DAC_READ_SEARCH]`,
  `apparmor: false` (needed for `mount`).
- Options renamed `puid`/`pgid` -> `PUID`/`PGID`; defaults now `0` (root), to
  match a CIFS-backed library and the alexbelgium add-on.

## 0.1.0

- Initial release.
- Wraps `ghcr.io/new-usemame/calibre-web-nextgen:latest` (amd64 + aarch64).
- Ingress on port 8083; optional host port 8083 for external device sync.
- Maps `share`, `media`, and `addon_config` (-> `/config`).
- Options: `puid`, `pgid`, `TZ`.

> Bumping this version and rebuilding the add-on pulls the current upstream
> `:latest` image. Pin a specific upstream tag in `build.yaml` if you want
> reproducible builds.
