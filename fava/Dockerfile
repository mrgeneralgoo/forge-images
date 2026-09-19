FROM python:3.14-slim@sha256:caaf356f40667c496d405780745b9ac25771c189a51dfcc42430d531ea09f8a2
ARG VCS_REF=unknown

# Keep every Python dependency in one application environment. The image has
# no global pip install, so downstream applications can inherit /opt/venv
# without accidentally carrying a second copy of Fava.
COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt \
    && useradd --create-home --shell /usr/sbin/nologin fava \
    && mkdir -p /opt/fava \
    && /opt/venv/bin/pip freeze > /opt/fava/requirements-installed.txt \
    && chown -R fava:fava /opt/fava

# Baked, importable WSGI entrypoint: --preload copy-on-write ledger sharing,
# a BQL parse cache, and URL-prefix handling. Lives outside /data so a mounted
# ledger can never shadow it.
WORKDIR /opt/fava
COPY --chown=fava:fava fava_wsgi.py /opt/fava/fava_wsgi.py

# HOME=/tmp so gunicorn's control socket is writable even when the container is
# run as a non-root UID (e.g. to match a bind-mounted ledger's owner).
ENV VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp \
    FAVA_WORKERS=3 \
    FAVA_BEANFILE=/data/main.bean \
    FAVA_PREFIX=/fava

EXPOSE 8000

LABEL org.opencontainers.image.title="Fava" \
      org.opencontainers.image.description="Fava and fava-dashboards served by preloaded multi-process Gunicorn." \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}"

USER fava

# --preload: parse the ledger once in the master, workers inherit it via CoW.
# --timeout 120: a heavy BQL query on a slow board can take several seconds.
# The command is intentionally overridable: a downstream image can replace it
# without importing this module or starting the default Fava server.
CMD ["sh", "-c", "exec gunicorn --preload -w ${FAVA_WORKERS:-3} --timeout 120 -b 0.0.0.0:8000 fava_wsgi:app"]
