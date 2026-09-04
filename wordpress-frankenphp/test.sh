#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile

fail() { echo "$1" >&2; exit 1; }

# Upstream pins are read from the Dockerfile rather than duplicated here, so a
# Renovate digest bump never needs a matching edit in this file.
arg() {
  awk -v key="$1" '$1 == "ARG" && index($2, key "=") == 1 { sub("^[^=]+=", "", $2); print $2; exit }' "$dockerfile"
}

wordpress_ref=$(arg WORDPRESS_REF)
php_ref=$(arg PHP_REF)

# A malformed or missing ref would otherwise degrade every comparison below into
# an empty-string match that always passes.
for ref in "$wordpress_ref" "$php_ref"; do
  [[ "$ref" =~ ^[a-z0-9._/-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$ ]] ||
    fail "malformed upstream image reference in Dockerfile: ${ref:-<empty>}"
done

wordpress_digest=${wordpress_ref##*@}
php_digest=${php_ref##*@}

# Every digest literal must live in an ARG line. A second copy anywhere else is
# a pin that Renovate will not update and that will silently drift.
if grep -n 'sha256:' "$dockerfile" | grep -qv '^[0-9]*:ARG '; then
  fail 'digest literal outside an ARG line in Dockerfile'
fi

# Each FROM must resolve through the authoritative ARG. Without this the ARG,
# the labels and the actual base image could disagree while every derived
# assertion below still passed.
grep -Fxq 'FROM ${WORDPRESS_REF} AS wordpress-core' "$dockerfile" ||
  fail 'wordpress-core stage does not build from ${WORDPRESS_REF}'
grep -Fxq 'FROM ${PHP_REF}' "$dockerfile" ||
  fail 'runtime stage does not build from ${PHP_REF}'

for text in \
  'install-php-extensions' \
  'COPY --from=wordpress-core /usr/src/wordpress/ /var/www/html/public/' \
  'VOLUME ["/var/www/html/public/wp-content/uploads", "/var/www/html/public/wp-content/cache"]'; do
  grep -F "$text" "$dockerfile" >/dev/null || fail "missing Dockerfile contract: $text"
done

if grep -Eq '^[[:space:]]*FROM[[:space:]]+--platform=' "$dockerfile"; then
  fail 'fixed platform in Dockerfile'
fi
if grep -Eq '^[[:space:]]*COPY[[:space:]].*wp-content' "$dockerfile"; then
  fail 'local wp-content copy in Dockerfile'
fi

volumes=$(docker image inspect "$image" --format '{{range $path, $_ := .Config.Volumes}}{{$path}}{{"\n"}}{{end}}')
grep -Fx '/var/www/html/public/wp-content/uploads' <<<"$volumes" >/dev/null ||
  fail 'uploads volume missing'
grep -Fx '/var/www/html/public/wp-content/cache' <<<"$volumes" >/dev/null ||
  fail 'cache volume missing'

label() { docker image inspect "$image" --format "{{ index .Config.Labels \"$1\" }}"; }
test "$(label io.forge-images.wordpress.source-digest)" = "$wordpress_digest" ||
  fail "wordpress source-digest label does not match ${wordpress_digest}"
test "$(label io.forge-images.frankenphp.source-digest)" = "$php_digest" ||
  fail "frankenphp source-digest label does not match ${php_digest}"

# Everything below checks the real image. Versions are reported, never pinned:
# the image tracks upstream floating tags, so a version assertion here would
# turn every upstream release into a red pull request.
docker run --rm --entrypoint sh "$image" -s <<'CHECK'
set -eu

php -v >/dev/null || { echo 'php is not runnable' >&2; exit 1; }
command -v frankenphp >/dev/null || { echo 'frankenphp is missing from the runtime' >&2; exit 1; }
php -r 'require "/var/www/html/public/wp-includes/version.php"; echo "WordPress $wp_version on PHP " . PHP_VERSION . "\n";'

# WordPress and the PHP runtime are two independently floating references, so
# they can drift into a combination WordPress itself refuses to run on.
php -r 'require "/var/www/html/public/wp-includes/version.php";
  if (version_compare(PHP_VERSION, $required_php_version, "<")) {
    fwrite(STDERR, "PHP " . PHP_VERSION . " is below WordPress requirement " . $required_php_version . "\n");
    exit(1);
  }'

modules=$(php -m)
for extension in igbinary zstd lzf mysqli exif imagick gd intl timezonedb bcmath shmop redis; do
  printf '%s\n' "$modules" | grep -Fxi "$extension" >/dev/null ||
    { echo "missing PHP extension: $extension" >&2; exit 1; }
 done

for file in /var/www/html/public/wp-admin/about.php \
            /var/www/html/public/wp-includes/version.php \
            /var/www/html/public/license.txt; do
  test -f "$file" || { echo "missing WordPress file: $file" >&2; exit 1; }
done

test "$(id -u)" -eq 33 || { echo 'container does not run as uid 33' >&2; exit 1; }
test "$(id -g)" -eq 33 || { echo 'container does not run as gid 33' >&2; exit 1; }
for dir in /var/www/html/public /var/www/html/public/wp-content \
           /var/www/html/public/wp-content/uploads \
           /var/www/html/public/wp-content/cache; do
  test -d "$dir" || { echo "missing directory: $dir" >&2; exit 1; }
  test "$(stat -c '%U:%G' "$dir")" = 'www-data:www-data' ||
    { echo "wrong owner on $dir" >&2; exit 1; }
done
for dir in /var/www/html/public/wp-content/uploads \
           /var/www/html/public/wp-content/cache; do
  test -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)" ||
    { echo "$dir is not empty" >&2; exit 1; }
  touch "$dir/.write-test"
  rm "$dir/.write-test"
done

for file in /var/www/html/public/wp-config.php \
            /var/www/html/public/.env /var/www/html/public/.htpasswd \
            /var/www/html/public/.git/config; do
  test ! -e "$file" || { echo "unexpected file baked into image: $file" >&2; exit 1; }
done
if find /var/www/html/public -xdev -type f \( \
  -iname '*.env' -o -iname '*.pem' -o -iname '*.key' \
  -o -iname '*.p12' -o -iname '*.pfx' -o -iname 'id_rsa*' \
\) -print -quit | grep -q .; then
  echo 'credential-shaped file baked into image' >&2
  exit 1
fi
CHECK

# Everything above runs through `sh` and never exercises the image's own
# entrypoint. Start the container the way a consumer would and require a real
# WordPress response over HTTP, so a drifting FrankenPHP runtime that breaks the
# entrypoint, the Caddy config or the document root cannot pass silently.
container="wordpress-smoke-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$container" -p 127.0.0.1::8080 "$image" >/dev/null
host_port=$(docker port "$container" 8080/tcp | head -1 | sed 's/.*://')
[[ -n "$host_port" ]] || fail 'container did not publish the HTTP port'

served=
for _ in $(seq 1 60); do
  body=$(curl -fsSL "http://127.0.0.1:${host_port}/" 2>/dev/null || true)
  if [[ -n "$body" ]]; then
    served=$body
    break
  fi
  sleep 1
done

if [[ -z "$served" ]]; then
  docker logs "$container" >&2 || true
  fail 'image did not serve HTTP through its own entrypoint'
fi
grep -qi 'wordpress' <<<"$served" ||
  fail 'HTTP response did not come from WordPress'

cleanup
trap - EXIT

echo "wordpress-frankenphp checks passed: $image"
