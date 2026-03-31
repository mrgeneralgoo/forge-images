FROM serversideup/php:8.5-frankenphp@sha256:6a8ccf5b64ea6a37ac0ff087490df028124744919b7b274cf6ca7512a0555939

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
