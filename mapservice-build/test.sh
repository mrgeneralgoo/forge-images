#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile

pin() {
  awk -v key="$1" '$1 == "ARG" && index($2, key "=") == 1 { sub("^[^=]+=", "", $2); print $2; exit }' "$dockerfile"
}

expected_stormlib_version=$(pin STORMLIB_VERSION)
expected_stormlib_commit=$(pin STORMLIB_COMMIT)
expected_stormlib_sha=$(pin STORMLIB_ARCHIVE_SHA256)
expected_go_version=$(pin GO_VERSION)
expected_go_commit=$(pin GO_COMMIT)
expected_go_sha=$(pin GO_ARCHIVE_SHA256)
expected_sqlc_version=$(pin SQLC_VERSION)
expected_sqlc_commit=$(pin SQLC_COMMIT)
expected_sqlc_sha=$(pin SQLC_ARCHIVE_SHA256)
expected_golangci_version=$(pin GOLANGCI_VERSION)
expected_golangci_commit=$(pin GOLANGCI_COMMIT)
expected_golangci_sha=$(pin GOLANGCI_ARCHIVE_SHA256)

if ! [[ "$expected_stormlib_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "invalid StormLib version pin" >&2
  exit 1
fi
if ! [[ "$expected_go_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid Go version pin" >&2
  exit 1
fi
if ! [[ "$expected_sqlc_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid sqlc version pin" >&2
  exit 1
fi
if ! [[ "$expected_golangci_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid golangci-lint version pin" >&2
  exit 1
fi

for commit in \
  "$expected_stormlib_commit" \
  "$expected_go_commit" \
  "$expected_sqlc_commit" \
  "$expected_golangci_commit"; do
  if ! [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo "invalid source commit pin" >&2
    exit 1
  fi
done
for sha in \
  "$expected_stormlib_sha" \
  "$expected_go_sha" \
  "$expected_sqlc_sha" \
  "$expected_golangci_sha"; do
  if ! [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "invalid source archive checksum pin" >&2
    exit 1
  fi
done

for text in \
  'FROM golang:1.27.0-trixie@sha256:ae28539d2ef595b9a2930dd7f031d9592376829dc0eae7cb869559f7d5812c3a AS go-distribution' \
  'COPY --from=go-distribution /usr/local/go/ /usr/local/go/' \
  'FROM sqlc/sqlc:1.31.1@sha256:70f53171d27b2424e9358869975455a6e955a5aa8e58a998a270a6e34e525537' \
  'FROM golangci/golangci-lint:v2.13.2@sha256:ba07dffad130794ae79ebaa0056809d18c0168f3f846480ffd3eb6c04578b83d' \
  'Binary distribution: golangci/golangci-lint:v2.13.2@sha256:ba07dffad130794ae79ebaa0056809d18c0168f3f846480ffd3eb6c04578b83d' \
  'AS upstream-source' \
  'COPY --from=upstream-source /tmp/upstream/go/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/go/PROVENANCE' \
  'COPY --from=upstream-source /tmp/upstream/sqlc/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/sqlc/PROVENANCE' \
  'COPY --from=upstream-source /tmp/upstream/golangci-lint/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/golangci-lint/PROVENANCE' \
  'COPY --from=upstream-source /tmp/upstream/stormlib/LICENSE' \
  'COPY --from=upstream-source /tmp/metadata/stormlib/PROVENANCE' \
  'org.opencontainers.image.licenses="Apache-2.0 AND BSD-3-Clause AND GPL-3.0-only AND MIT"'; do
  grep -F "$text" "$dockerfile" >/dev/null
done

grep -Eq '^FROM debian:trixie-slim@sha256:[0-9a-f]{64}$' "$dockerfile"

for key in \
  STORMLIB_VERSION STORMLIB_COMMIT STORMLIB_ARCHIVE_SHA256 \
  GO_VERSION GO_COMMIT GO_ARCHIVE_SHA256 \
  SQLC_VERSION SQLC_COMMIT SQLC_ARCHIVE_SHA256 \
  GOLANGCI_VERSION GOLANGCI_COMMIT GOLANGCI_ARCHIVE_SHA256; do
  grep -Eq "^ARG ${key}=" "$dockerfile"
done

if grep -Eq '^COPY --from=(sqlc|golangci)(:[^[:space:]]+)?[[:space:]]+.*(LICENSE|PROVENANCE)' "$dockerfile"; then
  echo "license or provenance copied from a tool image" >&2
  exit 1
fi
for text in \
  "ARG STORMLIB_VERSION=$expected_stormlib_version" \
  "ARG STORMLIB_COMMIT=$expected_stormlib_commit" \
  "ARG STORMLIB_ARCHIVE_SHA256=$expected_stormlib_sha" \
  "ARG GO_VERSION=$expected_go_version" \
  "ARG GO_COMMIT=$expected_go_commit" \
  "ARG GO_ARCHIVE_SHA256=$expected_go_sha" \
  "ARG SQLC_VERSION=$expected_sqlc_version" \
  "ARG SQLC_COMMIT=$expected_sqlc_commit" \
  "ARG SQLC_ARCHIVE_SHA256=$expected_sqlc_sha" \
  "ARG GOLANGCI_VERSION=$expected_golangci_version" \
  "ARG GOLANGCI_COMMIT=$expected_golangci_commit" \
  "ARG GOLANGCI_ARCHIVE_SHA256=$expected_golangci_sha"; do
  grep -F "$text" "$dockerfile" >/dev/null
done

for url in \
  'https://codeload.github.com/golang/go/tar.gz/' \
  'https://codeload.github.com/sqlc-dev/sqlc/tar.gz/' \
  'https://codeload.github.com/golangci/golangci-lint/tar.gz/' \
  'https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/'; do
  grep -F "$url" "$dockerfile" >/dev/null
done

for checksum in \
  "$expected_go_sha" \
  "$expected_sqlc_sha" \
  "$expected_golangci_sha" \
  "$expected_stormlib_sha"; do
  grep -F "sha256sum --check --status" "$dockerfile" >/dev/null
  grep -F "$checksum" "$dockerfile" >/dev/null
done

test_updater_rollback() {
  local mode=$1
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  cp "$dockerfile" "$script_dir/update-stormlib-pin.sh" "$script_dir/NOTICE.md" "$script_dir/test.sh" "$fixture/"
  cp "$fixture/Dockerfile" "$fixture/Dockerfile.before"

  set +e
  env -u RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE \
    STORMLIB_UPDATE_TEST_COMMIT=1111111111111111111111111111111111111111 \
    STORMLIB_UPDATE_TEST_SHA256=2222222222222222222222222222222222222222222222222222222222222222 \
    STORMLIB_UPDATE_TEST_FAIL_AFTER_RENAME="$mode" \
    bash "$fixture/update-stormlib-pin.sh" v9.41 >/dev/null 2>&1
  local status=$?
  set -e

  if (( status == 0 )); then
    echo "StormLib updater failure injection unexpectedly succeeded: $mode" >&2
    exit 1
  fi
  cmp -s "$fixture/Dockerfile.before" "$fixture/Dockerfile"
  if find "$fixture" -maxdepth 1 -type f \
      \( -name '*.tmp.*' -o -name '*.backup.*' -o -name 'Dockerfile.new' \) \
      -print -quit | grep -q .; then
    echo "StormLib updater left transaction artifacts: $mode" >&2
    exit 1
  fi
  rm -rf "$fixture"
  trap - RETURN
}

for mode in exit term; do
  test_updater_rollback "$mode"
done

expected_stormlib_version_number=${expected_stormlib_version#v}
expected_arch=$(docker image inspect "$image" --format '{{.Architecture}}')
case "$expected_arch" in amd64|arm64) ;; *) echo "unexpected image architecture: $expected_arch" >&2; exit 1;; esac
docker run --rm \
  -e EXPECTED_ARCH="$expected_arch" \
  -e EXPECTED_STORMLIB_VERSION="$expected_stormlib_version_number" \
  -e EXPECTED_STORMLIB_COMMIT="$expected_stormlib_commit" \
  -e EXPECTED_STORMLIB_SHA="$expected_stormlib_sha" \
  -e EXPECTED_GO_VERSION="$expected_go_version" \
  -e EXPECTED_GO_COMMIT="$expected_go_commit" \
  -e EXPECTED_GO_SHA="$expected_go_sha" \
  -e EXPECTED_SQLC_VERSION="$expected_sqlc_version" \
  -e EXPECTED_SQLC_COMMIT="$expected_sqlc_commit" \
  -e EXPECTED_SQLC_SHA="$expected_sqlc_sha" \
  -e EXPECTED_GOLANGCI_VERSION="$expected_golangci_version" \
  -e EXPECTED_GOLANGCI_COMMIT="$expected_golangci_commit" \
  -e EXPECTED_GOLANGCI_SHA="$expected_golangci_sha" \
  --entrypoint sh "$image" -s <<'CHECK'
set -eu

export DEBIAN_FRONTEND=noninteractive

go version | grep -F "go$EXPECTED_GO_VERSION linux/$EXPECTED_ARCH"
test "$(dpkg --print-architecture)" = "$EXPECTED_ARCH"
sqlc version | grep -F "$EXPECTED_SQLC_VERSION"
golangci-lint --version | grep -F "${EXPECTED_GOLANGCI_VERSION#v}"
git --version
test -s /etc/ssl/certs/ca-certificates.crt

for package in ca-certificates gcc git libc6-dev libbz2-dev zlib1g-dev; do
  dpkg-query -W "$package" >/dev/null
 done
for package in cmake curl g++ gnupg make mercurial openssh-client pkg-config python3 subversion wget; do
  if dpkg-query -W "$package" >/dev/null 2>&1; then
    echo "unexpected package in slim build environment: $package" >&2
    exit 1
  fi
done

for file in /usr/share/doc/go/LICENSE \
            /usr/share/doc/go/PATENTS \
            /usr/share/doc/go/PROVENANCE \
            /usr/share/doc/sqlc/LICENSE \
            /usr/share/doc/sqlc/PROVENANCE \
            /usr/share/doc/golangci-lint/LICENSE \
            /usr/share/doc/golangci-lint/PROVENANCE \
            /usr/share/source/golangci-lint/source.tar.gz \
            /usr/share/doc/stormlib/LICENSE \
            /usr/share/doc/stormlib/PROVENANCE \
            /usr/share/doc/mapservice-build/NOTICE.md; do
  test -s "$file"
done

grep -F 'Copyright 2009 The Go Authors.' /usr/share/doc/go/LICENSE
grep -F 'MIT License' /usr/share/doc/sqlc/LICENSE
grep -F 'GNU GENERAL PUBLIC LICENSE' /usr/share/doc/golangci-lint/LICENSE
grep -F 'The MIT License (MIT)' /usr/share/doc/stormlib/LICENSE

grep -F "Source URL: https://codeload.github.com/golang/go/tar.gz/$EXPECTED_GO_COMMIT" \
  /usr/share/doc/go/PROVENANCE
grep -F "Source tag: go$EXPECTED_GO_VERSION" /usr/share/doc/go/PROVENANCE
grep -F "Source commit: $EXPECTED_GO_COMMIT" /usr/share/doc/go/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_GO_SHA" /usr/share/doc/go/PROVENANCE
grep -F "Source URL: https://codeload.github.com/sqlc-dev/sqlc/tar.gz/$EXPECTED_SQLC_COMMIT" \
  /usr/share/doc/sqlc/PROVENANCE
grep -F "Source tag: v$EXPECTED_SQLC_VERSION" /usr/share/doc/sqlc/PROVENANCE
grep -F "Source commit: $EXPECTED_SQLC_COMMIT" /usr/share/doc/sqlc/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_SQLC_SHA" /usr/share/doc/sqlc/PROVENANCE
grep -F "Source URL: https://codeload.github.com/golangci/golangci-lint/tar.gz/$EXPECTED_GOLANGCI_COMMIT" \
  /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source tag: $EXPECTED_GOLANGCI_VERSION" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source commit: $EXPECTED_GOLANGCI_COMMIT" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_GOLANGCI_SHA" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "Source URL: https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/$EXPECTED_STORMLIB_COMMIT" \
  /usr/share/doc/stormlib/PROVENANCE
grep -F "Source tag: v$EXPECTED_STORMLIB_VERSION" /usr/share/doc/stormlib/PROVENANCE
grep -F "Source commit: $EXPECTED_STORMLIB_COMMIT" /usr/share/doc/stormlib/PROVENANCE
grep -F "Source archive SHA256: $EXPECTED_STORMLIB_SHA" /usr/share/doc/stormlib/PROVENANCE

grep -F "License: BSD-3-Clause" /usr/share/doc/go/PROVENANCE
grep -F "License: MIT" /usr/share/doc/sqlc/PROVENANCE
grep -F "License: GPL-3.0" /usr/share/doc/golangci-lint/PROVENANCE
grep -F "golangci-lint $EXPECTED_GOLANGCI_VERSION" /usr/share/doc/mapservice-build/NOTICE.md
grep -F "License: MIT" /usr/share/doc/stormlib/PROVENANCE
printf '%s  %s\n' "$EXPECTED_GOLANGCI_SHA" /usr/share/source/golangci-lint/source.tar.gz | sha256sum --check --status
tar -tzf /usr/share/source/golangci-lint/source.tar.gz | grep -Eq '/LICENSE$'
grep -F 'Corresponding source: /usr/share/source/golangci-lint/source.tar.gz' \
  /usr/share/doc/golangci-lint/PROVENANCE

test -s /usr/local/lib/libstorm.so
test -s /usr/local/include/StormLib.h
ldd /usr/local/lib/libstorm.so
grep -F "STORMLIB_VERSION_STRING         \"$EXPECTED_STORMLIB_VERSION\"" \
  /usr/local/include/StormLib.h
smoke_root=$(mktemp -d)
mkdir "$smoke_root/storm"
cat > "$smoke_root/storm/go.mod" <<'EOF'
module smoke.invalid/storm

go 1.27
EOF
cat > "$smoke_root/storm/main.go" <<'EOF'
package main

/*
#cgo CFLAGS: -I/usr/local/include
#cgo LDFLAGS: -L/usr/local/lib -Wl,-rpath,/usr/local/lib -lstorm
#include <StormLib.h>
static const char *stormVersion(void) { return STORMLIB_VERSION_STRING; }
*/
import "C"

func main() {
	if C.GoString(C.stormVersion())[0] != '9' {
		panic("unexpected StormLib version")
	}
}
EOF
(
  cd "$smoke_root/storm"
  CGO_ENABLED=1 go build -o storm-smoke .
  ./storm-smoke
)

mkdir "$smoke_root/proxy"
cat > "$smoke_root/proxy/main.go" <<'EOF'
package main

import (
	"net"
	"net/http"
	"os"
)

func main() {
	listener, err := net.Listen("tcp", "127.0.0.1:18080")
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile("/tmp/proxy-ready", []byte("ready"), 0o600); err != nil {
		panic(err)
	}
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := os.WriteFile("/tmp/proxy-hit", []byte(r.URL.Path), 0o600); err != nil {
			panic(err)
		}
		http.Error(w, "intentional proxy failure", http.StatusInternalServerError)
	})
	if err := http.Serve(listener, handler); err != nil {
		panic(err)
	}
}
EOF
go build -o "$smoke_root/failing-proxy" "$smoke_root/proxy/main.go"
"$smoke_root/failing-proxy" &
proxy_pid=$!
trap 'kill "$proxy_pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 100); do
  test ! -e /tmp/proxy-ready || break
  sleep 0.05
done
test -e /tmp/proxy-ready

mkdir "$smoke_root/direct-source"
(
  cd "$smoke_root/direct-source"
  git init -q
  git config user.name test
  git config user.email test@example.invalid
  printf 'module example.invalid/direct.git\n\ngo 1.27\n' > go.mod
  printf 'package direct\nconst Value = 1\n' > direct.go
  git add go.mod direct.go
  git commit -qm init
  git tag v0.0.1
)
git clone -q --bare "$smoke_root/direct-source" "$smoke_root/direct.git"
git config --global url."file://$smoke_root/direct.git".insteadOf \
  https://example.invalid/direct
mkdir "$smoke_root/direct-client" "$smoke_root/modcache" "$smoke_root/gocache"
cat > "$smoke_root/direct-client/go.mod" <<'EOF'
module client.invalid/test

go 1.27

require example.invalid/direct.git v0.0.1
EOF
cat > "$smoke_root/direct-client/main.go" <<'EOF'
package main

import "example.invalid/direct.git"

func main() {
	if direct.Value != 1 {
		panic("unexpected direct module value")
	}
}
EOF
test -z "$(find "$smoke_root/modcache" -mindepth 1 -print -quit)"
test -z "$(find "$smoke_root/gocache" -mindepth 1 -print -quit)"
(
  cd "$smoke_root/direct-client"
  GOPROXY='http://127.0.0.1:18080|direct' \
  GONOPROXY=none \
  GONOSUMDB='example.invalid/*' \
  GOMODCACHE="$smoke_root/modcache" \
  GOCACHE="$smoke_root/gocache" \
    go mod download
  GOPROXY='http://127.0.0.1:18080|direct' \
  GONOPROXY=none \
  GONOSUMDB='example.invalid/*' \
  GOMODCACHE="$smoke_root/modcache" \
  GOCACHE="$smoke_root/gocache" \
    go build -o direct-smoke .
  ./direct-smoke
)
test -s /tmp/proxy-hit
test -s "$smoke_root/modcache/cache/download/example.invalid/direct.git/@v/v0.0.1.zip"
test -n "$(find "$smoke_root/gocache" -mindepth 1 -print -quit)"
kill "$proxy_pid"
wait "$proxy_pid" 2>/dev/null || true
trap - EXIT
rm -f /tmp/proxy-ready /tmp/proxy-hit
rm -rf "$smoke_root"

for path in /tmp/upstream /tmp/metadata /tmp/go.tar.gz /tmp/sqlc.tar.gz \
            /tmp/golangci-lint.tar.gz /tmp/stormlib.tar.gz /tmp/stormlib \
            /tmp/stormlib-build /workspace /app /root/.ssh /root/.git \
            /usr/src/wordpress /usr/src/sqlc /usr/src/golangci-lint; do
  test ! -e "$path"
done
CHECK

echo "mapservice-build checks passed: $image"
