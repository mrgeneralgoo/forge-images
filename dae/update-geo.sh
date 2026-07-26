#!/bin/sh
# proxy-dae/update-geo.sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
: "${DAE_RUNTIME:=$ROOT/runtime}"
: "${DAE_CURL:=curl}"
BASE=${DAE_GEO_BASE_URL:-https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download}
export DAE_ROOT="$ROOT" DAE_RUNTIME
# shellcheck disable=SC1091
. "$ROOT/lib/dae-ops.sh"

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

verify_checksum() {
    data=$1
    checksum=$2
    expected=$(awk 'NR == 1 {print $1}' "$checksum")
    actual=$(hash_file "$data")
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        dae_ops_die "checksum failed for $(basename "$data")"
    fi
}

lock="$ROOT/.update-geo.lock"
if ! mkdir "$lock" 2>/dev/null; then
    dae_ops_die 'GeoData update already running'
fi
trap 'rm -rf "$lock"' EXIT INT TERM
tmp=$(mktemp -d "$ROOT/.geo.XXXXXX")
stage=$(mktemp -d "$ROOT/.geo-validate.XXXXXX")
trap 'rm -rf "$tmp" "$stage" "$lock"' EXIT INT TERM

for name in geoip.dat geosite.dat; do
    "$DAE_CURL" -fsSL --retry 3 --retry-delay 5 -o "$tmp/$name" "$BASE/$name"
    "$DAE_CURL" -fsSL --retry 3 --retry-delay 5 -o "$tmp/$name.sha256sum" "$BASE/$name.sha256sum"
    verify_checksum "$tmp/$name" "$tmp/$name.sha256sum"
    chmod 600 "$tmp/$name"
done

dae_ops_stage_runtime "$stage"
cp "$tmp/geoip.dat" "$stage/geoip.dat"
cp "$tmp/geosite.dat" "$stage/geosite.dat"
chmod 600 "$stage/"*.dat
dae_validate_tree "$stage"

mkdir -p "$DAE_RUNTIME"
chmod 700 "$DAE_RUNTIME"
had_geoip=no
had_geosite=no
[ -f "$DAE_RUNTIME/geoip.dat" ] && had_geoip=yes
[ -f "$DAE_RUNTIME/geosite.dat" ] && had_geosite=yes
for name in geoip.dat geosite.dat; do
    if [ -f "$DAE_RUNTIME/$name" ]; then
        cp "$DAE_RUNTIME/$name" "$DAE_RUNTIME/$name.previous"
        chmod 600 "$DAE_RUNTIME/$name.previous"
    fi
    cp "$tmp/$name" "$DAE_RUNTIME/$name.tmp.$$"
    chmod 600 "$DAE_RUNTIME/$name.tmp.$$"
done
# NOTE: these two mv calls are not atomic as a pair; POSIX has no way to
# rename two files in a single transaction. The window is two adjacent
# syscalls with no fallible operation between them, and it self-heals: dae
# has not reloaded yet at this point, so a crash here still leaves the
# running dae using its previously-loaded geo data, and the next scheduled
# update-geo.sh run re-downloads and re-installs BOTH files. Both
# ".previous" backups also remain on disk for manual recovery.
mv "$DAE_RUNTIME/geoip.dat.tmp.$$" "$DAE_RUNTIME/geoip.dat"
mv "$DAE_RUNTIME/geosite.dat.tmp.$$" "$DAE_RUNTIME/geosite.dat"

if ! dae_reload; then
    for name in geoip.dat geosite.dat; do
        case "$name" in
            geoip.dat) had_previous=$had_geoip ;;
            geosite.dat) had_previous=$had_geosite ;;
        esac
        if [ "$had_previous" = yes ]; then
            mv "$DAE_RUNTIME/$name.previous" "$DAE_RUNTIME/$name"
        else
            rm -f "$DAE_RUNTIME/$name"
        fi
    done
    dae_reload || dae_ops_log 'GeoData rollback reload also failed; operator action required'
    exit 1
fi
dae_ops_log 'GeoData pair installed and dae reloaded'
