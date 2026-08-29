forge-images
Copyright 2026 mrgeneralgoo

This repository is licensed under the Apache License, Version 2.0; see
LICENSE.

Each image may include software under additional licenses. Direct notices and
provenance for the generic images are kept beside their Dockerfiles:

- `mapservice-build/NOTICE.md` and the image's `/usr/share/doc/go/`,
  `/usr/share/doc/sqlc/`, `/usr/share/doc/golangci-lint/`, and
  `/usr/share/doc/stormlib/`
- `wordpress-frankenphp/NOTICE.md` and the image's `/usr/share/doc/wordpress/`

The applicable license files are copied from the corresponding upstream
artifacts during image builds. For `mapservice-build`, the pinned golangci-lint
corresponding-source archive is also retained at
`/usr/share/source/golangci-lint/source.tar.gz`. Generated SBOM metadata is
supplemental; it does not replace direct license, provenance, or source
artifacts.
