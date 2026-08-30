# dae (daeuniverse eBPF transparent proxy) plus a self-contained, in-container
# rule/GeoData auto-update loop. Built on the pinned official image (alpine
# based), so the running dae is the exact upstream binary — nothing to keep in
# sync. The updater reloads dae locally (same container, same PID namespace,
# same /var/run): no host systemd, no Docker socket, no shared volumes.
#
# Personal data stays out of the image and is mounted at runtime:
#   - /etc/dae            the dae runtime (config.dae + its includes + geo data)
#   - /config/rule-providers.json  the personal rule-source manifest (read-only)
# Both paths are overridable via DAE_RUNTIME / DAE_RULE_MANIFEST.
#
# The FROM digest is pinned; Renovate opens bump PRs.
FROM daeuniverse/dae:latest@sha256:e9c8bf973e0f2a746503efa654248f2c4edc00d9fc3c3b33829a9c732d93bb37
ARG VCS_REF=unknown

# The base image ships only busybox sh + wget; add the updater toolchain.
RUN apk add --no-cache curl python3 tini coreutils

WORKDIR /opt/dae
COPY lib/ ./lib/
COPY convert-rules.py update-rules.sh update-geo.sh ./
COPY entrypoint.sh run-job.sh /usr/local/bin/
COPY crontab /etc/crontabs/root
RUN chmod +x update-rules.sh update-geo.sh \
        /usr/local/bin/entrypoint.sh /usr/local/bin/run-job.sh

# Defaults; override any with `-e` at run time. DAE_OPS_LOCAL makes
# lib/dae-ops.sh validate/reload against the local dae binary.
ENV DAE_OPS_LOCAL=1 \
    DAE_RUNTIME=/etc/dae \
    DAE_RULE_MANIFEST=/config/rule-providers.json \
    DAE_CURL=curl

LABEL org.opencontainers.image.title="dae with managed rules" \
      org.opencontainers.image.description="Pinned dae runtime with in-container rule and GeoData updates." \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}"

# tini as PID 1 reaps the daemon plus the crond/curl/python3 update children.
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
