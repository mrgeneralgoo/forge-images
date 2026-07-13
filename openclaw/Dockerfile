FROM ghcr.io/openclaw/openclaw:latest@sha256:6a31d44b2944e7adcd2b582bf6fb463111264ebca97a0201795b799135bd102c

# Skill / agent dependencies layered on top of the upstream openclaw image.
# Each tool gets its own RUN line + renovate annotation so renovate can pin
# and bump versions independently.

USER root

# defuddle: HTML→markdown extractor used by jarvis skills/defuddle
# renovate: datasource=npm depName=defuddle
RUN npm install -g defuddle@0.18.1

# Restore the upstream non-root user so the gateway keeps its original
# security posture. Don't run as root by accident.
USER node
