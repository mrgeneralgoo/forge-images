ARG WORDPRESS_REF=wordpress:latest@sha256:074f9ef5429025dab76a4242f5b796f64ae76a49dd19b6708ad29e1893a8d383
ARG PHP_REF=serversideup/php:frankenphp@sha256:e679ccfc3832c3958b76f86d85e6d4e62a98292482b771f436e11884454f3ac9

FROM ${WORDPRESS_REF} AS wordpress-core

FROM ${PHP_REF}
ARG WORDPRESS_REF
ARG PHP_REF
ARG VCS_REF=unknown

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions \
      igbinary zstd lzf mysqli exif imagick gd intl \
      timezonedb bcmath shmop redis

RUN mkdir -p /var/www/html/public

# WordPress core ships its own license.txt inside the document root, so the
# tree copied here is already the complete corresponding source.
COPY --from=wordpress-core /usr/src/wordpress/ /var/www/html/public/

RUN set -eux; \
    mkdir -p /var/www/html/public/wp-content/uploads \
             /var/www/html/public/wp-content/cache; \
    chown -R www-data:www-data /var/www/html/public; \
    chmod 0755 /var/www/html/public/wp-content/uploads \
               /var/www/html/public/wp-content/cache

VOLUME ["/var/www/html/public/wp-content/uploads", "/var/www/html/public/wp-content/cache"]

# Upstream references are derived from the ARG pins above: the digest literal
# lives in exactly one place per image, so a Renovate digest bump needs no
# follow-up edits anywhere else.
LABEL org.opencontainers.image.title="WordPress on FrankenPHP" \
      org.opencontainers.image.description="Official WordPress core on a pinned FrankenPHP runtime with curated PHP extensions." \
      org.opencontainers.image.licenses="Apache-2.0 AND GPL-2.0-or-later" \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}" \
      io.forge-images.wordpress.source-digest="${WORDPRESS_REF##*@}" \
      io.forge-images.frankenphp.source-digest="${PHP_REF##*@}"

USER www-data
