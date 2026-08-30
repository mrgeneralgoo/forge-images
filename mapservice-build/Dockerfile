# renovate: datasource=github-tags depName=ladislav-zezula/StormLib
ARG STORMLIB_VERSION=v9.40
ARG STORMLIB_COMMIT=6bb1882bd00ddbc3729cac5dac0fda81a61e5514
ARG STORMLIB_ARCHIVE_SHA256=f584f35edf9cb7f5e6adc65ee467ddfcf5f5b2d06445a0b6a3f274755d9e8484

ARG GO_VERSION=1.27.0
ARG GO_COMMIT=8af21751f066eced273ca3ce49506b366847c623
ARG GO_ARCHIVE_SHA256=55e877061912c5bcf526719c4d76936e19bf2d3b687dd4b5a76590cd6d3f2b96

ARG SQLC_VERSION=1.31.1
ARG SQLC_COMMIT=a95e91d70ad9e1181253c333a1cfdd75ae4b95a5
ARG SQLC_ARCHIVE_SHA256=f0c87c96059123cb7fef9ae03f6fbb5185a830f7b78c64220b5f166d3ce51d70

ARG GOLANGCI_VERSION=v2.13.2
ARG GOLANGCI_COMMIT=27774aaf853a4fd21f1dd5e69439459dc1b26e68
ARG GOLANGCI_ARCHIVE_SHA256=ef31ff6f9c278cbbf6e813c1d61eb683ee8a1f79050ce259d08a3b16b4d65642

FROM sqlc/sqlc:1.31.1@sha256:70f53171d27b2424e9358869975455a6e955a5aa8e58a998a270a6e34e525537 AS sqlc
FROM golangci/golangci-lint:v2.13.2@sha256:ba07dffad130794ae79ebaa0056809d18c0168f3f846480ffd3eb6c04578b83d AS golangci

FROM golang:1.27.0-trixie@sha256:ae28539d2ef595b9a2930dd7f031d9592376829dc0eae7cb869559f7d5812c3a AS go-distribution

FROM go-distribution AS upstream-source
ARG STORMLIB_VERSION
ARG STORMLIB_COMMIT
ARG STORMLIB_ARCHIVE_SHA256
ARG GO_VERSION
ARG GO_COMMIT
ARG GO_ARCHIVE_SHA256
ARG SQLC_VERSION
ARG SQLC_COMMIT
ARG SQLC_ARCHIVE_SHA256
ARG GOLANGCI_VERSION
ARG GOLANGCI_COMMIT
ARG GOLANGCI_ARCHIVE_SHA256

RUN set -eux; \
    mkdir -p /tmp/upstream/go \
             /tmp/upstream/sqlc \
             /tmp/upstream/golangci-lint \
             /tmp/upstream/stormlib \
             /tmp/metadata/go \
             /tmp/metadata/sqlc \
             /tmp/metadata/golangci-lint \
             /tmp/metadata/stormlib; \
    for commit in "${GO_COMMIT}" "${SQLC_COMMIT}" "${GOLANGCI_COMMIT}" "${STORMLIB_COMMIT}"; do \
      printf '%s\n' "${commit}" | grep -Eq '^[0-9a-f]{40}$'; \
    done; \
    for checksum in "${GO_ARCHIVE_SHA256}" "${SQLC_ARCHIVE_SHA256}" "${GOLANGCI_ARCHIVE_SHA256}" "${STORMLIB_ARCHIVE_SHA256}"; do \
      printf '%s\n' "${checksum}" | grep -Eq '^[0-9a-f]{64}$'; \
    done; \
    go_archive=/tmp/go.tar.gz; \
    sqlc_archive=/tmp/sqlc.tar.gz; \
    golangci_archive=/tmp/golangci-lint.tar.gz; \
    stormlib_archive=/tmp/stormlib.tar.gz; \
    curl --fail --silent --show-error --location --retry 3 \
      "https://codeload.github.com/golang/go/tar.gz/${GO_COMMIT}" \
      --output "${go_archive}"; \
    printf '%s  %s\n' "${GO_ARCHIVE_SHA256}" "${go_archive}" | sha256sum --check --status; \
    tar --extract --gzip --file "${go_archive}" --strip-components=1 --directory /tmp/upstream/go; \
    grep -Fxq "go${GO_VERSION}" /tmp/upstream/go/VERSION; \
    test -s /tmp/upstream/go/LICENSE; \
    test -s /tmp/upstream/go/PATENTS; \
    curl --fail --silent --show-error --location --retry 3 \
      "https://codeload.github.com/sqlc-dev/sqlc/tar.gz/${SQLC_COMMIT}" \
      --output "${sqlc_archive}"; \
    printf '%s  %s\n' "${SQLC_ARCHIVE_SHA256}" "${sqlc_archive}" | sha256sum --check --status; \
    tar --extract --gzip --file "${sqlc_archive}" --strip-components=1 --directory /tmp/upstream/sqlc; \
    test -s /tmp/upstream/sqlc/LICENSE; \
    curl --fail --silent --show-error --location --retry 3 \
      "https://codeload.github.com/golangci/golangci-lint/tar.gz/${GOLANGCI_COMMIT}" \
      --output "${golangci_archive}"; \
    printf '%s  %s\n' "${GOLANGCI_ARCHIVE_SHA256}" "${golangci_archive}" | sha256sum --check --status; \
    tar --extract --gzip --file "${golangci_archive}" --strip-components=1 --directory /tmp/upstream/golangci-lint; \
    test -s /tmp/upstream/golangci-lint/LICENSE; \
    curl --fail --silent --show-error --location --retry 3 \
      "https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/${STORMLIB_COMMIT}" \
      --output "${stormlib_archive}"; \
    printf '%s  %s\n' "${STORMLIB_ARCHIVE_SHA256}" "${stormlib_archive}" | sha256sum --check --status; \
    tar --extract --gzip --file "${stormlib_archive}" --strip-components=1 --directory /tmp/upstream/stormlib; \
    grep -Fq "STORMLIB_VERSION_STRING         \"${STORMLIB_VERSION#v}\"" /tmp/upstream/stormlib/src/StormLib.h; \
    test -s /tmp/upstream/stormlib/LICENSE; \
    cp "${golangci_archive}" /tmp/metadata/golangci-lint/source.tar.gz; \
    printf '%s\n' \
      'Name: Go toolchain' \
      "Version: ${GO_VERSION}" \
      'License: BSD-3-Clause' \
      "Source URL: https://codeload.github.com/golang/go/tar.gz/${GO_COMMIT}" \
      "Source tag: go${GO_VERSION}" \
      "Source commit: ${GO_COMMIT}" \
      "Source archive SHA256: ${GO_ARCHIVE_SHA256}" \
      'Binary distribution: golang:1.27.0-trixie@sha256:ae28539d2ef595b9a2930dd7f031d9592376829dc0eae7cb869559f7d5812c3a' \
      > /tmp/metadata/go/PROVENANCE; \
    printf '%s\n' \
      'Name: sqlc' \
      "Version: ${SQLC_VERSION}" \
      'License: MIT' \
      "Source URL: https://codeload.github.com/sqlc-dev/sqlc/tar.gz/${SQLC_COMMIT}" \
      "Source tag: v${SQLC_VERSION}" \
      "Source commit: ${SQLC_COMMIT}" \
      "Source archive SHA256: ${SQLC_ARCHIVE_SHA256}" \
      'Binary distribution: sqlc/sqlc:1.31.1@sha256:70f53171d27b2424e9358869975455a6e955a5aa8e58a998a270a6e34e525537' \
      > /tmp/metadata/sqlc/PROVENANCE; \
    printf '%s\n' \
      'Name: golangci-lint' \
      "Version: ${GOLANGCI_VERSION}" \
      'License: GPL-3.0' \
      "Source URL: https://codeload.github.com/golangci/golangci-lint/tar.gz/${GOLANGCI_COMMIT}" \
      "Source tag: ${GOLANGCI_VERSION}" \
      "Source commit: ${GOLANGCI_COMMIT}" \
      "Source archive SHA256: ${GOLANGCI_ARCHIVE_SHA256}" \
      'Corresponding source: /usr/share/source/golangci-lint/source.tar.gz' \
      'Binary distribution: golangci/golangci-lint:v2.13.2@sha256:ba07dffad130794ae79ebaa0056809d18c0168f3f846480ffd3eb6c04578b83d' \
      > /tmp/metadata/golangci-lint/PROVENANCE; \
    printf '%s\n' \
      'Name: StormLib' \
      "Version: ${STORMLIB_VERSION}" \
      'License: MIT' \
      "Source URL: https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/${STORMLIB_COMMIT}" \
      "Source tag: ${STORMLIB_VERSION}" \
      "Source commit: ${STORMLIB_COMMIT}" \
      "Source archive SHA256: ${STORMLIB_ARCHIVE_SHA256}" \
      'Build: source-built with CMake; no application source is copied' \
      > /tmp/metadata/stormlib/PROVENANCE; \
    rm -f "${go_archive}" "${sqlc_archive}" "${stormlib_archive}"

FROM go-distribution AS stormlib-builder

COPY --from=upstream-source /tmp/upstream/stormlib /tmp/stormlib
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends cmake; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /tmp/stormlib-build; \
    cmake -S /tmp/stormlib -B /tmp/stormlib-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/stormlib \
      -DBUILD_SHARED_LIBS=ON \
      -DSTORM_USE_BUNDLED_LIBRARIES=ON \
      -DSTORM_BUILD_TESTS=OFF; \
    cmake --build /tmp/stormlib-build --parallel; \
    cmake --install /tmp/stormlib-build; \
    test -s /opt/stormlib/lib/libstorm.so

FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
ARG VCS_REF=unknown
ARG STORMLIB_VERSION
ARG STORMLIB_COMMIT
ARG STORMLIB_ARCHIVE_SHA256
ARG GO_VERSION
ARG GO_COMMIT
ARG GO_ARCHIVE_SHA256
ARG SQLC_VERSION
ARG SQLC_COMMIT
ARG SQLC_ARCHIVE_SHA256
ARG GOLANGCI_VERSION
ARG GOLANGCI_COMMIT
ARG GOLANGCI_ARCHIVE_SHA256

ENV PATH=/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GOLANG_VERSION=${GO_VERSION} \
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
COPY --from=golangci /usr/bin/golangci-lint /usr/local/bin/golangci-lint
COPY --from=stormlib-builder /opt/stormlib/ /usr/local/
COPY --from=upstream-source /tmp/upstream/go/LICENSE /usr/share/doc/go/LICENSE
COPY --from=upstream-source /tmp/upstream/go/PATENTS /usr/share/doc/go/PATENTS
COPY --from=upstream-source /tmp/metadata/go/PROVENANCE /usr/share/doc/go/PROVENANCE
COPY --from=upstream-source /tmp/upstream/sqlc/LICENSE /usr/share/doc/sqlc/LICENSE
COPY --from=upstream-source /tmp/metadata/sqlc/PROVENANCE /usr/share/doc/sqlc/PROVENANCE
COPY --from=upstream-source /tmp/upstream/golangci-lint/LICENSE /usr/share/doc/golangci-lint/LICENSE
COPY --from=upstream-source /tmp/metadata/golangci-lint/PROVENANCE /usr/share/doc/golangci-lint/PROVENANCE
COPY --from=upstream-source /tmp/metadata/golangci-lint/source.tar.gz /usr/share/source/golangci-lint/source.tar.gz
COPY --from=upstream-source /tmp/upstream/stormlib/LICENSE /usr/share/doc/stormlib/LICENSE
COPY --from=upstream-source /tmp/metadata/stormlib/PROVENANCE /usr/share/doc/stormlib/PROVENANCE
COPY NOTICE.md /usr/share/doc/mapservice-build/NOTICE.md

USER root
RUN set -eux; \
    printf '/usr/local/lib\n' > /etc/ld.so.conf.d/stormlib.conf; \
    ldconfig

WORKDIR /go

LABEL org.opencontainers.image.title="Go and StormLib build environment" \
      org.opencontainers.image.description="Pinned Go build environment with source-built StormLib, sqlc, and golangci-lint." \
      org.opencontainers.image.licenses="Apache-2.0 AND BSD-3-Clause AND GPL-3.0-only AND MIT" \
      org.opencontainers.image.version="${GO_VERSION}" \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}" \
      io.forge-images.go.commit="${GO_COMMIT}" \
      io.forge-images.go.archive-sha256="${GO_ARCHIVE_SHA256}" \
      io.forge-images.sqlc.commit="${SQLC_COMMIT}" \
      io.forge-images.sqlc.archive-sha256="${SQLC_ARCHIVE_SHA256}" \
      io.forge-images.golangci-lint.commit="${GOLANGCI_COMMIT}" \
      io.forge-images.golangci-lint.archive-sha256="${GOLANGCI_ARCHIVE_SHA256}" \
      io.forge-images.stormlib.commit="${STORMLIB_COMMIT}" \
      io.forge-images.stormlib.archive-sha256="${STORMLIB_ARCHIVE_SHA256}"
