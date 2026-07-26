# forge-images

🚢 A curated collection of Docker images for building, running, and shipping software reliably.

This repository focuses on **reusable, maintainable, and reproducible** Docker images designed for development, CI/CD, and production environments.

All images are built **multi-arch (`linux/amd64` + `linux/arm64`)** and published to both GitHub Container Registry and Docker Hub.

---

## 📦 Images

| Image | Pull | Description |
|-------|------|-------------|
| **fava** | `ghcr.io/mrgeneralgoo/fava` · `mrgeneralgoo/fava` | [Fava](https://beancount.github.io/fava/) (Beancount browser) served by gunicorn for real multi-core BQL queries. Baked WSGI entrypoint with `--preload` copy-on-write ledger sharing, a BQL parse cache, and URL-prefix support. |
| **pkm-mcp** | `ghcr.io/mrgeneralgoo/pkm-mcp` · `mrgeneralgoo/pkm-mcp` | Node.js base for a PKM MCP server: git, ripgrep, and native-module build deps (python3 + build-essential) preinstalled. |
| **openclaw** | `ghcr.io/mrgeneralgoo/openclaw` · `mrgeneralgoo/openclaw` | Skill/agent tooling layered on the upstream `openclaw` image, each tool pinned and bumped independently by Renovate. |
| **frankenphp** | `ghcr.io/mrgeneralgoo/frankenphp` · `mrgeneralgoo/frankenphp` | serversideup PHP 8.5 (FrankenPHP) with a curated set of PHP extensions (redis, imagick, gd, intl, bcmath, …). |
| **dae** | `ghcr.io/mrgeneralgoo/dae` · `mrgeneralgoo/dae` | [dae](https://github.com/daeuniverse/dae) (eBPF transparent proxy) on the pinned upstream image plus a self-contained in-container rule/GeoData auto-update loop (busybox crond + local `dae reload`). Personal config and the rule-source manifest are bind-mounted, never baked. |

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
personal data ever lands in the published image. dae needs a Linux host with
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
      - ./rule-providers.json:/config/rule-providers.json:ro  # personal rule sources
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
- Every PR is **smoke-tested in CI** (`.github/workflows/ci.yml` runs each image's `test.sh`); minor/patch updates auto-merge, majors wait for review.
- A merge under an image's directory **retriggers that image's publish workflow** — so a rebuild happens only when something actually changed.

---

## ➕ Adding an image

1. Create a directory `‹name›/` containing:
   - `Dockerfile` (digest-pinned `FROM`; pin deps via a manifest like `requirements.txt`)
   - `test.sh ‹image›` — a smoke test (build is invoked by CI; script receives the tag)
   - `.dockerignore`
2. Add a publish workflow `.github/workflows/‹name›.yml` (copy an existing one; set `IMAGE_NAME`, `paths`, `context`).
3. Add `‹name›` to the `container` matrix in `.github/workflows/ci.yml`.
