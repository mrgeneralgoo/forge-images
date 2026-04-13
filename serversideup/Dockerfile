FROM serversideup/php:8.5-frankenphp@sha256:f72b3b470ed612ac3f8511088ac59d5d1c848805f25b71dcfcc6487c4ac8ce12

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
