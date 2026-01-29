FROM serversideup/php:8.5-frankenphp@sha256:abe3db9b4b4b5f4e77f45f1c11c5b9ba0b7471c6e635609a60cde3cec36d2347

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
