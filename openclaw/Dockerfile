FROM ghcr.io/openclaw/openclaw:latest@sha256:9f55f0cb32b2925a983f40726440189b8f422ec61ae2a0fb0cf90403cf6d63d7

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
