FROM serversideup/php:8.5-frankenphp@sha256:a5892a21eb01d10bc9e4970e0587d7d93f7cdc201f0b73596cabbd25ea15b933

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
