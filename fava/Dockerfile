FROM python:3.14-slim@sha256:cae66f2ef0ec51a9891263eeee7f987dacf0a9879e8aa9353d5606e0530619a5

# Fava + fava-dashboards served by gunicorn. See fava_wsgi.py for why gunicorn
# (multi-process → real multi-core for the CPU-bound BQL queries dashboards
# fire) rather than the thread-based `fava` CLI.
# Versions are pinned in requirements.txt; Renovate opens bump PRs (CI
# smoke-tests each before auto-merge), which retrigger the publish workflow.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Baked, importable WSGI entrypoint: --preload copy-on-write ledger sharing,
# a BQL parse cache, and URL-prefix handling. Lives outside /data so a mounted
# ledger can never shadow it.
WORKDIR /opt/fava
COPY fava_wsgi.py /opt/fava/fava_wsgi.py

# HOME=/tmp so gunicorn's control socket is writable even when the container is
# run as a non-root UID (e.g. to match a bind-mounted ledger's owner).
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/opt/fava \
    HOME=/tmp \
    FAVA_WORKERS=3 \
    FAVA_BEANFILE=/data/main.bean \
    FAVA_PREFIX=/fava

EXPOSE 5000

# --preload: parse the ledger once in the master, workers inherit it via CoW.
# --timeout 120: a heavy BQL query on a slow board can take several seconds.
CMD ["sh", "-c", "gunicorn --preload -w ${FAVA_WORKERS:-3} --timeout 120 -b 0.0.0.0:5000 fava_wsgi:app"]
