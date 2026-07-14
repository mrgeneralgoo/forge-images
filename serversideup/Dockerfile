FROM serversideup/php:8.5-frankenphp@sha256:a0f4447da7612f9bca3c982d0cf33a607cbddf828f4b96a44bfa9f6f037007b6

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
