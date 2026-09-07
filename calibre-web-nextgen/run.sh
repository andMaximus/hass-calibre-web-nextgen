#!/usr/bin/env bash
# Entrypoint shim:
#   1. map Home Assistant add-on options -> env vars for the upstream image
#   2. mount any configured SMB/CIFS shares under /mnt/<name>
#   3. hand off to the upstream s6-overlay init (/init) as PID 1
set -eu

OPT=/data/options.json

# --- options -> env --------------------------------------------------------
eval "$(python3 - <<'PY'
import json, shlex
try:
    o = json.load(open("/data/options.json"))
except Exception:
    o = {}
def sh(name, val):
    print("%s=%s" % (name, shlex.quote(str(val))))
sh("PUID", int(o.get("PUID", 0) or 0))
sh("PGID", int(o.get("PGID", 0) or 0))
tz = str(o.get("TZ") or "").strip()
if tz and all(c.isalnum() or c in "/_+-" for c in tz):
    sh("TZ", tz)
sh("_LIBRARY", str(o.get("library") or "").strip())
sh("_INGEST", str(o.get("ingest") or "").strip())
sh("_NETWORKDISKS", o.get("networkdisks") or "")
sh("_CIFS_USER", o.get("cifsusername") or "")
sh("_CIFS_PASS", o.get("cifspassword") or "")
sh("_CIFS_DOMAIN", o.get("cifsdomain") or "")
sh("_NFSDISKS", o.get("nfsdisks") or "")
PY
)"
export PUID PGID
[ -n "${TZ:-}" ] && export TZ || true

echo "[cwng] PUID=${PUID} PGID=${PGID} TZ=${TZ:-<system>}"

# --- SMB/CIFS mounts -----------------------------------------------------------
mount_cifs() {
    local spec="$1" mp="$2" cred="$3" base opts
    # nobrl: CIFS byte-range locks are unreliable on many NAS SMB servers and
    # make SQLite (metadata.db) throw spurious "database is locked". Disabling
    # them is the standard SQLite-on-CIFS workaround - safe as long as only this
    # add-on writes the library.
    base="credentials=${cred},uid=${PUID},gid=${PGID},file_mode=0664,dir_mode=0775,iocharset=utf8,nobrl"
    for extra in "vers=3.1.1" "vers=3.0" "vers=2.1" "vers=1.0" \
                 "vers=3.0,noserverino" "vers=2.1,noserverino,nounix"; do
        opts="${base},${extra}"
        if mount -t cifs -o "$opts" "$spec" "$mp" 2>/tmp/cifs.err; then
            echo "[cwng] mounted $spec -> $mp  ($extra)"
            return 0
        fi
    done
    echo "[cwng] ERROR: could not mount $spec -> $mp"
    sed 's/^/[cwng]   /' /tmp/cifs.err 2>/dev/null || true
    return 1
}

if [ -n "${_NETWORKDISKS}" ]; then
    CRED="$(mktemp /tmp/.cifscred.XXXXXX)"
    chmod 600 "$CRED"
    {
        printf 'username=%s\n' "${_CIFS_USER}"
        printf 'password=%s\n' "${_CIFS_PASS}"
        [ -n "${_CIFS_DOMAIN}" ] && printf 'domain=%s\n' "${_CIFS_DOMAIN}"
    } > "$CRED"

    OLDIFS="$IFS"; IFS=','
    for disk in ${_NETWORKDISKS}; do
        IFS="$OLDIFS"
        disk="$(echo "$disk" | sed 's#\\#/#g; s#^[[:space:]]*##; s#[[:space:]]*$##')"
        [ -z "$disk" ] && continue
        case "$disk" in //*) : ;; *) disk="//${disk#/}" ;; esac
        name="$(basename "$disk")"
        mp="/mnt/${name}"
        mkdir -p "$mp"
        mount_cifs "$disk" "$mp" "$CRED" || true
        IFS=','
    done
    IFS="$OLDIFS"
    rm -f "$CRED"
    echo "[cwng] SMB share(s) available under /mnt/"
fi

# --- NFS mounts --------------------------------------------------------------
# NFSv4 gives SQLite reliable file locking (unlike CIFS) - the right choice when
# metadata.db lives on the share. Format: host:/export  (comma-separate several).
mount_nfs() {
    local spec="$1" mp="$2" opts
    # vers=4 negotiates the highest NFSv4 minor both sides support (locking works).
    # vers=3,nolock is a last resort - SQLite locking will NOT work on it.
    for opts in "vers=4" "vers=3,nolock"; do
        if mount -t nfs -o "rw,hard,${opts}" "$spec" "$mp" 2>/tmp/nfs.err; then
            echo "[cwng] mounted $spec -> $mp  (nfs ${opts})"
            case "$opts" in vers=3*) echo "[cwng]   NOTE: fell back to NFSv3+nolock - SQLite locking will NOT work here; export NFSv4 on the NAS" ;; esac
            return 0
        fi
    done
    echo "[cwng] ERROR: could not mount $spec -> $mp"
    sed 's/^/[cwng]   /' /tmp/nfs.err 2>/dev/null || true
    return 1
}

if [ -n "${_NFSDISKS}" ]; then
    OLDIFS="$IFS"; IFS=','
    for disk in ${_NFSDISKS}; do
        IFS="$OLDIFS"
        disk="$(echo "$disk" | sed 's#^[[:space:]]*##; s#[[:space:]]*$##')"
        [ -z "$disk" ] && continue
        name="$(basename "$disk")"
        mp="/mnt/${name}"
        mkdir -p "$mp"
        mount_nfs "$disk" "$mp" || true
        IFS=','
    done
    IFS="$OLDIFS"
    echo "[cwng] NFS share(s) available under /mnt/"
fi

# --- library location ------------------------------------------------------
# CWA/NextGen disables the "Location of Calibre database" UI field and only
# looks in /calibre-library. Bind the chosen path there so it auto-detects
# an existing library (metadata.db). Empty -> leave the default in place.
if [ -n "${_LIBRARY}" ]; then
    if [ -d "${_LIBRARY}" ]; then
        mkdir -p /calibre-library
        if mount --bind "${_LIBRARY}" /calibre-library 2>/tmp/bind.err; then
            echo "[cwng] library: bound ${_LIBRARY} -> /calibre-library"
            [ -f /calibre-library/metadata.db ] \
                && echo "[cwng] library: found existing metadata.db" \
                || echo "[cwng] library: no metadata.db at the root (CWA will search subfolders / create one)"
        else
            echo "[cwng] WARN: bind mount of ${_LIBRARY} failed:"
            sed 's/^/[cwng]   /' /tmp/bind.err 2>/dev/null || true
        fi
    else
        echo "[cwng] WARN: library path '${_LIBRARY}' does not exist - check the SMB mount / path"
    fi
fi

# --- ingest drop folder --------------------------------------------------------
if [ -n "${_INGEST}" ]; then
    if [ -d "${_INGEST}" ]; then
        mkdir -p /cwa-book-ingest
        if mount --bind "${_INGEST}" /cwa-book-ingest 2>/tmp/bind.err; then
            echo "[cwng] ingest: bound ${_INGEST} -> /cwa-book-ingest"
        else
            echo "[cwng] WARN: bind mount of ${_INGEST} failed:"
            sed 's/^/[cwng]   /' /tmp/bind.err 2>/dev/null || true
        fi
    else
        echo "[cwng] WARN: ingest path '${_INGEST}' does not exist"
    fi
fi

# --- HA Ingress nginx shim ---------------------------------------------------
if command -v nginx >/dev/null 2>&1; then
    mkdir -p /var/lib/nginx /var/log/nginx
    if nginx -t -c /etc/nginx-ingress.conf 2>/tmp/nginx.err; then
        nginx -c /etc/nginx-ingress.conf
        echo "[cwng] Ingress nginx shim listening on :8099 -> :8083"
    else
        echo "[cwng] WARN: Ingress nginx config test failed - the Ingress UI"
        echo "[cwng]       may 404; the mapped host port 8083 still works."
        sed 's/^/[cwng]   /' /tmp/nginx.err 2>/dev/null || true
    fi
fi

echo "[cwng] starting upstream init (/init)"
exec /init
