# mapservice-build

A pinned, minimal Go and CGO build environment for Mapservice development. It
contains the Go toolchain, sqlc, and source-built StormLib without copying any
application source.

> **Breaking change:** `golangci-lint` was removed from this image. Consumers
> that lint inside it must install it themselves or pin an earlier digest.

## Images

```text
ghcr.io/mrgeneralgoo/mapservice-build
docker.io/mrgeneralgoo/mapservice-build
```

Architectures: `linux/amd64`, `linux/arm64`.

## Included toolchain

- Official Go distribution copied from a digest-pinned multi-architecture Go
  image.
- sqlc binary from a digest-pinned image.
- StormLib built from a commit-pinned, checksum-verified source archive.
- Git, CA certificates, GCC, libc headers, bzip2 headers, and zlib headers.

Transient download and build tools are absent from the final image. The working
directory is `/go`, `GOPATH=/go`, and Go's automatic toolchain download is
disabled with `GOTOOLCHAIN=local`.

## Version tracking

Go and Debian follow floating tags (`golang:trixie`, `debian:trixie-slim`)
pinned by digest, so Renovate digest updates carry new upstream releases in
without any version edit anywhere else. Each digest literal lives in exactly one
`ARG *_REF` line at the top of the Dockerfile; labels are derived from it.

`golang:trixie` rather than `golang:latest` keeps the build stage aligned with
the `debian:trixie-slim` runtime, so the StormLib shared object it compiles
always matches the runtime's glibc.

sqlc has no minor tag upstream, so it stays pinned to an exact version and needs
a deliberate bump. StormLib is built from source and keeps its commit and
checksum pinned.

Read the actual versions out of any build with:

```bash
docker run --rm <image> go version
docker run --rm --entrypoint sqlc <image> version
```

## Licenses

Upstream license files are copied into the image: Go's `LICENSE` and `PATENTS`
from the official distribution, StormLib's `LICENSE` from the source tree it is
built from, and sqlc's MIT text from `licenses/sqlc-LICENSE` in this repository
(the upstream sqlc image is a scratch image carrying no license file). All are
under `/usr/share/doc`.

StormLib is installed under `/usr/local`, with dynamic linker configuration in
`/etc/ld.so.conf.d/stormlib.conf`.

## Usage

```bash
docker run --rm \
  -v "$PWD:/go/src/project" \
  -w /go/src/project \
  ghcr.io/mrgeneralgoo/mapservice-build@sha256:<digest> \
  go test ./...
```

The image intentionally contains no application source or deployment secrets.
Use BuildKit secret mounts or runtime environment variables for private module
credentials.

## StormLib updates

StormLib needs three pins updated together — version, source commit and archive
checksum — and only the version is discoverable from the release tag. Renovate
on the hosted app cannot run commands, so it reports new StormLib tags on the
dependency dashboard and does not open a pull request on its own
(`dependencyDashboardApproval`). A maintainer runs the transactional updater:

```bash
bash mapservice-build/update-stormlib-pin.sh v9.41
```

The updater resolves the source commit and archive checksum, rewrites the
Dockerfile atomically, builds a validation image, and restores the previous
Dockerfile on failure.

## Local test

```bash
docker buildx build --platform linux/amd64 --load \
  -t test-mapservice-build mapservice-build
./mapservice-build/test.sh test-mapservice-build
```

The smoke test verifies that the pins in the Dockerfile match the built image,
that each stage builds from its authoritative `ARG`, package minimization,
license files, StormLib linkage and a real call into an exported StormLib
symbol, CGO compilation, and Go module proxy fallback. Tool versions are
reported rather than asserted, except StormLib, which is compiled from a pinned
source commit and so must match its pin.
