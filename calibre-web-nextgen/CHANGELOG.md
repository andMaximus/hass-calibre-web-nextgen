# Changelog

## 0.1.0

- Initial release.
- Wraps `ghcr.io/new-usemame/calibre-web-nextgen:latest` (amd64 + aarch64).
- Ingress on port 8083; optional host port 8083 for external device sync.
- Maps `share`, `media`, and `addon_config` (-> `/config`).
- Options: `puid`, `pgid`, `TZ`.

> Bumping this version and rebuilding the add-on pulls the current upstream
> `:latest` image. Pin a specific upstream tag in `build.yaml` if you want
> reproducible builds.
