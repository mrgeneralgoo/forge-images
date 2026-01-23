FROM serversideup/php:8.5-frankenphp@sha256:3b3fb2e57bab5ea239c07b0e88eea9e63a299d0551e063a55a7cb40edf5247f4

USER root

RUN (pecl uninstall -r redis || true) && \
    (rm -f /usr/local/etc/php/conf.d/docker-php-ext-redis.ini || true) && \
    install-php-extensions igbinary mysqli exif imagick gd intl timezonedb bcmath shmop redis

USER www-data