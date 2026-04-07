FROM serversideup/php:8.5-frankenphp@sha256:7197af7583c25b11a892627cb579cffec03cda5a8724e0391c9fabc6717cec82

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
