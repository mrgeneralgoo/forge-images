FROM serversideup/php:8.5-frankenphp@sha256:25c106e909fee00417db094a876f532fa212c087d3068102295b1416475529c5

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data
