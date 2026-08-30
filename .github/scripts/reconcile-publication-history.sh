#!/usr/bin/env bash
set -Eeuo pipefail

: "${GHCR_IMAGE:?GHCR_IMAGE is required}"
: "${DOCKERHUB_IMAGE:?DOCKERHUB_IMAGE is required}"
: "${RECONCILE_MODE:?RECONCILE_MODE is required}"

case "$RECONCILE_MODE" in
  sha|latest) ;;
  *) echo 'RECONCILE_MODE must be sha or latest' >&2; exit 2 ;;
esac

script="${BASH_SOURCE[0]%/*}/reconcile-public-tags.sh"

api_get() {
  local url="$1"
  if [[ -n "${RECONCILE_API_BACKEND:-}" ]]; then
    "$RECONCILE_API_BACKEND" "$url"
  else
    curl -fsSL --retry 3 --retry-all-errors \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "$url"
  fi
}

shas=$(mktemp)
trap 'rm -f "$shas"' EXIT

if [[ -n "${RECONCILE_SHAS_FILE:-}" ]]; then
  cat "$RECONCILE_SHAS_FILE" > "$shas"
else
  : "${GITHUB_API_URL:?GITHUB_API_URL is required}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
  : "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
  : "${WORKFLOW_FILE:?WORKFLOW_FILE is required}"
  page=1
  while :; do
    payload=$(api_get \
      "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/actions/workflows/$WORKFLOW_FILE/runs?per_page=100&page=$page")
    count=$(jq -er '.workflow_runs | length' <<< "$payload")
    jq -r '.workflow_runs[] | select(.head_branch == "main" and .status == "completed") | .head_sha' <<< "$payload" >> "$shas"
    (( count < 100 )) && break
    page=$((page + 1))
  done
fi

ordered=$(mktemp)
trap 'rm -f "$shas" "$ordered"' EXIT
awk '/^[0-9a-f]{40}$/ && !seen[$0]++' "$shas" > "$ordered"
if [[ -n "${RECONCILE_DISCOVERY_FILE:-}" ]]; then
  cp "$ordered" "$RECONCILE_DISCOVERY_FILE"
fi
if [[ "${RECONCILE_DISCOVERY_ONLY:-false}" == true ]]; then
  exit 0
fi

reconcile_sha() {
  local release_sha="$1" promote_latest="$2" result
  result=$(mktemp)
  if ! RELEASE_SHA="$release_sha" \
    PROMOTE_LATEST="$promote_latest" \
    RECONCILE_RESULT_FILE="$result" \
    "$script" >/dev/null; then
    rm -f "$result"
    return 1
  fi
  if [[ -s "$result" ]]; then
    cat "$result"
  fi
  rm -f "$result"
}

if [[ "$RECONCILE_MODE" == sha ]]; then
  while IFS= read -r release_sha; do
    reconcile_sha "$release_sha" false >/dev/null
  done < "$ordered"
  exit 0
fi

while IFS= read -r release_sha; do
  target=$(reconcile_sha "$release_sha" false)
  if [[ -n "$target" ]]; then
    RELEASE_SHA="$release_sha" PROMOTE_LATEST=true "$script"
    exit 0
  fi
done < "$ordered"

echo 'No published sha reference exists; latest needs no repair.'
