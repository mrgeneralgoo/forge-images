# Fava

[Fava](https://beancount.github.io/fava/) and `fava-dashboards` served by
multi-process Gunicorn. The image is intended for dashboards whose concurrent
BQL requests benefit from multiple processes rather than a thread-only server.

## Images

```text
ghcr.io/mrgeneralgoo/fava
docker.io/mrgeneralgoo/fava
```

Architectures: `linux/amd64`, `linux/arm64`.

## Runtime behavior

- Gunicorn uses preloaded worker processes for real multi-core execution.
- The ledger is loaded before workers fork, allowing copy-on-write sharing.
- The WSGI entrypoint supports a configurable URL prefix.
- Repeated BQL parsing uses a bounded in-process cache when the compatible
  Beanquery API is available.
- `HOME=/tmp` permits operation under a non-root UID matching a bind mount.

## Usage

```bash
docker run -d \
  --name fava \
  --user 1000:1000 \
  -v ./ledger:/data:ro \
  -e FAVA_BEANFILE=/data/main.bean \
  -e FAVA_PREFIX=/fava \
  -e FAVA_WORKERS=3 \
  -p 5000:5000 \
  ghcr.io/mrgeneralgoo/fava@sha256:<digest>
```

| Variable | Default | Purpose |
|---|---|---|
| `FAVA_BEANFILE` | `/data/main.bean` | Root Beancount file |
| `FAVA_PREFIX` | `/fava` | URL mount prefix; use an empty value for `/` |
| `FAVA_WORKERS` | `3` | Gunicorn worker processes |

Keep the worker count modest on low-power systems. The ledger directory is a
runtime bind mount and is not included in the image.

## Dependencies

Direct Python package versions are pinned in `requirements.txt` and updated by
Renovate. The base Python image is pinned by digest. The WSGI entrypoint is
stored outside `/data`, so a mounted ledger cannot shadow it.

## Local test

```bash
docker buildx build --platform linux/amd64 --load -t test-fava fava
./fava/test.sh test-fava
```

The smoke test verifies Python imports and Gunicorn, then boots the service with
a minimal ledger and waits for an HTTP response under the configured prefix.
