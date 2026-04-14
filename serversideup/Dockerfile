FROM serversideup/php:8.5-frankenphp@sha256:172219c7ad30e93640457334a2c88c6e0faea122994b1859d5067287e39fc4c8

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
