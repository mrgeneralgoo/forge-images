FROM serversideup/php:8.5-frankenphp@sha256:64b83eece07c1415d61353bfc93641b40b836017e52b0675bc777adb6422de6c

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
