#!/bin/bash
set -e

IMAGE_NAME=$1

if [ -z "$IMAGE_NAME" ]; then
  echo "Error: Image name is required."
  echo "Usage: $0 <image_name>"
  exit 1
fi

echo "Testing image: $IMAGE_NAME"

echo "Checking Python..."
docker run --rm "$IMAGE_NAME" python --version

echo "Checking Fava is importable..."
docker run --rm "$IMAGE_NAME" python -c "import fava; print('fava', fava.__version__)"

echo "Checking gunicorn..."
docker run --rm "$IMAGE_NAME" gunicorn --version

echo "Checking fava-dashboards is installed..."
docker run --rm "$IMAGE_NAME" python -c "import fava_dashboards; print('fava-dashboards ok')"

# --- Boot test: mount a minimal ledger and confirm the app serves it. ---
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"; docker rm -f fava-smoke >/dev/null 2>&1 || true' EXIT

cat > "$WORKDIR/main.bean" <<'BEAN'
option "operating_currency" "USD"
2020-01-01 open Assets:Cash
2020-01-01 open Equity:Opening-Balances
2020-01-01 * "seed"
  Assets:Cash             1.00 USD
  Equity:Opening-Balances
BEAN

echo "Booting container with a minimal ledger..."
docker run -d --name fava-smoke \
  -v "$WORKDIR/main.bean:/data/main.bean:ro" \
  -e FAVA_WORKERS=1 \
  -p 5001:5000 \
  "$IMAGE_NAME"

echo "Waiting for gunicorn to come up..."
ok=""
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5001/fava/" || true)
  # 200 (page) or 3xx (fava's own redirect) both mean the app is serving.
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
    ok="1"; echo "  served /fava/ -> HTTP $code"; break
  fi
  sleep 1
done

if [ -z "$ok" ]; then
  echo "❌ App did not serve /fava/ in time. Container logs:"
  docker logs fava-smoke || true
  exit 1
fi

echo "🎉 All fava image tests passed!"
