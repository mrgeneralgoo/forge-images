#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile
workflow=$script_dir/../.github/workflows/mapservice-build.yml

for text in \
  'BUILD_DIGEST: ${{ steps.build.outputs.digest }}' \
  'outputs: type=image,name=${{ env.GHCR_IMAGE }},push-by-digest=true,name-canonical=true,push=true' \
  'docker buildx imagetools inspect "$GHCR_IMAGE@$BUILD_DIGEST" --raw' \
  'if (.manifests? | type) == "array" then' \
  '.platform.os? == $os' \
  '.platform.architecture? == $arch' \
  'else error("expected exactly one platform image manifest")' \
  'application/vnd.oci.image.manifest.v1+json' \
  'vnd.docker.reference.type' \
  'image-ref: ${{ env.GHCR_IMAGE }}@${{ steps.resolve.outputs.image_digest }}' \
  'subject-digest: ${{ steps.resolve.outputs.image_digest }}' \
  'IMAGE_DIGEST: ${{ steps.resolve.outputs.image_digest }}' \
  "--format '{{json .SBOM.SPDX}}'"; do
  grep -F -- "$text" "$workflow" >/dev/null
done
if grep -Eq 'image-ref:.*steps\.build\.outputs\.digest|subject-digest:.*steps\.build\.outputs\.digest' "$workflow"; then
  echo "scan or attestation still uses the BuildKit index digest" >&2
  exit 1
fi
if grep -Fq 'type=image,name=${{ env.DOCKERHUB_IMAGE }}' "$workflow"; then
  echo "build step has multiple registry exporters with different output digests" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]+DIGEST:' "$workflow"; then
  echo "workflow uses the ambiguous DIGEST variable" >&2
  exit 1
fi
assert_next_step() {
  local first=$1 second=$2
  awk -v first="$first" -v second="$second" '
    $0 == "      - name: " first { seen=1; next }
    seen && /^      - (name|uses): / { exit($0 == "      - name: " second ? 0 : 1) }
    END { if (!seen) exit 1 }
  ' "$workflow"
}
assert_next_step 'Build and push canonical image by digest' 'Resolve canonical platform image manifest digest'
assert_next_step 'Attest build provenance on canonical registry' 'Mirror scanned image to Docker Hub staging'
step_contains() {
  local step=$1 needle=$2
  awk -v step="$step" -v needle="$needle" '
    $0 == "      - name: " step { in_step=1; next }
    in_step && /^      - name: / { exit(found ? 0 : 1) }
    in_step && index($0, needle) { found=1 }
    END { if (!found) exit 1 }
  ' "$workflow"
}
step_contains 'Block HIGH and CRITICAL vulnerabilities' 'image-ref: ${{ env.GHCR_IMAGE }}@${{ steps.resolve.outputs.image_digest }}'
step_contains 'Extract attached SPDX SBOM' 'BUILD_DIGEST: ${{ steps.build.outputs.digest }}'
step_contains 'Extract attached SPDX SBOM' '"$GHCR_IMAGE@$BUILD_DIGEST"'
step_contains 'Extract attached SPDX SBOM' "--format '{{json .SBOM.SPDX}}'"
step_contains 'Attest SPDX SBOM on canonical registry' 'subject-digest: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Attest build provenance on canonical registry' 'subject-digest: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Mirror scanned image to Docker Hub staging' '"$GHCR_IMAGE@$IMAGE_DIGEST"'
step_contains 'Mirror scanned image to Docker Hub staging' '--tag "$DOCKERHUB_IMAGE:$staging_tag"'
step_contains 'Mirror scanned image to Docker Hub staging' '--prefer-index=false'
step_contains 'Mirror scanned image to Docker Hub staging' 'test "$mirror_digest" = "$IMAGE_DIGEST"'
step_contains 'Sign canonical and mirror digests' 'IMAGE_DIGEST: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Sign canonical and mirror digests' 'cosign sign --yes "$GHCR_IMAGE@$IMAGE_DIGEST"'
step_contains 'Sign canonical and mirror digests' 'cosign sign --yes "$DOCKERHUB_IMAGE@$IMAGE_DIGEST"'
step_contains 'Create immutable release references' '"$GHCR_IMAGE@$IMAGE_DIGEST"'
step_contains 'Create immutable release references' '--prefer-index=false'
step_contains 'Create immutable release references' 'test "$release_digest" = "$IMAGE_DIGEST"'
step_contains 'Create immutable release references' 'test "$mirror_digest" = "$IMAGE_DIGEST"'
step_contains 'Update mutable latest references after scan and signing' '"$DOCKERHUB_IMAGE@$IMAGE_DIGEST"'
step_contains 'Update mutable latest references after scan and signing' '--prefer-index=false'

pin() {
  awk -v key="$1" '$1 == "ARG" && index($2, key "=") == 1 { sub("^[^=]+=", "", $2); print $2; exit }' "$dockerfile"
}

expected_stormlib_version=$(pin STORMLIB_VERSION)
expected_stormlib_commit=$(pin STORMLIB_COMMIT)
expected_stormlib_sha=$(pin STORMLIB_ARCHIVE_SHA256)
expected_go_version=$(pin GO_VERSION)
expected_go_commit=$(pin GO_COMMIT)
expected_go_sha=$(pin GO_ARCHIVE_SHA256)
expected_sqlc_version=$(pin SQLC_VERSION)
expected_sqlc_commit=$(pin SQLC_COMMIT)
expected_sqlc_sha=$(pin SQLC_ARCHIVE_SHA256)
expected_golangci_version=$(pin GOLANGCI_VERSION)
expected_golangci_commit=$(pin GOLANGCI_COMMIT)
expected_golangci_sha=$(pin GOLANGCI_ARCHIVE_SHA256)

if ! [[ "$expected_stormlib_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "invalid StormLib version pin" >&2
  exit 1
fi
if ! [[ "$expected_go_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid Go version pin" >&2
  exit 1
fi
if ! [[ "$expected_sqlc_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid sqlc version pin" >&2
  exit 1
fi
if ! [[ "$expected_golangci_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid golangci-lint version pin" >&2
  exit 1
fi

for commit in \
  "$expected_stormlib_commit" \
  "$expected_go_commit" \
  "$expected_sqlc_commit" \
  "$expected_golangci_commit"; do
  if ! [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo "invalid source commit pin" >&2
    exit 1
  fi
done
for sha in \
  "$expected_stormlib_sha" \
  "$expected_go_sha" \
  "$expected_sqlc_sha" \
  "$expected_golangci_sha"; do
  if ! [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "invalid source archive checksum pin" >&2
    exit 1
  fi
done

for text in \
  'FROM golang:1.27.0-trixie@sha256:ae28539d2ef595b9a2930dd7f031d9592376829dc0eae7cb869559f7d5812c3a' \
  'FROM sqlc/sqlc:1.31.1@sha256:70f53171d27b2424e9358869975455a6e955a5aa8e58a998a270a6e34e525537' \
  'FROM golangci/golangci-lint:v2.13.1@sha256:d371321370bf2907bd13a8f6f8baff0e0ca7438d76fdf636b281eadf7e2305e3' \
  'AS upstream-source' \
  'COPY --from=upstream-source /tmp/upstream/go/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/go/PROVENANCE' \
  'COPY --from=upstream-source /tmp/upstream/sqlc/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/sqlc/PROVENANCE' \
  'COPY --from=upstream-source /tmp/upstream/golangci-lint/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/golangci-lint/PROVENANCE' \
  'COPY --from=upstream-source /tmp/upstream/stormlib/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/stormlib/PROVENANCE' \
  'org.opencontainers.image.licenses="Apache-2.0 AND BSD-3-Clause AND GPL-3.0-only AND MIT"'; do
  grep -F "$text" "$dockerfile" >/dev/null
done

for key in \
  STORMLIB_VERSION STORMLIB_COMMIT STORMLIB_ARCHIVE_SHA256 \
  GO_VERSION GO_COMMIT GO_ARCHIVE_SHA256 \
  SQLC_VERSION SQLC_COMMIT SQLC_ARCHIVE_SHA256 \
  GOLANGCI_VERSION GOLANGCI_COMMIT GOLANGCI_ARCHIVE_SHA256; do
  grep -Eq "^ARG ${key}=" "$dockerfile"
done

if grep -Eq '^COPY --from=(sqlc|golangci)(:[^[:space:]]+)?[[:space:]]+.*(LICENSE|PROVENANCE)' "$dockerfile"; then
  echo "license or provenance copied from a tool image" >&2
  exit 1
fi
for text in \
  "ARG STORMLIB_VERSION=$expected_stormlib_version" \
  "ARG STORMLIB_COMMIT=$expected_stormlib_commit" \
  "ARG STORMLIB_ARCHIVE_SHA256=$expected_stormlib_sha" \
  "ARG GO_VERSION=$expected_go_version" \
  "ARG GO_COMMIT=$expected_go_commit" \
  "ARG GO_ARCHIVE_SHA256=$expected_go_sha" \
  "ARG SQLC_VERSION=$expected_sqlc_version" \
  "ARG SQLC_COMMIT=$expected_sqlc_commit" \
  "ARG SQLC_ARCHIVE_SHA256=$expected_sqlc_sha" \
  "ARG GOLANGCI_VERSION=$expected_golangci_version" \
  "ARG GOLANGCI_COMMIT=$expected_golangci_commit" \
  "ARG GOLANGCI_ARCHIVE_SHA256=$expected_golangci_sha"; do
  grep -F "$text" "$dockerfile" >/dev/null
done

for url in \
  'https://codeload.github.com/golang/go/tar.gz/' \
  'https://codeload.github.com/sqlc-dev/sqlc/tar.gz/' \
  'https://codeload.github.com/golangci/golangci-lint/tar.gz/' \
  'https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/'; do
  grep -F "$url" "$dockerfile" >/dev/null
done

check_image_manifest_resolution() {
  local fixture jq_filter duplicate_status
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  jq_filter='
    if (.manifests? | type) == "array" then
      [
        .manifests[]
        | select(
            .platform.os? == $os
            and .platform.architecture? == $arch
            and (
              .mediaType? == "application/vnd.oci.image.manifest.v1+json"
              or .mediaType? == "application/vnd.docker.distribution.manifest.v2+json"
            )
            and .annotations["vnd.docker.reference.type"]? != "attestation-manifest"
          )
      ]
      | if length == 1 then .[0].digest
        else error("expected exactly one platform image manifest")
        end
    elif (
      .mediaType? == "application/vnd.oci.image.manifest.v1+json"
      or .mediaType? == "application/vnd.docker.distribution.manifest.v2+json"
    ) then
      $build_digest
    else
      error("expected an OCI index or image manifest")
    end
  '
  cat > "$fixture/index.json" <<'JSON'
{"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[
  {"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"sha256:image","platform":{"os":"linux","architecture":"amd64"}},
  {"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"sha256:attestation","platform":{"os":"unknown","architecture":"unknown"},"annotations":{"vnd.docker.reference.type":"attestation-manifest"}},
  {"mediaType":"application/vnd.in-toto+json","digest":"sha256:attestation-target","platform":{"os":"linux","architecture":"amd64"},"annotations":{"vnd.docker.reference.type":"attestation-manifest"}}
]}
JSON
  test "$(jq -er --arg os linux --arg arch amd64 --arg build_digest sha256:build "$jq_filter" "$fixture/index.json")" = sha256:image
  jq '.manifests[0].mediaType = "application/vnd.docker.distribution.manifest.v2+json"' \
    "$fixture/index.json" > "$fixture/docker-index.json"
  test "$(jq -er --arg os linux --arg arch amd64 --arg build_digest sha256:build "$jq_filter" "$fixture/docker-index.json")" = sha256:image

  jq '.manifests += [.manifests[0]]' "$fixture/index.json" > "$fixture/duplicate.json"
  set +e
  jq -er --arg os linux --arg arch amd64 --arg build_digest sha256:build "$jq_filter" "$fixture/duplicate.json" >/dev/null 2>&1
  duplicate_status=$?
  set -e
  test "$duplicate_status" -ne 0

  printf '%s\n' '{"mediaType":"application/vnd.docker.distribution.manifest.v2+json"}' > "$fixture/image.json"
  test "$(jq -er --arg os linux --arg arch amd64 --arg build_digest sha256:build "$jq_filter" "$fixture/image.json")" = sha256:build
  rm -rf "$fixture"
  trap - RETURN
}
check_image_manifest_resolution
for checksum in \
  "$expected_go_sha" \
  "$expected_sqlc_sha" \
  "$expected_golangci_sha" \
  "$expected_stormlib_sha"; do
  grep -F "sha256sum --check --status" "$dockerfile" >/dev/null
  grep -F "$checksum" "$dockerfile" >/dev/null
done

test_updater_rollback() {
  local mode=$1
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  cp "$dockerfile" "$script_dir/update-stormlib-pin.sh" "$script_dir/NOTICE.md" "$script_dir/test.sh" "$fixture/"
  cp "$fixture/Dockerfile" "$fixture/Dockerfile.before"

  set +e
  env -u RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE \
    STORMLIB_UPDATE_TEST_COMMIT=1111111111111111111111111111111111111111 \
    STORMLIB_UPDATE_TEST_SHA256=2222222222222222222222222222222222222222222222222222222222222222 \
    STORMLIB_UPDATE_TEST_FAIL_AFTER_RENAME="$mode" \
    bash "$fixture/update-stormlib-pin.sh" v9.41 >/dev/null 2>&1
  local status=$?
  set -e

  if (( status == 0 )); then
    echo "StormLib updater failure injection unexpectedly succeeded: $mode" >&2
    exit 1
  fi
  cmp -s "$fixture/Dockerfile.before" "$fixture/Dockerfile"
  if find "$fixture" -maxdepth 1 -type f \
      \( -name '*.tmp.*' -o -name '*.backup.*' -o -name 'Dockerfile.new' \) \
      -print -quit | grep -q .; then
    echo "StormLib updater left transaction artifacts: $mode" >&2
    exit 1
  fi
  rm -rf "$fixture"
  trap - RETURN
}

for mode in exit term; do
  test_updater_rollback "$mode"
done

expected_stormlib_version_number=${expected_stormlib_version#v}
docker run --rm \
  -e EXPECTED_STORMLIB_VERSION="$expected_stormlib_version_number" \
  -e EXPECTED_STORMLIB_COMMIT="$expected_stormlib_commit" \
  -e EXPECTED_STORMLIB_SHA="$expected_stormlib_sha" \
  -e EXPECTED_GO_VERSION="$expected_go_version" \
  -e EXPECTED_GO_COMMIT="$expected_go_commit" \
  -e EXPECTED_GO_SHA="$expected_go_sha" \
  -e EXPECTED_SQLC_VERSION="$expected_sqlc_version" \
  -e EXPECTED_SQLC_COMMIT="$expected_sqlc_commit" \
  -e EXPECTED_SQLC_SHA="$expected_sqlc_sha" \
  -e EXPECTED_GOLANGCI_VERSION="$expected_golangci_version" \
  -e EXPECTED_GOLANGCI_COMMIT="$expected_golangci_commit" \
  -e EXPECTED_GOLANGCI_SHA="$expected_golangci_sha" \
  --entrypoint sh "$image" -s <<'CHECK'
set -eu

export DEBIAN_FRONTEND=noninteractive

go version | grep -F "go$EXPECTED_GO_VERSION linux/amd64"
sqlc version | grep -F "$EXPECTED_SQLC_VERSION"
golangci-lint --version | grep -F "${EXPECTED_GOLANGCI_VERSION#v}"

for file in /usr/share/doc/go/LICENSE \
            /usr/share/doc/go/PATENTS \
            /usr/share/doc/go/PROVENANCE \
            /usr/share/doc/sqlc/LICENSE \
            /usr/share/doc/sqlc/PROVENANCE \
            /usr/share/doc/golangci-lint/LICENSE \
            /usr/share/doc/golangci-lint/PROVENANCE \
            /usr/share/source/golangci-lint/source.tar.gz \
            /usr/share/doc/stormlib/LICENSE \
            /usr/share/doc/stormlib/PROVENANCE \
            /usr/share/doc/mapservice-build/NOTICE.md; do
  test -s "$file"
done

grep -F 'Copyright 2009 The Go Authors.' /usr/share/doc/go/LICENSE
grep -F 'MIT License' /usr/share/doc/sqlc/LICENSE
grep -F 'GNU GENERAL PUBLIC LICENSE' /usr/share/doc/golangci-lint/LICENSE
grep -F 'The MIT License (MIT)' /usr/share/doc/stormlib/LICENSE

grep -F "Source URL: https://codeload.github.com/golang/go/tar.gz/$EXPECTED_GO_COMMIT" \
  /usr/share/doc/go/PROVENANCE
grep -F "Source tag: go$EXPECTED_GO_VERSION" /usr/share/doc/go/PROVENANCE
grep -F "Source commit: $EXPECTED_GO_COMMIT" /usr/share/doc/go/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_GO_SHA" /usr/share/doc/go/PROVENANCE
grep -F "Source URL: https://codeload.github.com/sqlc-dev/sqlc/tar.gz/$EXPECTED_SQLC_COMMIT" \
  /usr/share/doc/sqlc/PROVENANCE
grep -F "Source tag: v$EXPECTED_SQLC_VERSION" /usr/share/doc/sqlc/PROVENANCE
grep -F "Source commit: $EXPECTED_SQLC_COMMIT" /usr/share/doc/sqlc/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_SQLC_SHA" /usr/share/doc/sqlc/PROVENANCE
grep -F "Source URL: https://codeload.github.com/golangci/golangci-lint/tar.gz/$EXPECTED_GOLANGCI_COMMIT" \
  /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source tag: $EXPECTED_GOLANGCI_VERSION" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source commit: $EXPECTED_GOLANGCI_COMMIT" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_GOLANGCI_SHA" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source URL: https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/$EXPECTED_STORMLIB_COMMIT" \
  /usr/share/doc/stormlib/PROVENANCE
grep -F "Source tag: v$EXPECTED_STORMLIB_VERSION" /usr/share/doc/stormlib/PROVENANCE
grep -F "Source commit: $EXPECTED_STORMLIB_COMMIT" /usr/share/doc/stormlib/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_STORMLIB_SHA" /usr/share/doc/stormlib/PROVENANCE

grep -F "License: BSD-3-Clause" /usr/share/doc/go/PROVENANCE
grep -F "License: MIT" /usr/share/doc/sqlc/PROVENANCE
grep -F "License: GPL-3.0" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "License: MIT" /usr/share/doc/stormlib/PROVENANCE
printf '%s  %s\n' "$EXPECTED_GOLANGCI_SHA" /usr/share/source/golangci-lint/source.tar.gz | sha256sum --check --status
tar -tzf /usr/share/source/golangci-lint/source.tar.gz | grep -Eq '/LICENSE$'
grep -F 'Corresponding source: /usr/share/source/golangci-lint/source.tar.gz' \
  /usr/share/doc/golangci-lint/PROVENANCE

test -s /usr/local/lib/libstorm.so
test -s /usr/local/include/StormLib.h
ldd /usr/local/lib/libstorm.so
grep -F "STORMLIB_VERSION_STRING         \"$EXPECTED_STORMLIB_VERSION\"" \
  /usr/local/include/StormLib.h
cat >/tmp/storm-smoke.c <<'EOF'
#include <StormLib.h>
int main(void) { return STORMLIB_VERSION_STRING[0] == '9' ? 0 : 1; }
EOF
gcc -Wall -Werror /tmp/storm-smoke.c -I/usr/local/include -L/usr/local/lib \
  -Wl,-rpath,/usr/local/lib -lstorm -o /tmp/storm-smoke
/tmp/storm-smoke

for path in /tmp/upstream /tmp/metadata /tmp/go.tar.gz /tmp/sqlc.tar.gz \
            /tmp/golangci-lint.tar.gz /tmp/stormlib.tar.gz /tmp/stormlib \
            /tmp/stormlib-build /workspace /app /root/.ssh /root/.git \
            /usr/src/wordpress /usr/src/sqlc /usr/src/golangci-lint; do
  test ! -e "$path"
done
CHECK

echo "mapservice-build checks passed: $image"
