FROM serversideup/php:8.5-frankenphp@sha256:2da770229192affdbdd6ad81a5042c7270a1b47126bca8913791e10ce1ea320d

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
