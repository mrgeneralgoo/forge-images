FROM serversideup/php:8.5-frankenphp@sha256:4390a120c0dc7a3bc33c2e979a2ffe307e8658fc816843660180fda391d5b901

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
