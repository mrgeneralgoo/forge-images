#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

runtime_check=$(docker run --rm -i --entrypoint sh "$image" -s <<'CHECK'
set -eu
test "$(id -u)" -ne 0
test "$(command -v python)" = /opt/venv/bin/python
test "$(command -v gunicorn)" = /opt/venv/bin/gunicorn
test -x /usr/local/bin/python
python --version
gunicorn --version
python -m pip check
python - <<'PY'
import importlib.metadata
import importlib.util
import sys
from pathlib import Path

assert sys.prefix == "/opt/venv", sys.prefix
assert sys.base_prefix != sys.prefix
records = {}
for line in Path("/opt/fava/requirements-installed.txt").read_text().splitlines():
    if "==" in line:
        name, version = line.split("==", 1)
        records[name.lower().replace("-", "_")] = version
for package in ("fava", "beancount", "fava_dashboards", "a2wsgi", "anyio", "starlette", "uvicorn", "gunicorn"):
    assert package in records, package
    assert importlib.metadata.version(package) == records[package], package
    assert importlib.util.find_spec(package) is not None, package
PY
/usr/local/bin/python - <<'PY'
import importlib.util
import sys

assert sys.prefix != "/opt/venv", sys.prefix
packages = ("fava", "beancount", "fava_dashboards", "a2wsgi", "anyio", "starlette", "uvicorn", "gunicorn")
found = [package for package in packages if importlib.util.find_spec(package) is not None]
assert not found, found
PY
cat /opt/fava/requirements-installed.txt
printf '%s\n' 'runtime checks passed'
CHECK
)
printf '%s\n' "$runtime_check"
gunicorn_version=$(awk -F== '$1 == "gunicorn" { print $2 }' <<<"$runtime_check")
grep -Eq '^Python 3\.14\.' <<<"$runtime_check"
grep -F "gunicorn (version $gunicorn_version)" <<<"$runtime_check" >/dev/null
grep -Fxq 'runtime checks passed' <<<"$runtime_check"

workdir=$(mktemp -d)
chmod 755 "$workdir"
container="fava-smoke-$$"
override_container="fava-override-$$"
trap 'rm -rf "$workdir"; docker rm -f "$container" "$override_container" >/dev/null 2>&1 || true' EXIT

cat > "$workdir/main.bean" <<'BEAN'
option "operating_currency" "USD"
2020-01-01 open Assets:Cash
2020-01-01 open Equity:Opening-Balances
2020-01-01 * "seed"
  Assets:Cash             1.00 USD
  Equity:Opening-Balances
BEAN

docker run -d --name "$container" \
  -v "$workdir/main.bean:/data/main.bean:ro" \
  -e FAVA_WORKERS=1 \
  -p 127.0.0.1::5000 \
  "$image"
base_port=$(docker port "$container" 5000/tcp | awk -F: 'NR == 1 { print $NF }')
base_url="http://127.0.0.1:$base_port"

for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$base_url/fava/" || true)
  case "$code" in
    200|301|302) break ;;
  esac
  sleep 1
done

page_response="$workdir/fava-page.html"
query_response="$workdir/fava-query.json"
curl -fsSL "$base_url/fava/" -o "$page_response"
grep -q 'ledger-data' "$page_response"
curl -fsS --get --data-urlencode 'query_string=SELECT account FROM postings' \
  "$base_url/fava/beancount/api/query" -o "$query_response"
grep -Eq 'Assets:Cash|Opening-Balances' "$query_response"

# A downstream image can replace CMD with a plain ASGI service. This checks
# that the override starts only Uvicorn and does not import or start Fava.
docker run -d --name "$override_container" \
  -p 127.0.0.1::5000 \
  "$image" sh -c 'printf "%s\n" \
    "from a2wsgi import WSGIMiddleware" \
    "def wsgi(environ, start_response):" \
    "    start_response(\"200 OK\", [(\"content-type\", \"text/plain\")])" \
    "    return [b\"override\"]" \
    "app = WSGIMiddleware(wsgi)" \
    > /tmp/asgi.py; exec uvicorn --app-dir /tmp --host 0.0.0.0 --port 5000 asgi:app'
override_port=$(docker port "$override_container" 5000/tcp | awk -F: 'NR == 1 { print $NF }')
override_url="http://127.0.0.1:$override_port"

override_response="$workdir/override-response.txt"
for _ in $(seq 1 30); do
  if curl -fsS "$override_url/" -o "$override_response" 2>/dev/null \
      && [[ "$(<"$override_response")" == override ]]; then
    break
  fi
  sleep 1
done
curl -fsS "$override_url/" -o "$override_response"
test "$(<"$override_response")" = override
if docker top "$override_container" | grep -q '[g]unicorn'; then
  echo 'CMD override unexpectedly started Gunicorn' >&2
  exit 1
fi
test "$(docker top "$override_container" | grep -c '[u]vicorn')" -eq 1

echo "fava checks passed: $image"
