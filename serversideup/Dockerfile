FROM serversideup/php:8.5-frankenphp@sha256:306fe6c67b31e0bff6bf984ba66c9d74dd10dbfce87e716a1cc8eed355c8c71a

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
