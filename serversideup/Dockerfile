FROM serversideup/php:8.5-frankenphp@sha256:00d0699b22265e91e7e27f85f57b08f23f946bbb59bf811e520b99c748979d77

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
