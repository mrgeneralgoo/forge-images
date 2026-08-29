mapservice-build contains these directly distributed upstream components:

- Go 1.27.0, licensed under BSD-3-Clause. Its license, PATENTS file, and
  pinned source provenance are in `/usr/share/doc/go/`.
- sqlc 1.31.1, licensed under MIT. Its license and pinned source provenance
  are in `/usr/share/doc/sqlc/`.
- golangci-lint v2.13.2, licensed under GPL-3.0. Its license and pinned source
  provenance are in `/usr/share/doc/golangci-lint/`; the exact upstream source
  archive for the pinned release is retained at
  `/usr/share/source/golangci-lint/source.tar.gz` as the corresponding-source
  artifact.
- StormLib v9.40, licensed under MIT. It is built from source, with its
  license and pinned source provenance in `/usr/share/doc/stormlib/`.

The provenance files record each source URL, source tag, immutable source
commit, archive SHA-256, and binary distribution reference. Generated SBOM
metadata is supplementary and does not replace these direct license or source
artifacts.

No application source, configuration, secret material, or deployment data is
part of this image.
