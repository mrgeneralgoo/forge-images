#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile

for text in \
  'FROM wordpress:7.1.0-php8.3-apache@sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17 AS wordpress-core' \
  'FROM serversideup/php:8.5-frankenphp@sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035' \
  'install-php-extensions' \
  'COPY --from=wordpress-core /usr/src/wordpress/ /var/www/html/public/' \
  'COPY --from=wordpress-core /usr/src/wordpress/license.txt /usr/share/doc/wordpress/LICENSE' \
  'VOLUME ["/var/www/html/public/wp-content/uploads", "/var/www/html/public/wp-content/cache"]'; do
  grep -F "$text" "$dockerfile" >/dev/null
done

if grep -Eq '^[[:space:]]*FROM[[:space:]]+--platform=' "$dockerfile"; then
  echo 'fixed platform in Dockerfile' >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*COPY[[:space:]].*wp-content' "$dockerfile"; then
  echo 'local wp-content copy in Dockerfile' >&2
  exit 1
fi

volumes=$(docker image inspect "$image" --format '{{range $path, $_ := .Config.Volumes}}{{$path}}{{"\n"}}{{end}}')
grep -Fx '/var/www/html/public/wp-content/uploads' <<<"$volumes" >/dev/null
grep -Fx '/var/www/html/public/wp-content/cache' <<<"$volumes" >/dev/null

test "$(docker image inspect "$image" --format '{{ index .Config.Labels "io.forge-images.wordpress.source-digest" }}')" = \
  'sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17'
test "$(docker image inspect "$image" --format '{{ index .Config.Labels "io.forge-images.frankenphp.source-digest" }}')" = \
  'sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035'

docker run --rm --entrypoint sh "$image" -s <<'CHECK'
set -eu

php -v | grep -F 'PHP 8.5'
php -r 'require "/var/www/html/public/wp-includes/version.php"; exit($wp_version === "7.1" ? 0 : 1);'

modules=$(php -m)
for extension in igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis; do
  printf '%s\n' "$modules" | grep -Fxi "$extension" >/dev/null
 done

test -f /var/www/html/public/wp-admin/about.php
test -f /var/www/html/public/wp-includes/version.php
test -s /usr/share/doc/wordpress/LICENSE
test -s /usr/share/doc/wordpress/PROVENANCE
test -s /usr/share/doc/wordpress/NOTICE.md
grep -F 'sha256:5a93c470ae8220fddf71f6ebe3bc94e615ddc2ae4d9810f795b830fb11c41a17' /usr/share/doc/wordpress/PROVENANCE
grep -F 'sha256:c8e9d95cd6b83180662f63de646937f3b304041ac4edfbd95ff8bd684467d035' /usr/share/doc/wordpress/PROVENANCE
cmp -s /var/www/html/public/license.txt /usr/share/doc/wordpress/LICENSE

test "$(id -u)" -eq 33
test "$(id -g)" -eq 33
for dir in /var/www/html/public /var/www/html/public/wp-content \
           /var/www/html/public/wp-content/uploads \
           /var/www/html/public/wp-content/cache; do
  test -d "$dir"
  test "$(stat -c '%U:%G' "$dir")" = 'www-data:www-data'
done
for dir in /var/www/html/public/wp-content/uploads \
           /var/www/html/public/wp-content/cache; do
  test -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)"
  touch "$dir/.write-test"
  rm "$dir/.write-test"
done

for file in /var/www/html/public/wp-config.php \
            /var/www/html/public/.env /var/www/html/public/.htpasswd \
            /var/www/html/public/.git/config; do
  test ! -e "$file"
done
if find /var/www/html/public -xdev -type f \( \
  -iname '*.env' -o -iname '*.pem' -o -iname '*.key' \
  -o -iname '*.p12' -o -iname '*.pfx' -o -iname 'id_rsa*' \
\) -print -quit | grep -q .; then
  exit 1
fi
CHECK

echo "wordpress-frankenphp checks passed: $image"
