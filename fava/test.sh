#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

docker run --rm --entrypoint sh "$image" -c '
  set -eu
  python --version
  gunicorn --version
  python -c "import fava; print(fava.__version__)"
  python -c "import fava_dashboards"
'

workdir=$(mktemp -d)
container="fava-smoke-$$"
trap 'rm -rf "$workdir"; docker rm -f "$container" >/dev/null 2>&1 || true' EXIT

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
  -p 5001:5000 \
  "$image"

for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:5001/fava/ || true)
  case "$code" in
    200|301|302)
      echo "fava checks passed: $image"
      exit 0
      ;;
  esac
  sleep 1
done

docker logs "$container" || true
echo 'Fava did not serve /fava/ in time' >&2
exit 1
