#!/bin/sh
# proxy-dae/update-rules.sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
: "${DAE_RUNTIME:=$ROOT/runtime}"
: "${DAE_CURL:=curl}"
: "${DAE_RULE_MANIFEST:=$ROOT/rule-providers.json}"
export DAE_ROOT="$ROOT" DAE_RUNTIME
# shellcheck disable=SC1091
. "$ROOT/lib/dae-ops.sh"

lock="$ROOT/.update-rules.lock"
if ! mkdir "$lock" 2>/dev/null; then
    dae_ops_die 'rule update already running'
fi
trap 'rm -rf "$lock"' EXIT INT TERM
tmp=$(mktemp -d "$ROOT/.rules.XXXXXX")
trap 'rm -rf "$tmp" "$lock"' EXIT INT TERM

python3 - "$DAE_RULE_MANIFEST" >"$tmp/sources.tsv" <<'PY'
import json
import sys
for item in json.load(open(sys.argv[1]))["providers"]:
    print(f"{item['name']}\t{item['url']}")
PY

while IFS="$(printf '\t')" read -r name url; do
    [ -n "$name" ] || continue
    "$DAE_CURL" -fsSL --retry 3 --retry-delay 5 \
        -o "$tmp/$name.yaml" "$url"
done <"$tmp/sources.tsv"

python3 "$ROOT/convert-rules.py" \
    --manifest "$DAE_RULE_MANIFEST" \
    --source-dir "$tmp" \
    --output "$tmp/rules.generated.dae"

if [ -f "$DAE_RUNTIME/rules.generated.dae" ] && \
    cmp -s "$tmp/rules.generated.dae" "$DAE_RUNTIME/rules.generated.dae"; then
    dae_ops_log 'rules unchanged; reload skipped'
    exit 0
fi

dae_install_candidate rules.generated.dae "$tmp/rules.generated.dae" yes
dae_ops_log 'rules installed and dae reloaded'
