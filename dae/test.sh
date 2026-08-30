#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:-}
if [[ -z "$image" ]]; then
  echo "usage: $0 IMAGE" >&2
  exit 2
fi

docker run --rm --entrypoint sh "$image" -s <<'CHECK'
set -eu

dae --version
for tool in dae curl python3 crond od tini; do
  command -v "$tool" >/dev/null
 done

printf 'global{}\nrouting{}\n' > /tmp/config.dae
chmod 600 /tmp/config.dae
dae validate -c /tmp/config.dae

dir=$(mktemp -d)
cat > "$dir/manifest.json" <<'JSON'
{"providers":[{"name":"custom","behavior":"classical","target":"MY_GROUP","url":"file:///dev/null"}]}
JSON
cat > "$dir/custom.yaml" <<'YAML'
payload:
  - DOMAIN,api.example.com
  - IP-CIDR,203.0.113.0/24,no-resolve
YAML
python3 /opt/dae/convert-rules.py \
  --manifest "$dir/manifest.json" \
  --source-dir "$dir" \
  --output "$dir/out.dae"
grep -q "domain(full: 'api.example.com') -> MY_GROUP" "$dir/out.dae"
grep -q "dip('203.0.113.0/24') -> MY_GROUP" "$dir/out.dae"
CHECK

docker run --rm --entrypoint run-job.sh "$image" rules --no-jitter |
  grep -q 'skipping rule update'
if docker run --rm --entrypoint run-job.sh "$image" bogus; then
  echo 'run-job.sh accepted an invalid argument' >&2
  exit 1
fi

echo "dae checks passed: $image"
