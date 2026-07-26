#!/bin/sh
# Shared validated dae runtime operations.

: "${DAE_ROOT:=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
: "${DAE_RUNTIME:=$DAE_ROOT/runtime}"
: "${DAE_DOCKER:=docker}"
: "${DAE_CONTAINER:=dae}"
# DAE_OPS_LOCAL=1 runs validate/reload against a local `dae` binary in the same
# container/PID namespace as the daemon (used by the in-container dae-updater
# sidecar). Default 0 keeps the host/Docker path (docker run / docker exec)
# used by prepare-runtime.sh and deploy.sh.
: "${DAE_OPS_LOCAL:=0}"

dae_ops_log() { printf '[dae-ops] %s\n' "$*"; }
dae_ops_die() { printf '[dae-ops] ERROR: %s\n' "$*" >&2; exit 1; }

dae_ops_file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

dae_ops_require_mode_600() {
    [ -f "$1" ] || dae_ops_die "missing file: $1"
    [ "$(dae_ops_file_mode "$1")" = 600 ] || dae_ops_die "$1 must be mode 0600"
}

dae_image() (
    dae_ops_image=$("$DAE_DOCKER" compose -f "$DAE_ROOT/docker-compose.yml" config --images |
        awk '/^daeuniverse\/dae:/{print; exit}')
    [ -n "$dae_ops_image" ] || dae_ops_die 'cannot resolve pinned dae image from compose'
    printf '%s\n' "$dae_ops_image"
)

dae_validate_tree() (
    dae_ops_tree=$1
    [ -f "$dae_ops_tree/config.dae" ] || dae_ops_die "missing staged config: $dae_ops_tree/config.dae"
    if [ "$DAE_OPS_LOCAL" = 1 ]; then
        dae validate -c "$dae_ops_tree/config.dae"
    else
        "$DAE_DOCKER" run --rm --entrypoint dae \
            -v "$dae_ops_tree:/etc/dae:ro" "$(dae_image)" \
            validate -c /etc/dae/config.dae
    fi
)

dae_ops_stage_runtime() (
    dae_ops_stage=$1
    dae_ops_override_name=${2:-}
    dae_ops_override_path=${3:-}

    mkdir -p "$dae_ops_stage"
    for dae_ops_name in config.dae nodes.dae routing.pre.dae rules.generated.dae routing.post.dae; do
        if [ "$dae_ops_name" = "$dae_ops_override_name" ]; then
            cp "$dae_ops_override_path" "$dae_ops_stage/$dae_ops_name"
        else
            [ -f "$DAE_RUNTIME/$dae_ops_name" ] || dae_ops_die "missing runtime file: $dae_ops_name"
            cp "$DAE_RUNTIME/$dae_ops_name" "$dae_ops_stage/$dae_ops_name"
        fi
        chmod 600 "$dae_ops_stage/$dae_ops_name"
        dae_ops_require_mode_600 "$dae_ops_stage/$dae_ops_name"
    done

    for dae_ops_name in geoip.dat geosite.dat; do
        if [ -f "$DAE_RUNTIME/$dae_ops_name" ]; then
            cp "$DAE_RUNTIME/$dae_ops_name" "$dae_ops_stage/$dae_ops_name"
            chmod 600 "$dae_ops_stage/$dae_ops_name"
            dae_ops_require_mode_600 "$dae_ops_stage/$dae_ops_name"
        fi
    done
)

dae_ops_secure_runtime() (
    chmod 700 "$DAE_RUNTIME"
    for dae_ops_name in config.dae nodes.dae routing.pre.dae rules.generated.dae routing.post.dae; do
        if [ -f "$DAE_RUNTIME/$dae_ops_name" ]; then
            chmod 600 "$DAE_RUNTIME/$dae_ops_name"
            dae_ops_require_mode_600 "$DAE_RUNTIME/$dae_ops_name"
        fi
    done
)

dae_reload() (
    if [ "$DAE_OPS_LOCAL" = 1 ]; then
        # Local reload: reads /var/run/dae.pid, sends SIGUSR1, and polls
        # /var/run/dae.progress for completion. Requires the daemon's /var/run
        # to be shared with this container (see docker-compose.yml dae-run
        # volume) and a shared PID namespace so the signal reaches the daemon.
        dae_ops_output=$(dae reload 2>&1) || :
    else
        dae_ops_output=$(
            "$DAE_DOCKER" exec "$DAE_CONTAINER" dae reload 2>&1
        ) || :
    fi
    printf '%s\n' "$dae_ops_output"
    [ "$(printf '%s' "$dae_ops_output" | tr -d '[:space:]')" = OK ]
)

dae_install_candidate() (
    dae_ops_name=$1
    dae_ops_candidate=$2
    dae_ops_reload=${3:-no}
    [ -f "$dae_ops_candidate" ] || dae_ops_die "missing candidate: $dae_ops_candidate"

    mkdir -p "$DAE_RUNTIME" || return 1
    dae_ops_secure_runtime || return 1

    dae_ops_stage=$(mktemp -d "$DAE_ROOT/.validate.XXXXXX") || return 1
    trap 'rm -rf "$dae_ops_stage"' EXIT HUP INT TERM
    dae_ops_stage_runtime "$dae_ops_stage" "$dae_ops_name" "$dae_ops_candidate" || return 1
    dae_validate_tree "$dae_ops_stage" || return 1

    dae_ops_destination="$DAE_RUNTIME/$dae_ops_name"
    dae_ops_previous="$dae_ops_destination.previous"
    dae_ops_had_previous=no
    if [ -f "$dae_ops_destination" ]; then
        cp "$dae_ops_destination" "$dae_ops_previous" || return 1
        chmod 600 "$dae_ops_previous" || return 1
        dae_ops_had_previous=yes
    fi

    dae_ops_temporary="$dae_ops_destination.tmp.$$"
    cp "$dae_ops_candidate" "$dae_ops_temporary" || return 1
    chmod 600 "$dae_ops_temporary" || return 1
    mv "$dae_ops_temporary" "$dae_ops_destination" || return 1
    dae_ops_require_mode_600 "$dae_ops_destination"

    if [ "$dae_ops_reload" = yes ] && ! dae_reload; then
        dae_ops_log "reload failed; restoring $dae_ops_name"
        if [ "$dae_ops_had_previous" = yes ]; then
            mv "$dae_ops_previous" "$dae_ops_destination"
        else
            rm -f "$dae_ops_destination"
        fi
        dae_reload || dae_ops_log 'rollback reload also failed; operator action required'
        return 1
    fi
)
