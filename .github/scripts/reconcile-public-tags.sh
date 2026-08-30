#!/usr/bin/env bash
set -Eeuo pipefail

: "${GHCR_IMAGE:?GHCR_IMAGE is required}"
: "${DOCKERHUB_IMAGE:?DOCKERHUB_IMAGE is required}"
: "${RELEASE_SHA:?RELEASE_SHA is required}"

if ! [[ "$RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "RELEASE_SHA must be a full lowercase git commit" >&2
  exit 2
fi

attempts=${RECONCILE_ATTEMPTS:-5}
delay=${RECONCILE_INITIAL_DELAY_SECONDS:-15}
if ! [[ "$attempts" =~ ^[1-9][0-9]*$ && "$delay" =~ ^[0-9]+$ ]]; then
  echo "invalid retry configuration" >&2
  exit 2
fi

imagetools() {
  if [[ -n "${RECONCILE_BACKEND:-}" ]]; then
    "$RECONCILE_BACKEND" "$@"
  else
    docker buildx imagetools "$@"
  fi
}

inspect_digest() {
  imagetools inspect "$1" --format '{{json .Manifest}}' | jq -er .digest
}

valid_digest() {
  [[ "$1" =~ ^sha256:[0-9a-f]{64}$ ]]
}

inspect_optional_once() {
  local ref="$1" output="$2" error="$3"
  if inspect_digest "$ref" > "$output" 2> "$error"; then
    return 0
  fi
  if grep -Eqi 'manifest unknown|name unknown|unexpected status.*404|response status.*404' "$error"; then
    : > "$output"
    return 0
  fi
  return 1
}

inspect_optional() {
  local ref="$1" output error
  output=$(mktemp)
  error=$(mktemp)
  if retry inspect_optional_once "$ref" "$output" "$error"; then
    cat "$output"
    rm -f "$output" "$error"
    return 0
  fi
  cat "$error" >&2
  rm -f "$output" "$error"
  return 1
}

retry() {
  local attempt=1 current_delay=$delay
  until "$@"; do
    if (( attempt >= attempts )); then
      return 1
    fi
    sleep "$current_delay"
    attempt=$((attempt + 1))
    current_delay=$((current_delay * 2))
  done
}

ensure_reference_once() {
  local image="$1" tag="$2" digest="$3" current
  if current=$(inspect_digest "$image:$tag" 2>/dev/null) && [[ "$current" == "$digest" ]]; then
    return 0
  fi
  imagetools create --tag "$image:$tag" "$image@$digest"
  current=$(inspect_digest "$image:$tag")
  test "$current" = "$digest"
}

ensure_reference() {
  retry ensure_reference_once "$1" "$2" "$3"
}

digest_available_once() {
  local actual
  actual=$(inspect_digest "$1@$2")
  test "$actual" = "$2"
}

sha_tag="sha-$RELEASE_SHA"
target=${TARGET_DIGEST:-}
mirror_target=${MIRROR_DIGEST:-}

if [[ -n "$target" ]]; then
  valid_digest "$target" || { echo "invalid TARGET_DIGEST" >&2; exit 2; }
  if [[ -n "$mirror_target" ]]; then
    valid_digest "$mirror_target" || { echo "invalid MIRROR_DIGEST" >&2; exit 2; }
    test "$target" = "$mirror_target"
  fi
else
  canonical_sha=$(inspect_optional "$GHCR_IMAGE:$sha_tag")
  mirror_sha=$(inspect_optional "$DOCKERHUB_IMAGE:$sha_tag")
  if valid_digest "$canonical_sha"; then
    target=$canonical_sha
  elif valid_digest "$mirror_sha"; then
    target=$mirror_sha
  else
    echo "No public $sha_tag reference exists; nothing to reconcile."
    exit 0
  fi
fi

retry digest_available_once "$DOCKERHUB_IMAGE" "$target"
retry digest_available_once "$GHCR_IMAGE" "$target"

ensure_reference "$DOCKERHUB_IMAGE" "$sha_tag" "$target"
ensure_reference "$GHCR_IMAGE" "$sha_tag" "$target"
if [[ "${PROMOTE_LATEST:-false}" == true ]]; then
  ensure_reference "$DOCKERHUB_IMAGE" latest "$target"
  ensure_reference "$GHCR_IMAGE" latest "$target"
fi

printf 'Public references converged on %s\n' "$target"
