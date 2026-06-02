FROM serversideup/php:8.5-frankenphp@sha256:9223cffd4ff56072ed5adb94ae2ae1eae15e9b70397bfdb98d8fa2d928d327d9

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
