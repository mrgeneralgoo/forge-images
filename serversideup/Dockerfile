FROM serversideup/php:8.5-frankenphp@sha256:0e3ccba461b7054bac70f42f379bfa9d45614e62ac221003ef9271551516706f

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
