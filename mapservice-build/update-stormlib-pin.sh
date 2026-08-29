#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile
source_repo=https://github.com/ladislav-zezula/StormLib.git
source_base=https://codeload.github.com/ladislav-zezula/StormLib/tar.gz
new_value=${1:-}
dep_name=${2:-}
if [[ -z "$dep_name" && -n "${RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE:-}" ]]; then
  dep_name=$(cat "$RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE")
fi
if [[ -n "$dep_name" && "$dep_name" != "ladislav-zezula/StormLib" ]]; then
  exit 0
fi

if [[ "$new_value" == v* ]]; then
  version=${new_value#v}
else
  version=$new_value
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "invalid StormLib tag: ${new_value:-<empty>}" >&2
  exit 2
fi
tag="v$version"

work_dir=$(mktemp -d)
backup=$work_dir/Dockerfile
staged=$work_dir/Dockerfile.new
rollback=1
cleanup() {
  status=$?
  trap - EXIT
  set +e
  if (( rollback )); then
    cp -p "$backup" "$dockerfile"
    echo "StormLib pin update rolled back" >&2
  fi
  rm -rf "$work_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cp -p "$dockerfile" "$backup"
for key in STORMLIB_VERSION STORMLIB_COMMIT STORMLIB_ARCHIVE_SHA256; do
  count=$(grep -Ec "^ARG ${key}=" "$dockerfile")
  if [[ "$count" -ne 1 ]]; then
    echo "expected one ${key} pin" >&2
    exit 1
  fi
done

if [[ -n "${STORMLIB_UPDATE_TEST_COMMIT:-}" || -n "${STORMLIB_UPDATE_TEST_SHA256:-}" ]]; then
  commit=${STORMLIB_UPDATE_TEST_COMMIT:-}
  checksum=${STORMLIB_UPDATE_TEST_SHA256:-}
else
  commit=$(git ls-remote --tags "$source_repo" "refs/tags/${tag}^{}" | awk 'NR == 1 { print $1 }')
  if [[ -z "$commit" ]]; then
    commit=$(git ls-remote --tags "$source_repo" "refs/tags/${tag}" | awk 'NR == 1 { print $1 }')
  fi
  if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo "could not resolve commit for ${tag}" >&2
    exit 1
  fi

  archive=$work_dir/stormlib.tar.gz
  archive_url=$source_base/$commit
  curl --fail --silent --show-error --location --retry 3 "$archive_url" --output "$archive"
  checksum=$(sha256sum "$archive" | awk '{ print $1 }')
  if ! [[ "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
    echo "could not calculate archive digest" >&2
    exit 1
  fi
  header_path=$(tar -tzf "$archive" | awk '/\/src\/StormLib\.h$/ { print; exit }')
  test -n "$header_path"
  tar -xOf "$archive" "$header_path" | grep -F "STORMLIB_VERSION_STRING         \"$version\"" >/dev/null
fi
if [[ ! "$commit" =~ ^[0-9a-f]{40}$ || ! "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
  echo "invalid resolved StormLib metadata" >&2
  exit 1
fi

sed \
  -e "s|^ARG STORMLIB_VERSION=.*$|ARG STORMLIB_VERSION=$tag|" \
  -e "s|^ARG STORMLIB_COMMIT=.*$|ARG STORMLIB_COMMIT=$commit|" \
  -e "s|^ARG STORMLIB_ARCHIVE_SHA256=.*$|ARG STORMLIB_ARCHIVE_SHA256=$checksum|" \
  "$dockerfile" > "$staged"

bash -n "$script_dir/test.sh"
bash -n "$script_dir/update-stormlib-pin.sh"
grep -F "ARG STORMLIB_VERSION=$tag" "$staged" >/dev/null
grep -F "ARG STORMLIB_COMMIT=$commit" "$staged" >/dev/null
grep -F "ARG STORMLIB_ARCHIVE_SHA256=$checksum" "$staged" >/dev/null
mv "$staged" "$dockerfile"
case "${STORMLIB_UPDATE_TEST_FAIL_AFTER_RENAME:-}" in
  exit) false ;;
  term) kill -TERM "$$" ;;
  '') ;;
  *) echo "invalid failure injection" >&2; exit 2 ;;
esac

command -v docker >/dev/null
test_image=${STORMLIB_UPDATE_TEST_IMAGE:-forge-mapservice-build:stormlib-update}
docker build --platform linux/amd64 -t "$test_image" "$script_dir"
"$script_dir/test.sh" "$test_image"

rollback=0
echo "StormLib pin updated to $tag ($commit, $checksum)"
