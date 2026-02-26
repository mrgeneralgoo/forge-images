FROM serversideup/php:8.5-frankenphp@sha256:e5df1046da4de420ff527c707b77f93332c876f5f9feb291e7194fc199354f78

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
