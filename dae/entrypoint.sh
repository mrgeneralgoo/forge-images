#!/bin/sh
# dae + auto-update entrypoint.
#
# Runs the dae daemon in the foreground (its exit is the container's exit, so a
# restart policy restarts the proxy) and drives the rule/GeoData update loop in
# the background: a startup catch-up refresh followed by busybox crond. The
# daemon and the updater share one container, one PID namespace and one
# /var/run, so `dae reload` reaches the daemon directly — no host scheduler, no
# Docker socket, no shared volumes.
set -eu

log() { printf '[dae-entry] %s\n' "$*"; }

: "${DAE_RUNTIME:=/etc/dae}"
: "${DAE_RULE_MANIFEST:=/config/rule-providers.json}"
: "${DAE_CURL:=curl}"
export DAE_OPS_LOCAL=1 DAE_RUNTIME DAE_RULE_MANIFEST DAE_CURL
export PATH=/usr/local/bin:/usr/bin:/bin

# crond runs jobs with a minimal environment of its own, so snapshot the update
# env here — where any `-e` runtime overrides are visible — for run-job.sh to
# source. This is what makes DAE_RULE_MANIFEST / DAE_GEO_BASE_URL overridable.
{
    printf 'export PATH=%s\n' "$PATH"
    printf 'export DAE_OPS_LOCAL=%s\n' "$DAE_OPS_LOCAL"
    printf 'export DAE_RUNTIME=%s\n' "$DAE_RUNTIME"
    printf 'export DAE_RULE_MANIFEST=%s\n' "$DAE_RULE_MANIFEST"
    printf 'export DAE_CURL=%s\n' "$DAE_CURL"
    if [ -n "${DAE_GEO_BASE_URL:-}" ]; then
        printf 'export DAE_GEO_BASE_URL=%s\n' "$DAE_GEO_BASE_URL"
    fi
} >/opt/dae/runtime-env

# Background updater: wait for the daemon's pidfile, run a startup catch-up
# (mirroring systemd Persistent=true), then hand off to crond.
(
    i=0
    while [ ! -f /var/run/dae.pid ]; do
        i=$((i + 1))
        if [ "$i" -ge 120 ]; then
            log 'dae pidfile absent after 120s; scheduled runs will retry'
            break
        fi
        sleep 1
    done
    log 'startup rule refresh'
    /usr/local/bin/run-job.sh rules --no-jitter || log 'startup rule refresh failed (will retry on schedule)'
    log 'startup geo refresh'
    /usr/local/bin/run-job.sh geo --no-jitter || log 'startup geo refresh failed (will retry on schedule)'
    log 'starting crond — rules daily 04:17, geo weekly Mon 04:07 (each +<=15m jitter)'
    exec crond -f -l 8
) &

log 'starting dae daemon'
exec dae run -c "$DAE_RUNTIME/config.dae"
