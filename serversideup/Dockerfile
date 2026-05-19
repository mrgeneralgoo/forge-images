FROM serversideup/php:8.5-frankenphp@sha256:0a33b42e544ecc1c40ed39fc194e23c397068d17e5fc7678ba3df140980d7a15

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
