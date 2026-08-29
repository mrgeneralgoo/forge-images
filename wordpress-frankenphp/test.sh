#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile
workflow=$script_dir/../.github/workflows/wordpress-frankenphp.yml

for text in \
  'BUILD_DIGEST: ${{ steps.build.outputs.digest }}' \
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
  'image_digest: ${{ steps.resolve.outputs.image_digest }}' \
  "--format '{{json .SBOM.SPDX}}'"; do
  grep -F -- "$text" "$workflow" >/dev/null
done
if grep -Eq 'image-ref:.*steps\.build\.outputs\.digest|subject-digest:.*steps\.build\.outputs\.digest' "$workflow"; then
  echo "scan or attestation still uses the BuildKit index digest" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]+DIGEST:' "$workflow"; then
  echo "workflow uses the ambiguous DIGEST variable" >&2
  exit 1
fi
if grep -Fq '      digest: ${{ steps.build.outputs.digest }}' "$workflow"; then
  echo "build job exposes the BuildKit index instead of the platform image" >&2
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
assert_next_step 'Build amd64 and push by digest' 'Resolve canonical amd64 image manifest digest'
assert_next_step 'Build arm64 and push by digest' 'Resolve canonical arm64 image manifest digest'

final_index_workflow=$(awk '/^  publish-index:/{found=1} found {print}' "$workflow")
for text in \
  'AMD64_IMAGE_DIGEST: ${{ needs.build-amd64.outputs.image_digest }}' \
  'ARM64_IMAGE_DIGEST: ${{ needs.build-arm64.outputs.image_digest }}' \
  '"$GHCR_IMAGE@$AMD64_IMAGE_DIGEST"' \
  '"$GHCR_IMAGE@$ARM64_IMAGE_DIGEST"' \
  '"$DOCKERHUB_IMAGE@$AMD64_IMAGE_DIGEST"' \
  '"$DOCKERHUB_IMAGE@$ARM64_IMAGE_DIGEST"'; do
  grep -F -- "$text" <<<"$final_index_workflow" >/dev/null
done
if grep -Eq 'steps\.build\.outputs\.digest|needs\.build-(amd64|arm64)\.outputs\.digest|@AMD64_DIGEST|@ARM64_DIGEST' <<<"$final_index_workflow"; then
  echo "final index uses a BuildKit output index" >&2
  exit 1
fi
assert_order() {
  local first=$1 second=$2 first_line second_line
  first_line=$(grep -n -F -- "$first" "$workflow" | head -n1 | cut -d: -f1)
  second_line=$(grep -n -F -- "$second" "$workflow" | head -n1 | cut -d: -f1)
  test "$first_line" -lt "$second_line"
}
assert_order '"$GHCR_IMAGE@$AMD64_IMAGE_DIGEST"' '"$GHCR_IMAGE@$ARM64_IMAGE_DIGEST"'
assert_order '"$DOCKERHUB_IMAGE@$AMD64_IMAGE_DIGEST"' '"$DOCKERHUB_IMAGE@$ARM64_IMAGE_DIGEST"'
assert_order 'Create identical non-release staging indexes' 'Attest final multi-architecture index provenance on GHCR'
assert_order 'Attest final multi-architecture index provenance on GHCR' 'Sign immutable staging index digests'
assert_order 'Sign immutable staging index digests' 'Create immutable sha references after all gates'
assert_order 'Create immutable sha references after all gates' 'Create latest references on main after sha references'
step_contains() {
  local step=$1 needle=$2
  awk -v step="$step" -v needle="$needle" '
    $0 == "      - name: " step { in_step=1; next }
    in_step && /^      - name: / { exit(found ? 0 : 1) }
    in_step && index($0, needle) { found=1 }
    END { if (!found) exit 1 }
  ' "$workflow"
}
step_contains 'Build amd64 and push by digest' 'platforms: linux/amd64'
step_contains 'Resolve canonical amd64 image manifest digest' 'docker buildx imagetools inspect "$GHCR_IMAGE@$BUILD_DIGEST" --raw'
step_contains 'Block HIGH and CRITICAL vulnerabilities on amd64' 'image-ref: ${{ env.GHCR_IMAGE }}@${{ steps.resolve.outputs.image_digest }}'
step_contains 'Extract attached amd64 SPDX SBOM' 'BUILD_DIGEST: ${{ steps.build.outputs.digest }}'
step_contains 'Extract attached amd64 SPDX SBOM' '"$GHCR_IMAGE@$BUILD_DIGEST"'
step_contains 'Attest amd64 SPDX SBOM on canonical registry' 'subject-digest: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Attest amd64 build provenance on canonical registry' 'subject-digest: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Sign amd64 digest' 'cosign sign --yes "$GHCR_IMAGE@$IMAGE_DIGEST"'
step_contains 'Sign amd64 digest' 'cosign sign --yes "$DOCKERHUB_IMAGE@$IMAGE_DIGEST"'
step_contains 'Build arm64 and push by digest' 'platforms: linux/arm64'
step_contains 'Resolve canonical arm64 image manifest digest' 'docker buildx imagetools inspect "$GHCR_IMAGE@$BUILD_DIGEST" --raw'
step_contains 'Block HIGH and CRITICAL vulnerabilities on arm64' 'image-ref: ${{ env.GHCR_IMAGE }}@${{ steps.resolve.outputs.image_digest }}'
step_contains 'Extract attached arm64 SPDX SBOM' 'BUILD_DIGEST: ${{ steps.build.outputs.digest }}'
step_contains 'Extract attached arm64 SPDX SBOM' '"$GHCR_IMAGE@$BUILD_DIGEST"'
step_contains 'Attest arm64 SPDX SBOM on canonical registry' 'subject-digest: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Attest arm64 build provenance on canonical registry' 'subject-digest: ${{ steps.resolve.outputs.image_digest }}'
step_contains 'Sign arm64 digest' 'cosign sign --yes "$GHCR_IMAGE@$IMAGE_DIGEST"'
step_contains 'Sign arm64 digest' 'cosign sign --yes "$DOCKERHUB_IMAGE@$IMAGE_DIGEST"'

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

  printf '%s\n' '{"mediaType":"application/vnd.oci.image.manifest.v1+json"}' > "$fixture/image.json"
  test "$(jq -er --arg os linux --arg arch amd64 --arg build_digest sha256:build "$jq_filter" "$fixture/image.json")" = sha256:build
  rm -rf "$fixture"
  trap - RETURN
}
check_image_manifest_resolution

for text in \
  'FROM wordpress:7.1.0-php8.3-apache@sha256:8801a1239d7ba9fb340a5fc5ba0bf7f8d3652adbd64893e3fba7992ba618108e AS wordpress-core' \
  'FROM ghcr.io/mrgeneralgoo/frankenphp:latest@sha256:89d9081b847dbacfa081acd6d2a125de81e810402fb3a1bb9f8df62f0b25a1c1' \
  'COPY --from=wordpress-core /usr/src/wordpress/ /var/www/html/public/' \
  'COPY --from=wordpress-core /usr/src/wordpress/license.txt /usr/share/doc/wordpress/LICENSE' \
  'VOLUME ["/var/www/html/public/wp-content/uploads", "/var/www/html/public/wp-content/cache"]'; do
  grep -F "$text" "$dockerfile" >/dev/null
done

grep -F 'platforms: linux/amd64' "$workflow" >/dev/null
grep -F 'platforms: linux/arm64' "$workflow" >/dev/null
if grep -Eq '^[[:space:]]*FROM[[:space:]]+--platform=' "$dockerfile"; then
  echo "fixed platform in Dockerfile" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*COPY[[:space:]].*wp-content' "$dockerfile"; then
  echo "local wp-content copy in Dockerfile" >&2
  exit 1
fi
if awk '
  /^[[:space:]]*COPY[[:space:]]/ {
    if ($0 !~ /--from=/ && $0 !~ /COPY[[:space:]]+NOTICE\.md[[:space:]]/) {
      print
      bad=1
    }
  }
  END { exit bad }
' "$dockerfile"; then
  :
else
  echo "unexpected local COPY in Dockerfile" >&2
  exit 1
fi

volumes=$(docker image inspect "$image" --format '{{range $path, $_ := .Config.Volumes}}{{$path}}{{"\n"}}{{end}}')
grep -Fx '/var/www/html/public/wp-content/uploads' <<<"$volumes" >/dev/null
grep -Fx '/var/www/html/public/wp-content/cache' <<<"$volumes" >/dev/null

docker run --rm --entrypoint sh "$image" -s <<'CHECK'
set -eu

php -v | grep -F 'PHP 8.5'
php -r 'require "/var/www/html/public/wp-includes/version.php"; exit($wp_version === "7.1" ? 0 : 1);'
test -f /var/www/html/public/wp-admin/about.php
test -f /var/www/html/public/wp-includes/version.php
test -s /usr/share/doc/wordpress/LICENSE
test -s /usr/share/doc/wordpress/PROVENANCE
test -s /usr/share/doc/wordpress/NOTICE.md
grep -F 'sha256:8801a1239d7ba9fb340a5fc5ba0bf7f8d3652adbd64893e3fba7992ba618108e' /usr/share/doc/wordpress/PROVENANCE
cmp -s /var/www/html/public/license.txt /usr/share/doc/wordpress/LICENSE

test "$(id -u)" -eq 33
test "$(id -g)" -eq 33
for dir in /var/www/html/public /var/www/html/public/wp-content \
           /var/www/html/public/wp-content/uploads \
           /var/www/html/public/wp-content/cache; do
  test -d "$dir"
  test "$(stat -c '%U:%G' "$dir")" = 'www-data:www-data'
done
for dir in /var/www/html/public/wp-content/uploads \
           /var/www/html/public/wp-content/cache; do
  test -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)"
  touch "$dir/.write-test"
  rm "$dir/.write-test"
done

for file in /var/www/html/public/wp-config.php \
            /var/www/html/public/.env /var/www/html/public/.htpasswd \
            /var/www/html/public/.git/config; do
  test ! -e "$file"
done
for marker in "consu""m""er" "pre""m""ium" "site""-""specific"; do
  if find /var/www/html/public -xdev -type f -iname "*$marker*" -print -quit | grep -q .; then
    exit 1
  fi
done
if find /var/www/html/public -xdev -type f \( \
  -iname '*.env' -o -iname '*.pem' -o -iname '*.key' \
  -o -iname '*.p12' -o -iname '*.pfx' -o -iname 'id_rsa*' \
\) -print -quit | grep -q .; then
  exit 1
fi
CHECK

echo "wordpress-frankenphp checks passed: $image"
