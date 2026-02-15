FROM serversideup/php:8.5-frankenphp@sha256:3c8ec9a132671fe2b345fff052445aaed47d6f070053f45b11300b97dce1cd81

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
