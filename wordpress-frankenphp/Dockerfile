FROM wordpress:7.1.0-php8.3-apache@sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17 AS wordpress-core

FROM serversideup/php:8.5-frankenphp@sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035
ARG VCS_REF=unknown

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions \
      igbinary zstd lzf mysqli exif imagick gd intl \
      timezonedb bcmath shmop redis

RUN mkdir -p /usr/share/doc/wordpress /var/www/html/public

COPY --from=wordpress-core /usr/src/wordpress/ /var/www/html/public/
COPY --from=wordpress-core /usr/src/wordpress/license.txt /usr/share/doc/wordpress/LICENSE
COPY NOTICE.md /usr/share/doc/wordpress/NOTICE.md

RUN set -eux; \
    mkdir -p /var/www/html/public/wp-content/uploads \
             /var/www/html/public/wp-content/cache; \
    printf '%s\n' \
      'WordPress source image: wordpress:7.1.0-php8.3-apache' \
      'WordPress source digest: sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17' \
      'WordPress source path: /usr/src/wordpress' \
      'WordPress destination path: /var/www/html/public' \
      'Runtime source image: serversideup/php:8.5-frankenphp' \
      'Runtime source digest: sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035' \
      'License source: /usr/src/wordpress/license.txt' \
      'License destination: /usr/share/doc/wordpress/LICENSE' \
      > /usr/share/doc/wordpress/PROVENANCE; \
    chown -R www-data:www-data /var/www/html/public /usr/share/doc/wordpress; \
    chmod 0755 /var/www/html/public/wp-content/uploads \
               /var/www/html/public/wp-content/cache

VOLUME ["/var/www/html/public/wp-content/uploads", "/var/www/html/public/wp-content/cache"]

LABEL org.opencontainers.image.title="WordPress on FrankenPHP" \
      org.opencontainers.image.description="Official WordPress core on a pinned FrankenPHP runtime with curated PHP extensions." \
      org.opencontainers.image.licenses="Apache-2.0 AND GPL-2.0-or-later" \
      org.opencontainers.image.version="7.1.0" \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}" \
      io.forge-images.wordpress.source-digest="sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17" \
      io.forge-images.frankenphp.source-digest="sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035"

USER www-data
