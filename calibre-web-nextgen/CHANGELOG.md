# Changelog

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
