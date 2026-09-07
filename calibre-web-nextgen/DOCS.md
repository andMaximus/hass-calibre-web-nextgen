# Calibre-Web-NextGen

Home Assistant add-on wrapper around
[`ghcr.io/new-usemame/calibre-web-nextgen`](https://github.com/new-usemame/Calibre-Web-NextGen)
- the actively-maintained community continuation of Calibre-Web-Automated.

Why this instead of plain calibre-web:

- **Kobo Sync** (as before)
- **KOReader kosync server** built in - sync reading position across KOReader
  devices (Kindle, Android, Kobo-with-KOReader, XTeink + CrossPoint, ...)
- **Hardcover sync** - one toggle pushes reading status + progress + dates +
  annotations to hardcover.app, fed by both Kobo Sync and kosync
- bundled Calibre binaries (auto-ingest, conversion, metadata enforcement)

## Install

1. Add this repository to Home Assistant:
   Settings -> Add-ons -> Add-on Store -> (top-right) Repositories ->
   `https://github.com/andMaximus/hass-calibre-web-nextgen`
2. Install **Calibre-Web-NextGen**. Supervisor builds a thin wrapper over the
   upstream image (fast; needs internet + a little disk).
3. Set options (see below), Start, open the log to confirm it came up.
4. Open the UI (sidebar or `http://<ha>:8083`). Default login: `admin` /
   `admin123` - **change it immediately** under Profile -> Account.

## Options

| Option | Default | Notes |
|---|---|---|
| `PUID` | `0` | UID that owns config + library. `0` (root) is simplest with CIFS; `1000` for a local `/share` library |
| `PGID` | `0` | GID counterpart |
| `TZ` | *(blank)* | Blank = inherit HA system timezone |
| `networkdisks` | *(blank)* | SMB/CIFS share(s) to mount, e.g. `//192.168.2.223/Media/Books`. Comma-separate for several. Leave blank to skip |
| `cifsusername` | *(blank)* | SMB username |
| `cifspassword` | *(blank)* | SMB password (any characters OK - passed via a creds file, not the command line) |
| `cifsdomain` | *(blank)* | SMB workgroup/domain (optional) |

## Storage layout

| Container path | Mapped to | Use |
|---|---|---|
| `/config` | add-on config dir | `app.db`, users, settings, logs, KOReader sync state |
| `/share` | HA `share` | local Calibre library, e.g. `/share/books/calibre` |
| `/media` | HA `media` | alternative library / ingest location |
| `/mnt/<share>` | mounted SMB share | each `networkdisks` entry mounts at `/mnt/<last-path-segment>` |

On first run set **Admin -> Basic Configuration -> Location of Calibre database**
to wherever `metadata.db` lives - e.g. `/mnt/Books` for the CIFS example above,
or `/share/books/calibre` for a local library. If you have none, NextGen creates
an empty one there.

Book auto-ingest watches `/cwa-book-ingest` inside the container. To feed it from
a share, set the ingest path in the UI to a folder under `/share`, `/media` or
`/mnt/<share>`.

### SMB/CIFS mount details

The mount happens at container start (before the app), tries SMB dialects
`3.1.1 -> 3.0 -> 2.1 -> 1.0` and retries once with `noserverino`. Mounts appear
in the log as `[cwng] mounted ... -> /mnt/...`; a failure logs `[cwng] ERROR` and
the raw `mount.cifs` message, and the add-on still starts so you can read the log.
Mounting needs the `SYS_ADMIN` capability. AppArmor stays **enabled** with a
custom profile (`apparmor.txt`) that permits `mount` but still confines the rest
- so the add-on keeps a reasonable security rating rather than the lower one that
disabling AppArmor would give.

Migrating from the alexbelgium calibre-web add-on: the `networkdisks` /
`cifsusername` / `cifspassword` / `PUID` / `PGID` options carry over as-is (it
also mounts at `/mnt/<name>`).

## Migrating from an existing calibre-web / CWA add-on

`app.db` is compatible along the whole calibre-web -> CWA -> NextGen line.

1. **Back up** your current add-on's config dir (the folder holding `app.db`).
2. Stop the old add-on.
3. Copy its `app.db` (and `.calibre-web.log`, `gdrive*` if used) into this
   add-on's `/config` dir (`/addon_configs/<slug>_calibre_web_nextgen/`).
4. Start this add-on. It runs its migrations on first boot. Verify users, shelves
   and the library show up.
5. Only run one of them at a time - both writing the same `app.db` or the same
   Calibre library will corrupt state / hit "database is locked".

## Kobo

Kobo Sync URL structure is unchanged, but the per-user **sync token** must be
regenerated in NextGen (Admin -> Users -> the user) and the Kobo's
`api_endpoint` (in `.kobo/Kobo/Kobo eReader.conf`, `[OneStoreServices]`)
re-pointed at:

```
http://<ha-or-tailnet-ip>:8083/kobo/<new-token>
```

## KOReader

In KOReader: **Tools -> Progress sync -> Custom sync server** =
`http://<ha-or-tailnet-ip>:8083` (NextGen serves the kosync API at the root).
Register / login with a KOReader-sync account created in NextGen, then enable
sync per book or globally.

## Hardcover

Admin -> Basic Configuration -> **Enable Hardcover Sync**. Add a Hardcover API
token (get one at <https://hardcover.app/account/api>) either server-wide there
or per-user under Profile. This single switch drives both the scheduled
Hardcover-ID backfill and the Kobo/KOReader progress -> Hardcover sync.

## Notes

- Upstream image is **amd64 / aarch64 only** - not armv7.
- The add-on rebuilds against upstream `:latest` whenever you reinstall or bump
  its version. Pin a tag in `build.yaml` for reproducibility.
