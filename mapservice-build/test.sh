#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile

fail() { echo "$1" >&2; exit 1; }

# Pins are read from the Dockerfile rather than duplicated here, so a Renovate
# digest bump never needs a matching edit in this file.
arg() {
  awk -v key="$1" '$1 == "ARG" && index($2, key "=") == 1 { sub("^[^=]+=", "", $2); print $2; exit }' "$dockerfile"
}

go_ref=$(arg GO_REF)
sqlc_ref=$(arg SQLC_REF)
debian_ref=$(arg DEBIAN_REF)
stormlib_version=$(arg STORMLIB_VERSION)
stormlib_commit=$(arg STORMLIB_COMMIT)
stormlib_sha=$(arg STORMLIB_ARCHIVE_SHA256)

# A malformed or missing pin would otherwise degrade the comparisons below into
# empty-string matches that always pass.
for ref in "$go_ref" "$sqlc_ref" "$debian_ref"; do
  [[ "$ref" =~ ^[a-z0-9._/-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$ ]] ||
    fail "malformed upstream image reference in Dockerfile: ${ref:-<empty>}"
done
[[ "$stormlib_version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] ||
  fail "invalid StormLib version pin: ${stormlib_version:-<empty>}"
[[ "$stormlib_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail "invalid StormLib commit pin: ${stormlib_commit:-<empty>}"
[[ "$stormlib_sha" =~ ^[0-9a-f]{64}$ ]] ||
  fail "invalid StormLib archive checksum pin: ${stormlib_sha:-<empty>}"

# Every digest literal must live in an ARG line. A second copy anywhere else is
# a pin Renovate will not update and that will silently drift.
if grep -n '@sha256:' "$dockerfile" | grep -qv '^[0-9]*:ARG '; then
  fail 'image digest literal outside an ARG line in Dockerfile'
fi

# Each FROM must resolve through the authoritative ARG. Without this the ARG,
# the labels and the actual base image could disagree while every derived
# assertion below still passed.
grep -Fxq 'FROM ${SQLC_REF} AS sqlc' "$dockerfile" ||
  fail 'sqlc stage does not build from ${SQLC_REF}'
grep -Fxq 'FROM ${GO_REF} AS go-distribution' "$dockerfile" ||
  fail 'go-distribution stage does not build from ${GO_REF}'
grep -Fxq 'FROM ${DEBIAN_REF}' "$dockerfile" ||
  fail 'final stage does not build from ${DEBIAN_REF}'

for text in \
  'COPY --from=go-distribution /usr/local/go/ /usr/local/go/' \
  'COPY --from=sqlc /workspace/sqlc /usr/local/bin/sqlc' \
  'COPY --from=stormlib-builder /opt/stormlib/ /usr/local/' \
  'https://codeload.github.com/ladislav-zezula/StormLib/tar.gz/' \
  'sha256sum --check --status'; do
  grep -F "$text" "$dockerfile" >/dev/null || fail "missing Dockerfile contract: $text"
done

# StormLib is the only component built from source, so its three pins must stay
# consistent with each other.
for key in STORMLIB_VERSION STORMLIB_COMMIT STORMLIB_ARCHIVE_SHA256; do
  grep -Eq "^ARG ${key}=" "$dockerfile" || fail "missing pin: ARG ${key}"
done

test_updater_rollback() {
  local mode=$1
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  cp "$dockerfile" "$script_dir/update-stormlib-pin.sh" "$script_dir/test.sh" "$fixture/"
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
    fail "StormLib updater failure injection unexpectedly succeeded: $mode"
  fi
  cmp -s "$fixture/Dockerfile.before" "$fixture/Dockerfile" ||
    fail "StormLib updater did not roll back the Dockerfile: $mode"
  if find "$fixture" -maxdepth 1 -type f \
      \( -name '*.tmp.*' -o -name '*.backup.*' -o -name 'Dockerfile.new' \) \
      -print -quit | grep -q .; then
    fail "StormLib updater left transaction artifacts: $mode"
  fi
  rm -rf "$fixture"
  trap - RETURN
}

for mode in exit term; do
  test_updater_rollback "$mode"
done

expected_arch=$(docker image inspect "$image" --format '{{.Architecture}}')
case "$expected_arch" in amd64|arm64) ;; *) fail "unexpected image architecture: $expected_arch";; esac

label() { docker image inspect "$image" --format "{{ index .Config.Labels \"$1\" }}"; }
test "$(label io.forge-images.go.source-digest)" = "${go_ref##*@}" ||
  fail "go source-digest label does not match ${go_ref##*@}"
test "$(label io.forge-images.sqlc.source-digest)" = "${sqlc_ref##*@}" ||
  fail "sqlc source-digest label does not match ${sqlc_ref##*@}"

# Everything below checks the real image. Tool versions are reported, never
# asserted: the image tracks upstream floating tags, so a version assertion here
# would turn every upstream release into a red pull request. StormLib is the
# exception -- it is built from a pinned source commit, so the version compiled
# into the header must match the pin.
docker run --rm \
  -e EXPECTED_ARCH="$expected_arch" \
  -e EXPECTED_STORMLIB_VERSION="${stormlib_version#v}" \
  --entrypoint sh "$image" -s <<'CHECK'
set -eu

export DEBIAN_FRONTEND=noninteractive

go version
sqlc version
git --version
test "$(dpkg --print-architecture)" = "$EXPECTED_ARCH" ||
  { echo "architecture mismatch" >&2; exit 1; }
go version | grep -Fq "linux/$EXPECTED_ARCH" ||
  { echo "go reports a different architecture" >&2; exit 1; }
test -s /etc/ssl/certs/ca-certificates.crt

for package in ca-certificates gcc git libc6-dev libbz2-dev zlib1g-dev; do
  dpkg-query -W "$package" >/dev/null || { echo "missing package: $package" >&2; exit 1; }
 done
for package in cmake curl g++ gnupg make mercurial openssh-client pkg-config python3 subversion wget; do
  if dpkg-query -W "$package" >/dev/null 2>&1; then
    echo "unexpected package in slim build environment: $package" >&2
    exit 1
  fi
done

for file in /usr/share/doc/go/LICENSE \
            /usr/share/doc/go/PATENTS \
            /usr/share/doc/sqlc/LICENSE \
            /usr/share/doc/stormlib/LICENSE; do
  test -s "$file" || { echo "missing license file: $file" >&2; exit 1; }
done
grep -F 'Copyright 2009 The Go Authors.' /usr/share/doc/go/LICENSE >/dev/null
grep -F 'MIT License' /usr/share/doc/sqlc/LICENSE >/dev/null
grep -F 'The MIT License (MIT)' /usr/share/doc/stormlib/LICENSE >/dev/null

test -s /usr/local/lib/libstorm.so
test -s /usr/local/include/StormLib.h
ldd /usr/local/lib/libstorm.so >/dev/null
grep -F "STORMLIB_VERSION_STRING         \"$EXPECTED_STORMLIB_VERSION\"" \
  /usr/local/include/StormLib.h >/dev/null ||
  { echo "StormLib header version does not match the pin" >&2; exit 1; }

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

for path in /tmp/upstream /tmp/stormlib.tar.gz /tmp/stormlib \
            /tmp/stormlib-build /workspace /app /root/.ssh /root/.git \
            /usr/src/sqlc; do
  test ! -e "$path" || { echo "build leftover in final image: $path" >&2; exit 1; }
done
CHECK

echo "mapservice-build checks passed: $image"
