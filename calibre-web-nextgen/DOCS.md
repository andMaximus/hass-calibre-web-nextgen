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
4. Open the UI - the sidebar panel / "Open Web UI" (via the Ingress nginx shim),
   or directly at `http://<ha-ip>:8083`. Default login: `admin` / `admin123` -
   **change it immediately** under Profile -> Account.

Devices that sync from outside Home Assistant (Kobo, KOReader) must use the
direct `http://<ha-ip-or-tailnet-ip>:8083` URL, not the Ingress one.

## Options

| Option | Default | Notes |
|---|---|---|
| `PUID` | `0` | UID that owns config + library. `0` (root) is simplest with CIFS; `1000` for a local `/share` library |
| `PGID` | `0` | GID counterpart |
| `TZ` | *(blank)* | Blank = inherit HA system timezone |
| `library` | *(blank)* | Path to the folder holding your `metadata.db`, e.g. `/mnt/Books` or `/share/books/calibre`. Bound to `/calibre-library` where CWA looks. Blank = CWA auto-detects or creates one |
| `ingest` | *(blank)* | Optional auto-import drop folder. Files placed here are converted and added to the library, then deleted. Bound to `/cwa-book-ingest`. Blank = feature unused |
| `networkdisks` | *(blank)* | SMB/CIFS share(s) to mount, e.g. `//192.168.2.223/Media/Books`. Comma-separate for several |
| `cifsusername` / `cifspassword` / `cifsdomain` | *(blank)* | SMB credentials (password: any characters OK, passed via a creds file) |
| `nfsdisks` | *(blank)* | NFS share(s), `host:/export` e.g. `192.168.2.223:/Media`. **Prefer this** when `metadata.db` is on the share |

### SMB vs NFS for the library

If `metadata.db` lives on the network share, **use NFS** (`nfsdisks`), not SMB.
CIFS byte-range locking is unreliable on most NAS SMB servers and makes SQLite
throw persistent "database is locked" (the add-on works around it with `nobrl`,
which then has no cross-writer safety). NFSv4 gives SQLite proper locking.

NAS side (NFS): export the folder over **NFSv4**, allow this Home Assistant
host's IP, read/write, **no root squash** (the add-on runs as root). Then set
`nfsdisks: <nas-ip>:/<export>` and point `library` / `ingest` at subpaths of the
resulting `/mnt/<export>` mount.

## Storage layout

| Container path | Mapped to | Use |
|---|---|---|
| `/config` | add-on config dir | `app.db`, users, settings, logs, KOReader sync state |
| `/share` | HA `share` | local Calibre library / ingest folder |
| `/media` | HA `media` | alternative library / ingest location |
| `/mnt/<share>` | mounted SMB/NFS share | each `networkdisks` / `nfsdisks` entry mounts at `/mnt/<last-path-segment>` |
| `/calibre-library` | `library` option | where CWA reads the library |
| `/cwa-book-ingest` | `ingest` option | auto-import drop folder |

**Setting the library:** CWA/NextGen deliberately disables the "Location of
Calibre database" field in the UI - it only looks in `/calibre-library`. Use the
**`library` add-on option** instead: set it to the folder that contains your
`metadata.db` (`/mnt/Books`, `/share/books/calibre`, ...). The add-on bind-mounts
that to `/calibre-library` and CWA auto-detects the existing library on start
(it searches subfolders too). Leave `library` blank to let CWA create an empty
one. If CWA logs "not a Calibre database", the path is pointing one level too
high or low - fix `library` and restart.

**Auto-import (optional):** set the `ingest` option to a folder (under `/share`,
`/media` or `/mnt/<share>`). Anything dropped there is converted (to kepub etc.)
and added to the library, then removed. This is also the safe way to add books
once NextGen owns the library - it keeps NextGen the only writer of
`metadata.db`, unlike running `calibredb add` against the share directly.

### SMB/CIFS mount details

The mount happens at container start (before the app), tries SMB dialects
`3.1.1 -> 3.0 -> 2.1 -> 1.0` and retries once with `noserverino`. Mounts appear
in the log as `[cwng] mounted ... -> /mnt/...`; a failure logs `[cwng] ERROR` and
the raw `mount.cifs` message, and the add-on still starts so you can read the log.
Mounting needs the `SYS_ADMIN` capability. AppArmor stays **enabled** with a
custom profile (`apparmor.txt`) that permits `mount` but still confines the rest
- so the add-on keeps a reasonable security rating rather than the lower one that
disabling AppArmor would give.

The `networkdisks` / `cifsusername` / `cifspassword` / `PUID` / `PGID` options
match the alexbelgium calibre-web add-on's, and it also mounts at `/mnt/<name>` -
so switching over is mostly copying those values across. Point `library` at your
existing library folder and NextGen picks it up. Start fresh on `app.db` (users,
shelves): re-creating a user takes a minute and avoids SQLite corruption from a
half-copied database.

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
- The add-on version tracks upstream NextGen 1:1 and is bumped automatically by a
  scheduled GitHub workflow when NextGen cuts a release - Home Assistant then
  offers it as a normal add-on update.
- SQLite over SMB: `metadata.db` lives on your share. Keep NextGen the only thing
  writing it (use the `ingest` folder, not `calibredb` from another machine).
