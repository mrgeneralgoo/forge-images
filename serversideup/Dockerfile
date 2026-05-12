FROM serversideup/php:8.5-frankenphp@sha256:9513151c104ce0e1d0291522ad86d697291cbebe6c9cbdb679aaa123f5f263c9

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
