FROM serversideup/php:8.5-frankenphp@sha256:0380c82177bac697ef4385b451086d789a9618bfc2c06cf6f52905c018fa8cae

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
