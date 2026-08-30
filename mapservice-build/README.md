# mapservice-build

A pinned, minimal Go and CGO build environment for Mapservice development. It
contains the Go toolchain, sqlc, golangci-lint, and source-built StormLib without
copying any application source.

## Images

```text
ghcr.io/mrgeneralgoo/mapservice-build
docker.io/mrgeneralgoo/mapservice-build
```

Architectures: `linux/amd64`, `linux/arm64`.

## Included toolchain

- Official Go distribution copied from a pinned multi-architecture Go image.
- Pinned sqlc binary.
- Pinned golangci-lint binary and corresponding GPL source archive.
- StormLib built from a commit-pinned, checksum-verified source archive.
- Git, CA certificates, GCC, libc headers, bzip2 headers, and zlib headers.

Transient download and build tools are absent from the final image. The working
directory is `/go`, `GOPATH=/go`, and Go's automatic toolchain download is
disabled with `GOTOOLCHAIN=local`.

## Provenance and licenses

Source commit IDs, source archive SHA256 values, source URLs, licenses, and
binary distribution references are stored under `/usr/share/doc`. The
corresponding golangci-lint source archive is retained at:

```text
/usr/share/source/golangci-lint/source.tar.gz
```

StormLib is installed under `/usr/local`, with dynamic linker configuration in
`/etc/ld.so.conf.d/stormlib.conf`. See [`NOTICE.md`](NOTICE.md) for component
license details.

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

Renovate tracks the StormLib release tag and invokes the transactional pin
updater:

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

The smoke test verifies tool versions, package minimization, license/provenance
artifacts, StormLib linkage, CGO compilation, and Go module proxy fallback.
