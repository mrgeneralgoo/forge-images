FROM serversideup/php:8.5-frankenphp@sha256:6bd7ec8b1afc69566b97f10d2f883cdd7d40cfa030342fab597ca29f68f4205c

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
