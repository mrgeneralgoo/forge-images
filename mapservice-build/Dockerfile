# StormLib is built from source, so its commit and archive checksum stay pinned
# here. Renovate tracks the release tag; update-stormlib-pin.sh rewrites all
# three values together.
# renovate: datasource=github-tags depName=ladislav-zezula/StormLib
ARG STORMLIB_VERSION=v9.40
ARG STORMLIB_COMMIT=6bb1882bd00ddbc3729cac5dac0fda81a61e5514
ARG STORMLIB_ARCHIVE_SHA256=f584f35edf9cb7f5e6adc65ee467ddfcf5f5b2d06445a0b6a3f274755d9e8484

# Upstream images: floating tag for tracking, digest for reproducibility. Each
# digest literal appears exactly once, so a Renovate digest bump is a one-line
# change with nothing else to keep in sync.
ARG GO_REF=golang:trixie@sha256:9baa6b4187bbb98d240372a8a235ac0bb6b5ddd52bba1431dc2f7c0705862728
ARG SQLC_REF=sqlc/sqlc:latest@sha256:70f53171d27b2424e9358869975455a6e955a5aa8e58a998a270a6e34e525537
ARG DEBIAN_REF=debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

FROM ${SQLC_REF} AS sqlc

FROM ${GO_REF} AS go-distribution

# StormLib is fetched and compiled inside the very image the runtime stage uses,
# not merely inside another image with the same Debian codename. GO_REF and
# DEBIAN_REF are independent pins that Renovate updates separately, so building
# in the Go image could link the shared object against a newer glibc than the
# runtime actually ships.
FROM ${DEBIAN_REF} AS stormlib-builder
ARG STORMLIB_VERSION
ARG STORMLIB_COMMIT
ARG STORMLIB_ARCHIVE_SHA256

RUN set -eux; \
    printf '%s\n' "${STORMLIB_COMMIT}" | grep -Eq '^[0-9a-f]{40}$'; \
    printf '%s\n' "${STORMLIB_ARCHIVE_SHA256}" | grep -Eq '^[0-9a-f]{64}$'; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      cmake \
      curl \
      g++ \
      gcc \
      libbz2-dev \
      make \
      zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /tmp/upstream/stormlib /tmp/stormlib-build; \
    archive=/tmp/stormlib.tar.gz; \
    curl --fail --silent --show-error --location --retry 3 \
      "https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/${STORMLIB_COMMIT}" \
      --output "${archive}"; \
    printf '%s  %s\n' "${STORMLIB_ARCHIVE_SHA256}" "${archive}" | sha256sum --check --status; \
    tar --extract --gzip --file "${archive}" --strip-components=1 --directory /tmp/upstream/stormlib; \
    grep -Fq "STORMLIB_VERSION_STRING         \"${STORMLIB_VERSION#v}\"" /tmp/upstream/stormlib/src/StormLib.h; \
    test -s /tmp/upstream/stormlib/LICENSE; \
    rm -f "${archive}"; \
    cmake -S /tmp/upstream/stormlib -B /tmp/stormlib-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/stormlib \
      -DBUILD_SHARED_LIBS=ON \
      -DSTORM_USE_BUNDLED_LIBRARIES=ON \
      -DSTORM_BUILD_TESTS=OFF; \
    cmake --build /tmp/stormlib-build --parallel; \
    cmake --install /tmp/stormlib-build; \
    test -s /opt/stormlib/lib/libstorm.so

FROM ${DEBIAN_REF}
ARG GO_REF
ARG SQLC_REF
ARG STORMLIB_VERSION
ARG VCS_REF=unknown

ENV PATH=/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GOTOOLCHAIN=local \
    GOPATH=/go

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      gcc \
      git \
      libc6-dev \
      libbz2-dev \
      zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p "$GOPATH/src" "$GOPATH/bin"; \
    chmod -R 1777 "$GOPATH"

COPY --from=go-distribution /usr/local/go/ /usr/local/go/
COPY --from=sqlc /workspace/sqlc /usr/local/bin/sqlc
COPY --from=stormlib-builder /opt/stormlib/ /usr/local/

# Go ships LICENSE and PATENTS inside the official distribution, and StormLib's
# LICENSE comes from the source tree it is built from. sqlc's image is a scratch
# image with no license file, so its MIT text is vendored in this repository.
COPY --from=go-distribution /usr/local/go/LICENSE /usr/share/doc/go/LICENSE
COPY --from=go-distribution /usr/local/go/PATENTS /usr/share/doc/go/PATENTS
COPY --from=stormlib-builder /tmp/upstream/stormlib/LICENSE /usr/share/doc/stormlib/LICENSE
COPY licenses/sqlc-LICENSE /usr/share/doc/sqlc/LICENSE

USER root
RUN set -eux; \
    printf '/usr/local/lib\n' > /etc/ld.so.conf.d/stormlib.conf; \
    ldconfig

WORKDIR /go

LABEL org.opencontainers.image.title="Go and StormLib build environment" \
      org.opencontainers.image.description="Go build environment with source-built StormLib and sqlc." \
      org.opencontainers.image.licenses="Apache-2.0 AND BSD-3-Clause AND MIT" \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}" \
      io.forge-images.go.source-digest="${GO_REF##*@}" \
      io.forge-images.sqlc.source-digest="${SQLC_REF##*@}" \
      io.forge-images.stormlib.version="${STORMLIB_VERSION}"
