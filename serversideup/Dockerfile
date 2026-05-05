FROM serversideup/php:8.5-frankenphp@sha256:5bbc0d411d848aad39c260a88096b3d926054c738356c70bef324ffefb348044

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
