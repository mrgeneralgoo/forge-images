# WordPress FrankenPHP

Official WordPress core copied into a pinned Serversideup FrankenPHP runtime
with a curated set of PHP extensions. The image is a clean application base: it
contains no site plugins, themes, configuration, credentials, uploads, or cache
data.

## Images

```text
ghcr.io/mrgeneralgoo/wordpress-frankenphp
docker.io/mrgeneralgoo/wordpress-frankenphp
```

Architectures: `linux/amd64`, `linux/arm64`.

## Contents

- WordPress core from the official WordPress image.
- PHP and FrankenPHP from the Serversideup runtime.
- PHP extensions: `igbinary`, `zstd`, `lzf`, `mysqli`, `exif`, `imagick`, `gd`,
  `intl`, `timezonedb`, `bcmath`, `shmop`, and `redis`.
- Upstream image digests recorded as `io.forge-images.*.source-digest` labels.

Both upstream images are tracked by floating tag and pinned by digest, so
Renovate digest updates carry new upstream releases in without any version
edit. The exact versions in a given build are readable from the image itself:

```bash
docker run --rm --entrypoint php <image> -r \
  'require "/var/www/html/public/wp-includes/version.php"; echo "$wp_version PHP " . PHP_VERSION . "\n";'
```

WordPress is installed at:

```text
/var/www/html/public
```

The final process runs as `www-data` (`uid=33`, `gid=33`).

## Extending the image

A site-specific image should add only its `wp-content` tree:

```dockerfile
FROM ghcr.io/mrgeneralgoo/wordpress-frankenphp@sha256:<digest>

USER root
COPY --chown=www-data:www-data ./wp-content /var/www/html/public/wp-content
USER www-data
```

Do not copy `wp-config.php`, credentials, environment files, uploads, or cache
contents into the image.

## Volumes

```text
/var/www/html/public/wp-content/uploads
/var/www/html/public/wp-content/cache
```

Both directories are created empty, owned by `www-data`, writable at runtime,
and declared as volumes.

## Local test

```bash
docker buildx build --platform linux/amd64 --load \
  -t test-wordpress-frankenphp wordpress-frankenphp
./wordpress-frankenphp/test.sh test-wordpress-frankenphp
```

The smoke test verifies that PHP and WordPress load, every curated extension is
present, upstream digest labels match the Dockerfile pins, ownership is non-root,
volumes are empty and writable, and no common secret files were baked in. It
reports the PHP and WordPress versions but does not assert them, so an upstream
release never turns a digest update red.
