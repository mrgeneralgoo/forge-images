FROM ghcr.io/openclaw/openclaw:latest@sha256:2f5ce8848a1a69b3c460622e566cb9395da9fd18d7ef7b038cd8e2c4f195decf

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
