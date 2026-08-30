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

- WordPress 7.1 core from the pinned official WordPress image.
- PHP 8.5 and FrankenPHP from the pinned Serversideup runtime.
- PHP extensions: `igbinary`, `zstd`, `lzf`, `mysqli`, `exif`, `imagick`, `gd`,
  `intl`, `timezonedb`, `bcmath`, `shmop`, and `redis`.
- WordPress source license, notice, and exact upstream image provenance under
  `/usr/share/doc/wordpress`.

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

The smoke test verifies PHP and WordPress versions, every curated extension,
licenses/provenance, non-root ownership, empty writable volumes, and the absence
of common secret files.
