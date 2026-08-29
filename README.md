# forge-images

🚢 A curated collection of Docker images for building, running, and shipping software reliably.

This repository focuses on **reusable, maintainable, and reproducible** Docker images designed for development, CI/CD, and production environments.

Architecture support and publication destinations are defined per image below; there is no repository-wide architecture or registry promise.

---

## 📦 Images

| Image | Architecture | Pull | Description |
|-------|--------------|------|-------------|
| **fava** | `linux/amd64, linux/arm64` | `ghcr.io/mrgeneralgoo/fava` · `mrgeneralgoo/fava` | [Fava](https://beancount.github.io/fava/) (Beancount browser) served by gunicorn for real multi-core BQL queries. Baked WSGI entrypoint with `--preload` copy-on-write ledger sharing, a BQL parse cache, and URL-prefix support. |
| **pkm-mcp** | `linux/amd64, linux/arm64` | `ghcr.io/mrgeneralgoo/pkm-mcp` · `mrgeneralgoo/pkm-mcp` | Node.js base for a PKM MCP server: git, ripgrep, and native-module build deps (python3 + build-essential) preinstalled. |
| **openclaw** | `linux/amd64, linux/arm64` | `ghcr.io/mrgeneralgoo/openclaw` · `mrgeneralgoo/openclaw` | Skill/agent tooling layered on the upstream `openclaw` image, each tool pinned and bumped independently by Renovate. |
| **frankenphp** | `linux/amd64, linux/arm64` | `ghcr.io/mrgeneralgoo/frankenphp` · `mrgeneralgoo/frankenphp` | serversideup PHP 8.5 (FrankenPHP) with a curated set of PHP extensions (redis, imagick, gd, intl, bcmath, …). |
| **dae** | `linux/amd64, linux/arm64` | `ghcr.io/mrgeneralgoo/dae` · `mrgeneralgoo/dae` | [dae](https://github.com/daeuniverse/dae) (eBPF transparent proxy) on the pinned upstream image plus a self-contained in-container rule/GeoData auto-update loop (busybox crond + local `dae reload`). Runtime-specific config and the rule-source manifest are bind-mounted, never baked. |
| **mapservice-build** | `linux/amd64` | `ghcr.io/mrgeneralgoo/mapservice-build` · `mrgeneralgoo/mapservice-build` | Minimal Debian Go build environment with Git/CA/CGO support, source-built StormLib, sqlc, and golangci-lint; no application source is copied. |
| **wordpress-frankenphp** | `linux/amd64, linux/arm64` | `ghcr.io/mrgeneralgoo/wordpress-frankenphp` · `mrgeneralgoo/wordpress-frankenphp` | Official WordPress core in the pinned FrankenPHP runtime; uploads and cache are empty runtime volumes, and no local `wp-content` is copied. |

### Image boundaries and runtime inputs

- `mapservice-build` copies Go from the pinned official distribution into a minimal Debian stage with only Git, CA certificates, and the CGO compiler/header path; it also contains pinned sqlc/golangci-lint, StormLib headers/library, and dependency notices/provenance, but no application source.
- `wordpress-frankenphp` copies only the official WordPress core tree into `/var/www/html/public`; `uploads` and `cache` are empty writable volumes.
- Runtime secrets are supplied only through environment variables or Docker/BuildKit secret mounts. They are never baked into an image layer or build context.

### Pull and verify an immutable image

GHCR is the attested canonical registry. Each platform is built once into
GHCR and scanned by immutable image-manifest digest. Trivy remains enabled for
OS and library `HIGH`/`CRITICAL` findings, including unfixed findings, and
uploads SARIF to GitHub code scanning. Vulnerability findings are informational
and do not block image publication. Scanner, action, or vulnerability-database
operational failures remain fatal.

After reporting, each platform is attested and copied by immutable
image-manifest digest to a non-release Docker Hub staging tag. The workflow
verifies the copied digest before signing both registries. Multi-architecture
publication then creates an identical non-release staging index in both
registries, attests the GHCR index, and signs both immutable index digests. Only
after those gates are complete are `sha-` references created; `latest` is
created only on `main`.

The top-level multi-architecture index does not have an SPDX attestation.
BuildKit produces per-platform SBOMs. The GitHub per-platform SBOM and
provenance subjects are the published OS/architecture image-manifest digests;
the BuildKit build-output index digest is only the intermediate used to extract
the raw SPDX document. Resolve the final release index first, then use its raw
manifest to select the target platform image manifest:

```bash
set -Eeuo pipefail
GHCR_IMAGE=ghcr.io/mrgeneralgoo/wordpress-frankenphp
DOCKERHUB_IMAGE=docker.io/mrgeneralgoo/wordpress-frankenphp
WORKFLOW=wordpress-frankenphp
TARGET_OS=linux
TARGET_ARCH=amd64

INDEX_DIGEST="$(
  docker buildx imagetools inspect "$GHCR_IMAGE:latest" \
    --format '{{json .Manifest}}' | jq -er '.digest'
)"
MIRROR_INDEX_DIGEST="$(
  docker buildx imagetools inspect "$DOCKERHUB_IMAGE:latest" \
    --format '{{json .Manifest}}' | jq -er '.digest'
)"
test "$MIRROR_INDEX_DIGEST" = "$INDEX_DIGEST"

RAW_INDEX=$(mktemp)
trap 'rm -f "$RAW_INDEX"' EXIT
docker buildx imagetools inspect "$GHCR_IMAGE@$INDEX_DIGEST" --raw > "$RAW_INDEX"

if jq -e '(.manifests? | type) == "array"' "$RAW_INDEX" >/dev/null; then
  CHILD_DIGEST="$(jq -er \
    --arg os "$TARGET_OS" --arg arch "$TARGET_ARCH" \
    '[.manifests[] | select(
       .platform.os? == $os and
       .platform.architecture? == $arch and
       (.mediaType? == "application/vnd.oci.image.manifest.v1+json" or
        .mediaType? == "application/vnd.docker.distribution.manifest.v2+json") and
       .annotations["vnd.docker.reference.type"]? != "attestation-manifest"
     )]
     | if length == 1 then .[0].digest else error("target platform image is not unique") end' \
    "$RAW_INDEX")"
elif jq -e '(.mediaType? == "application/vnd.oci.image.manifest.v1+json" or
            .mediaType? == "application/vnd.docker.distribution.manifest.v2+json")' \
      "$RAW_INDEX" >/dev/null; then
  # A single image manifest has no index children; its top-level digest is the child.
  CHILD_DIGEST="$INDEX_DIGEST"
else
  echo "expected a release index or image manifest" >&2
  exit 1
fi

IDENTITY="https://github.com/mrgeneralgoo/forge-images/.github/workflows/${WORKFLOW}.yml@refs/heads/main"
VERIFY_ARGS=(
  --certificate-identity "$IDENTITY"
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
)

# Verify the GHCR index signature and its build provenance.
cosign verify "${VERIFY_ARGS[@]}" "$GHCR_IMAGE@$INDEX_DIGEST"
cosign verify-attestation --type slsaprovenance \
  "${VERIFY_ARGS[@]}" "$GHCR_IMAGE@$INDEX_DIGEST"
# Verify the signed Docker Hub mirror index.
cosign verify "${VERIFY_ARGS[@]}" "$DOCKERHUB_IMAGE@$INDEX_DIGEST"

# Verify the SPDX SBOM for the selected GHCR platform manifest.
cosign verify-attestation --type spdxjson \
  "${VERIFY_ARGS[@]}" "$GHCR_IMAGE@$CHILD_DIGEST"
# Optional: verify per-platform build provenance too.
cosign verify-attestation --type slsaprovenance \
  "${VERIFY_ARGS[@]}" "$GHCR_IMAGE@$CHILD_DIGEST"
```

For `mapservice-build`, set `GHCR_IMAGE` to
`ghcr.io/mrgeneralgoo/mapservice-build`, `DOCKERHUB_IMAGE` to
`docker.io/mrgeneralgoo/mapservice-build`, and `WORKFLOW=mapservice-build`.
Set `TARGET_ARCH=amd64`. The branch above handles either a single image manifest
or a one-entry index; for a single image manifest, `CHILD_DIGEST` correctly
falls back to `INDEX_DIGEST`. The same SPDX command then verifies that image's
platform SBOM. The Docker Hub mirror is signed, while GHCR carries the
attestation records.

### License

Repository-authored Dockerfiles, scripts, workflows, and documentation are
licensed under Apache-2.0; see [`LICENSE`](LICENSE) and [`NOTICE.md`](NOTICE.md).
Each image retains the upstream licenses and provenance described in its local
`NOTICE.md` and direct image files. Generated SBOMs are supplementary.
Repository licensing does not replace or relicense bundled third-party
components.

### Example — fava

```bash
docker run -d \
  -v ./ledger:/data:ro \
  -e FAVA_BEANFILE=/data/main.bean \
  -e FAVA_PREFIX=/fava \
  -e FAVA_WORKERS=3 \
  -p 5000:5000 \
  ghcr.io/mrgeneralgoo/fava
```

| Env | Default | Purpose |
|-----|---------|---------|
| `FAVA_BEANFILE` | `/data/main.bean` | Path to the root `.bean` ledger (bind-mounted). |
| `FAVA_PREFIX` | `/fava` | URL prefix; set to `""` to serve at root. |
| `FAVA_WORKERS` | `3` | gunicorn worker processes (keep modest on low-power boards). |

> `HOME=/tmp` is baked in so the container runs cleanly under a non-root UID — useful when matching a bind-mounted ledger's owner (e.g. `user: "1000:1000"`).

### Example — dae

The image bakes only the generic dae binary and the update machinery; your dae
runtime and rule-source manifest stay on the host and are mounted in, so no
runtime-specific data ever lands in the published image. dae needs a Linux host with
eBPF, so it runs privileged with host networking and the host PID namespace.

```yaml
services:
  dae:
    image: ghcr.io/mrgeneralgoo/dae
    privileged: true
    network_mode: host
    pid: host
    volumes:
      - /sys:/sys
      - ./runtime:/etc/dae                       # config.dae + its includes + geo data
      - ./rule-providers.json:/config/rule-providers.json:ro  # runtime-specific rule sources
    restart: unless-stopped
```

| Env | Default | Purpose |
|-----|---------|---------|
| `DAE_RUNTIME` | `/etc/dae` | dae runtime dir: `config.dae` plus the files it `include`s and the geo data. Must be a complete, valid dae runtime before start (see below). |
| `DAE_RULE_MANIFEST` | `/config/rule-providers.json` | Rule-source manifest driving `update-rules.sh`. If the path is absent, rule updates are skipped (geo updates still run). |
| `DAE_GEO_BASE_URL` | Loyalsoldier `v2ray-rules-dat` latest | Base URL for `geoip.dat` / `geosite.dat`. |

> The updater refreshes rules **daily (04:17)** and GeoData **weekly (Mon 04:07)**, each with up to 15m jitter, plus a catch-up refresh on startup — all in-container, reloading dae locally (no host scheduler, no Docker socket). On first start `/etc/dae` must already be a valid runtime (including a placeholder `rules.generated.dae`, e.g. `routing {}`), since the daemon starts before the first update lands.

---

## 🔄 How updates work

Dependencies are **pinned for reproducibility** and kept current automatically:

- **Base images & GitHub Actions** are digest-pinned; [Renovate](https://docs.renovatebot.com/) (`docker:pinDigests`, `helpers:pinGitHubActionDigests`) opens bump PRs.
- **Language deps** are pinned in each image's manifest (e.g. `fava/requirements.txt`) and tracked by Renovate's native managers.
- Every PR is **smoke-tested in CI** (`.github/workflows/ci.yml` runs each image's `test.sh`); ordinary one-pin updates may auto-merge after checks, while synchronized Go/tool/WordPress and StormLib updates wait for review.
- A merge under an image's directory **retriggers that image's publish workflow** — so a rebuild happens only when something actually changed.

---

## ➕ Adding an image

1. Create a directory `‹name›/` containing:
   - `Dockerfile` (digest-pinned `FROM`; pin deps via a manifest like `requirements.txt`)
   - `test.sh ‹image›` — a smoke test (build is invoked by CI; script receives the tag)
   - `.dockerignore`
2. Add a publish workflow `.github/workflows/‹name›.yml` (copy an existing one; set `IMAGE_NAME`, `paths`, `context`).
3. Add `‹name›` to the `container` matrix in `.github/workflows/ci.yml`.
