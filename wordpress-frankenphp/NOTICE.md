This image combines WordPress core from the pinned official WordPress image
with a pinned Serversideup FrankenPHP runtime and a curated set of PHP
extensions.

The WordPress license is copied during the image build to
`/usr/share/doc/wordpress/LICENSE`. Exact source-image digests and source paths
are recorded in `/usr/share/doc/wordpress/PROVENANCE`.

No application plugins, themes, configuration, secret material, or deployment
data are included. `wp-content/uploads` and `wp-content/cache` are empty writable
runtime volumes.
