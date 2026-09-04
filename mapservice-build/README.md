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

Every upstream image follows a floating tag pinned by digest (`golang:trixie`,
`sqlc/sqlc:latest`, `debian:trixie-slim`), so Renovate digest updates carry new
upstream releases in without a version edit anywhere else, and they merge
automatically once CI is green. Each digest literal lives in exactly one
`ARG *_REF` line at the top of the Dockerfile; labels are derived from it.

`golang:trixie` rather than `golang:latest` keeps the Go toolchain on the same
Debian release as the runtime. The StormLib shared object's glibc compatibility
does not rest on that, though: it is compiled inside `DEBIAN_REF` itself, the
same image the runtime stage uses, so the match is exact rather than merely
probable.

StormLib is the one component not covered by a digest update, because it is
built from source: a release bump moves three pins at once — version, source
commit and archive checksum — and only the version is discoverable from the tag.
That is automated separately, see [StormLib updates](#stormlib-updates).

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

[`.github/workflows/update-stormlib-pin.yml`](../.github/workflows/update-stormlib-pin.yml)
runs daily. It compares the pinned version against the newest upstream release
tag and, when they differ, runs the transactional updater below, then opens a
pull request.

The pull request is validated on both architectures before it is opened. The
updater builds and runs `test.sh` on amd64 and restores the previous Dockerfile
if anything fails; the workflow then pushes the candidate branch and rebuilds
and retests it natively on `ubuntu-24.04-arm`. StormLib is compiled C/C++, so a
release can break one architecture and not the other — validating only the
platform the updater happens to run on would be misleading. A branch that fails
arm64 validation is deleted rather than left behind.

The pull request is opened with `GITHUB_TOKEN`, which by design does not trigger
workflow runs, so it carries no checks of its own — read the workflow log, then
merge.

The same updater can be run by hand, which is also how a downgrade or a specific
tag is applied:

```bash
bash mapservice-build/update-stormlib-pin.sh v9.41
```

It resolves the source commit and archive checksum from the tag, verifies the
version string inside the downloaded archive, rewrites the Dockerfile
atomically, builds a validation image, and restores the previous Dockerfile on
failure.

Renovate also tracks the StormLib tag through a custom manager and reports new
releases on the dependency dashboard without opening a pull request
(`dependencyDashboardApproval`). That is deliberate redundancy: if the workflow
ever stops finding releases, the dashboard entry still surfaces them.

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
