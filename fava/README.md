# Fava public base image

This image provides a general-purpose Fava runtime for Beancount ledgers. It is
also the public base inherited by the derived application; it contains
no application-specific code, configuration, credentials, or ledger data.

## Images

```text
ghcr.io/mrgeneralgoo/fava
docker.io/mrgeneralgoo/fava
```

Architectures: `linux/amd64`, `linux/arm64`.

## Runtime contract

- Python 3.14 and all Python packages are installed in the single `/opt/venv`.
- The image runs as a dynamically created non-root `fava` user; no host UID/GID
  is baked into the image.
- The default command uses preloaded multi-process Gunicorn. The ledger is
  parsed once before workers fork, and the WSGI entrypoint lives in `/opt/fava`
  rather than the `/data` mount.
- The command is an ordinary overridable `CMD`, not an entrypoint. A derived
  image can replace it with its own ASGI application without importing Fava or
  starting Gunicorn.
- The pinned Starlette, `a2wsgi`, and Uvicorn packages are available to derived
  services in the same `/opt/venv`.

## Default usage

```bash
docker run -d \
  --name fava \
  -v ./ledger:/data:ro \
  -e FAVA_BEANFILE=/data/main.bean \
  -e FAVA_PREFIX=/fava \
  -e FAVA_WORKERS=3 \
  -p 5000:5000 \
  ghcr.io/mrgeneralgoo/fava@sha256:<digest>
```

Open `http://localhost:5000/fava/`. The default root ledger is
`/data/main.bean` and the default HTTP prefix is `/fava`.

| Variable | Default | Purpose |
|---|---|---|
| `FAVA_BEANFILE` | `/data/main.bean` | Root Beancount file |
| `FAVA_PREFIX` | `/fava` | URL mount prefix; use an empty value for `/` |
| `FAVA_WORKERS` | `3` | Gunicorn worker processes |

The ledger is always supplied at runtime and is not included in the image.
Keep the worker count modest on low-power systems.

## Inheriting the base

The stable application interface is `/opt/venv/bin/python` and the executables
in `/opt/venv/bin`. The complete installed package list is recorded at
`/opt/fava/requirements-installed.txt` for downstream compatibility checks.
Derived images should install their additional dependencies into that same
environment and provide their own `CMD`, for example:

```dockerfile
FROM ghcr.io/mrgeneralgoo/fava@sha256:<digest>
COPY requirements-app.txt /tmp/requirements-app.txt
USER root
RUN /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements-app.txt
COPY app /opt/app
USER fava
CMD ["uvicorn", "--app-dir", "/opt/app", "--host", "0.0.0.0", "--port", "8000", "app:app"]
```

There is no boot-time package installation, application hook, or multi-service
supervisor. Public build contexts must contain only generic runtime inputs.

## Dependencies and local test

Direct versions are pinned in `requirements.txt`; the Python base image is
pinned by digest. The smoke test uses a synthetic ledger to verify the real Fava
page and a GET BQL query, checks the single virtual environment, and replaces
`CMD` with a temporary `a2wsgi`/Uvicorn service to verify that no default
Gunicorn process starts.

```bash
docker buildx build --platform linux/amd64 --load -t test-fava fava
./fava/test.sh test-fava
```
