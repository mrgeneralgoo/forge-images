FROM serversideup/php:8.5-frankenphp@sha256:15bd049e56246e9da15465b15051fe033b064f70d6720239c696fc0f7d7313cc

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
