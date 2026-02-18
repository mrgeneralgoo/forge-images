FROM serversideup/php:8.5-frankenphp@sha256:202596793f603888119b6b8600df6eceae32b7d3d76bed5f6b949384e47a0389

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
