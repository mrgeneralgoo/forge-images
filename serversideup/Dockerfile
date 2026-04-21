FROM serversideup/php:8.5-frankenphp@sha256:e31838f138ec0b1c915297d6c90fd057f54653c7f6ad12c119fb45ec2fac5b81

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
