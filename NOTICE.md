forge-images
Copyright 2026 mrgeneralgoo

This repository is licensed under the Apache License, Version 2.0; see
LICENSE.

Each image may include software under additional licenses. The applicable
license files are copied into the image during the build and are readable from
the image itself:

- `mapservice-build`: `/usr/share/doc/go/`, `/usr/share/doc/sqlc/`, and
  `/usr/share/doc/stormlib/`
- `wordpress-frankenphp`: WordPress ships `license.txt` inside the document
  root at `/var/www/html/public/`

Upstream images are pinned by digest and recorded as
`io.forge-images.*.source-digest` labels, readable with `docker inspect`.
Generated SBOM metadata is supplemental; it does not replace the license files
carried in the images.
