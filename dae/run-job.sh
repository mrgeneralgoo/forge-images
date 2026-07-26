#!/bin/sh
# Update-job wrapper invoked by both the startup catch-up and crond.
#
#   run-job.sh rules|geo [--no-jitter]
#
# Sources the env snapshot written by entrypoint.sh (crond jobs otherwise get a
# bare environment), skips rule updates when no manifest is mounted, applies a
# bounded random jitter (mirroring systemd RandomizedDelaySec=15m) unless
# --no-jitter, then runs the requested update script in local (in-container)
# mode.
set -eu

# shellcheck disable=SC1091
[ -f /opt/dae/runtime-env ] && . /opt/dae/runtime-env
export PATH="${PATH:-/usr/local/bin:/usr/bin:/bin}"

jitter=1
what=
for arg in "$@"; do
    case "$arg" in
        --no-jitter) jitter=0 ;;
        rules | geo) what=$arg ;;
        *)
            printf 'usage: run-job.sh rules|geo [--no-jitter]\n' >&2
            exit 2
            ;;
    esac
done
[ -n "$what" ] || {
    printf 'usage: run-job.sh rules|geo [--no-jitter]\n' >&2
    exit 2
}

manifest=${DAE_RULE_MANIFEST:-/config/rule-providers.json}
if [ "$what" = rules ] && [ ! -f "$manifest" ]; then
    printf '[run-job] no rule manifest at %s; skipping rule update\n' "$manifest"
    exit 0
fi

if [ "$jitter" = 1 ]; then
    # Up to 900s (15m) of jitter from the kernel CSPRNG; two bytes are enough.
    j=$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')
    sleep "$((j % 901))"
fi

case "$what" in
    rules) exec sh /opt/dae/update-rules.sh ;;
    geo) exec sh /opt/dae/update-geo.sh ;;
esac
