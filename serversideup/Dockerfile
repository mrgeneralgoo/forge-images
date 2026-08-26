FROM serversideup/php:8.5-frankenphp@sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
