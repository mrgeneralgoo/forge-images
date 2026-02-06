FROM serversideup/php:8.5-frankenphp@sha256:cd6f8c206c060fa4073ba9336811ce6162d8a591bdf77eb4c78dcfe910af0cb1

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
