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
