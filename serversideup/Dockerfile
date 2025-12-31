FROM serversideup/php:8.5-frankenphp@sha256:560ea3174ea50c86a5a8de3b951a1620ec29d1850841878378889e24befac876

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data