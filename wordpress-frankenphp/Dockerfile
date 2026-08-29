FROM wordpress:7.1.0-php8.3-apache@sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17 AS wordpress-core

FROM ghcr.io/mrgeneralgoo/frankenphp:latest@sha256:89d9081b847dbacfa081acd6d2a125de81e810402fb3a1bb9f8df62f0b25a1c1
ARG VCS_REF=unknown

USER root
RUN mkdir -p /usr/share/doc/wordpress /var/www/html/public

COPY --from=wordpress-core /usr/src/wordpress/ /var/www/html/public/
COPY --from=wordpress-core /usr/src/wordpress/license.txt /usr/share/doc/wordpress/LICENSE
COPY NOTICE.md /usr/share/doc/wordpress/NOTICE.md

RUN set -eux; \
    mkdir -p /var/www/html/public/wp-content/uploads \
             /var/www/html/public/wp-content/cache; \
    printf '%s\n' \
      'Source image: wordpress:7.1.0-php8.3-apache' \
      'Source digest: sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17' \
      'Source path: /usr/src/wordpress' \
      'Destination path: /var/www/html/public' \
      'License source: /usr/src/wordpress/license.txt' \
      'License destination: /usr/share/doc/wordpress/LICENSE' \
      > /usr/share/doc/wordpress/PROVENANCE; \
    chown -R www-data:www-data /var/www/html/public /usr/share/doc/wordpress; \
    chmod 0755 /var/www/html/public/wp-content/uploads \
               /var/www/html/public/wp-content/cache

VOLUME ["/var/www/html/public/wp-content/uploads", "/var/www/html/public/wp-content/cache"]

LABEL org.opencontainers.image.title="WordPress core on FrankenPHP" \
      org.opencontainers.image.description="Official WordPress core copied into a pinned FrankenPHP runtime." \
      org.opencontainers.image.licenses="Apache-2.0 AND GPL-2.0-or-later" \
      org.opencontainers.image.version="7.1.0" \
      org.opencontainers.image.source="https://github.com/mrgeneralgoo/forge-images" \
      org.opencontainers.image.revision="${VCS_REF}" \
      io.forge-images.wordpress.source-digest="sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17" \
      io.forge-images.frankenphp.source-digest="sha256:89d9081b847dbacfa081acd6d2a125de81e810402fb3a1bb9f8df62f0b25a1c1"

USER www-data
