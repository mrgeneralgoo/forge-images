FROM ghcr.io/openclaw/openclaw:latest@sha256:c440a75f5580acb135409068f39ca701a5ca10fb9892cd9473a60ba0669cc0dc

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
