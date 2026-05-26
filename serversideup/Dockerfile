FROM serversideup/php:8.5-frankenphp@sha256:af741f32b06bea7b496ec050fd72abb6e652db962cc3bab3717ec5458b50c79c

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
