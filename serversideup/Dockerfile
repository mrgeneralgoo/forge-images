FROM serversideup/php:8.5-frankenphp@sha256:f297dbdbe2474e5075c5e938be4d4ba7ab902064f414743f5509d27a957c20d6

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
