FROM ghcr.io/openclaw/openclaw:latest@sha256:b12f76a7947e4cdd328bf3ea1045d41a5494b33852c911e9bc4fdd03dde469d5

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
