FROM serversideup/php:8.5-frankenphp@sha256:136f9582ec01e0669ebf1a1499d9ecdfd299daa634e08a9489b3ff65ee3acd0a

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
