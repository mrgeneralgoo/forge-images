#!/usr/bin/env bash
set -Eeuo pipefail

script="${BASH_SOURCE[0]%/*}/reconcile-public-tags.sh"
history_script="${BASH_SOURCE[0]%/*}/reconcile-publication-history.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
backend="$fixture/imagetools"

cat > "$backend" <<'BACKEND'
#!/usr/bin/env bash
set -Eeuo pipefail
state=$FAKE_STATE
key() { printf '%s' "$1" | tr '/:@' '___'; }

case "$1" in
  inspect)
    ref=$2
    failure="$state/inspect-fail-$(key "$ref")"
    if [[ -f "$failure" ]]; then
      remaining=$(cat "$failure")
      if (( remaining > 0 )); then
        printf '%s\n' $((remaining - 1)) > "$failure"
        echo 'temporary registry failure' >&2
        exit 1
      fi
    fi
    if [[ "$ref" == *@sha256:* ]]; then
      digest=${ref##*@}
      file="$state/available-$(key "$ref")"
    else
      file="$state/tag-$(key "$ref")"
      [[ -f "$file" ]] && digest=$(cat "$file")
    fi
    if [[ ! -f "$file" ]]; then
      echo 'manifest unknown' >&2
      exit 1
    fi
    printf '{"digest":"%s"}\n' "$digest"
    ;;
  create)
    test "$2" = --tag
    target=$3
    source=$4
    failure="$state/fail-$(key "$target")"
    if [[ -f "$failure" ]]; then
      remaining=$(cat "$failure")
      if (( remaining > 0 )); then
        printf '%s\n' $((remaining - 1)) > "$failure"
        exit 1
      fi
    fi
    printf '%s\n' "${source##*@}" > "$state/tag-$(key "$target")"
    printf '%s\n' "$target" >> "$state/writes"
    ;;
  *) exit 2 ;;
esac
BACKEND
chmod +x "$backend"

sha=0123456789abcdef0123456789abcdef01234567
target=sha256:$(printf '%064d' 7)
other=sha256:$(printf '%064d' 8)
ghcr=ghcr.io/mrgeneralgoo/test
mirror=docker.io/mrgeneralgoo/test

key() { printf '%s' "$1" | tr '/:@' '___'; }
reset_fixture() { find "$fixture" -type f ! -path "$backend" -delete; }
make_available() {
  touch "$fixture/available-$(key "$ghcr@$1")"
  touch "$fixture/available-$(key "$mirror@$1")"
}
tag_digest() { cat "$fixture/tag-$(key "$1:$2")"; }
fail_writes() { printf '%s\n' "$2" > "$fixture/fail-$(key "$1")"; }
fail_inspects() { printf '%s\n' "$2" > "$fixture/inspect-fail-$(key "$1")"; }

run_reconcile() {
  local mode=${1:-target}
  local env_args=(
    FAKE_STATE="$fixture"
    RECONCILE_BACKEND="$backend"
    RECONCILE_ATTEMPTS="${ATTEMPTS:-1}"
    RECONCILE_INITIAL_DELAY_SECONDS=0
    GHCR_IMAGE="$ghcr"
    DOCKERHUB_IMAGE="$mirror"
    RELEASE_SHA="$sha"
    PROMOTE_LATEST=true
  )
  if [[ "$mode" != discover ]]; then
    env_args+=(TARGET_DIGEST="$target" MIRROR_DIGEST="$target")
  fi
  env "${env_args[@]}" "$script"
}

reset_fixture
make_available "$target"
fail_writes "$ghcr:sha-$sha" 1
if run_reconcile; then
  echo 'promotion unexpectedly succeeded' >&2
  exit 1
fi
test "$(tag_digest "$mirror" "sha-$sha")" = "$target"
test ! -e "$fixture/tag-$(key "$ghcr:sha-$sha")"

fail_writes "$ghcr:sha-$sha" 1
if run_reconcile; then
  echo 'first independent reconciliation unexpectedly succeeded' >&2
  exit 1
fi
run_reconcile
test "$(tag_digest "$mirror" "sha-$sha")" = "$target"
test "$(tag_digest "$ghcr" "sha-$sha")" = "$target"
test "$(tag_digest "$mirror" latest)" = "$target"
test "$(tag_digest "$ghcr" latest)" = "$target"

reset_fixture
make_available "$target"
fail_writes "$ghcr:sha-$sha" 2
ATTEMPTS=3 run_reconcile
test "$(tag_digest "$ghcr" latest)" = "$target"

reset_fixture
make_available "$target"
make_available "$other"
printf '%s\n' "$target" > "$fixture/tag-$(key "$ghcr:sha-$sha")"
printf '%s\n' "$other" > "$fixture/tag-$(key "$mirror:sha-$sha")"
run_reconcile discover
test "$(tag_digest "$mirror" "sha-$sha")" = "$target"
test "$(tag_digest "$ghcr" latest)" = "$target"

reset_fixture
make_available "$target"
printf '%s\n' "$target" > "$fixture/tag-$(key "$ghcr:sha-$sha")"
fail_inspects "$ghcr:sha-$sha" 2
if ATTEMPTS=2 run_reconcile discover; then
  echo 'discovery suppressed a persistent registry failure' >&2
  exit 1
fi
run_reconcile discover
test "$(tag_digest "$mirror" "sha-$sha")" = "$target"

reset_fixture
run_reconcile discover | grep -F 'nothing to reconcile' >/dev/null

reset_fixture
sha_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
sha_b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
sha_c=cccccccccccccccccccccccccccccccccccccccc
sha_d=dddddddddddddddddddddddddddddddddddddddd
digest_a=sha256:$(printf '%064d' 11)
digest_b=sha256:$(printf '%064d' 12)
digest_c=sha256:$(printf '%064d' 13)
for digest in "$digest_a" "$digest_b" "$digest_c"; do
  make_available "$digest"
done
shas_file="$fixture/shas"
printf '%s\n' "$sha_d" "$sha_c" "$sha_b" "$sha_a" > "$shas_file"
printf '%s\n' "$digest_a" > "$fixture/tag-$(key "$mirror:sha-$sha_a")"
printf '%s\n' "$digest_b" > "$fixture/tag-$(key "$ghcr:sha-$sha_b")"
printf '%s\n' "$digest_c" > "$fixture/tag-$(key "$mirror:sha-$sha_c")"
printf '%s\n' "$digest_c" > "$fixture/tag-$(key "$ghcr:sha-$sha_c")"

env \
  FAKE_STATE="$fixture" \
  RECONCILE_BACKEND="$backend" \
  RECONCILE_ATTEMPTS=1 \
  RECONCILE_INITIAL_DELAY_SECONDS=0 \
  RECONCILE_SHAS_FILE="$shas_file" \
  RECONCILE_MODE=sha \
  GHCR_IMAGE="$ghcr" \
  DOCKERHUB_IMAGE="$mirror" \
  "$history_script"
for item in "$sha_a:$digest_a" "$sha_b:$digest_b" "$sha_c:$digest_c"; do
  release_sha=${item%%:*}
  digest=sha256:${item##*:sha256:}
  test "$(tag_digest "$mirror" "sha-$release_sha")" = "$digest"
  test "$(tag_digest "$ghcr" "sha-$release_sha")" = "$digest"
done

env \
  FAKE_STATE="$fixture" \
  RECONCILE_BACKEND="$backend" \
  RECONCILE_ATTEMPTS=1 \
  RECONCILE_INITIAL_DELAY_SECONDS=0 \
  RECONCILE_SHAS_FILE="$shas_file" \
  RECONCILE_MODE=latest \
  GHCR_IMAGE="$ghcr" \
  DOCKERHUB_IMAGE="$mirror" \
  "$history_script"
test "$(tag_digest "$mirror" latest)" = "$digest_c"
test "$(tag_digest "$ghcr" latest)" = "$digest_c"

echo 'cross-registry reconciliation fixtures passed'
