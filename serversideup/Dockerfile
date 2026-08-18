FROM serversideup/php:8.5-frankenphp@sha256:ed948d6066755a5216c466c1e4da59b7020d958bac42f6da00e6189940d1853f

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
