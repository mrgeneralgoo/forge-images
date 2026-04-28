FROM serversideup/php:8.5-frankenphp@sha256:666ddedf3153b59c216a30ebd708fc0062c5ccd85fb43249b53fd70ab3f3380e

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
