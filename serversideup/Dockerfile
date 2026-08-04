FROM serversideup/php:8.5-frankenphp@sha256:d7a9adc0dcddc6aa38af4cae6842f2d15cb56ae917a2738998f31a487720e183

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
