FROM serversideup/php:8.5-frankenphp

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data