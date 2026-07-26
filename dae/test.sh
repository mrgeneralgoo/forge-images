#!/bin/bash
set -e

IMAGE_NAME=$1

if [ -z "$IMAGE_NAME" ]; then
  echo "Error: Image name is required."
  echo "Usage: $0 <image_name>"
  exit 1
fi

echo "Testing image: $IMAGE_NAME"

# --- Toolchain: dae + the updater dependencies must all be present. ---
echo "Checking dae..."
docker run --rm "$IMAGE_NAME" dae --version
echo "Checking updater toolchain (curl, python3, crond, od, tini)..."
docker run --rm --entrypoint sh "$IMAGE_NAME" -c '
  set -e
  for t in dae curl python3 crond od tini; do
    command -v "$t" >/dev/null || { echo "missing: $t"; exit 1; }
  done
  echo "  all present"
'

# --- dae validate: unprivileged config parse (files must be 0600). ---
echo "Checking 'dae validate' on a minimal config..."
docker run --rm --entrypoint sh "$IMAGE_NAME" -c '
  set -e
  printf "global{}\nrouting{}\n" > /tmp/c.dae && chmod 600 /tmp/c.dae
  dae validate -c /tmp/c.dae
'

# --- run-job.sh guards: no manifest -> skip rules; bad arg -> usage error. ---
echo "Checking run-job.sh skips rule updates when no manifest is mounted..."
docker run --rm --entrypoint run-job.sh "$IMAGE_NAME" rules --no-jitter | grep -q 'skipping rule update'
echo "Checking run-job.sh rejects a bad argument..."
if docker run --rm --entrypoint run-job.sh "$IMAGE_NAME" bogus; then
  echo "❌ run-job.sh should have failed on a bad argument"; exit 1
fi

# --- convert-rules.py: transform a fixture manifest, incl. a custom target
#     group (proves the image is not hard-coded to any personal group name). ---
echo "Checking convert-rules.py with a custom target group..."
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cat > "$WORKDIR/manifest.json" <<'JSON'
{"providers":[
  {"name":"custom","behavior":"classical","target":"MY_GROUP","url":"file:///dev/null"}
]}
JSON
cat > "$WORKDIR/custom.yaml" <<'YAML'
payload:
  - DOMAIN,api.example.com
  - IP-CIDR,203.0.113.0/24,no-resolve
YAML
docker run --rm -v "$WORKDIR:/work:rw" --entrypoint python3 "$IMAGE_NAME" \
  /opt/dae/convert-rules.py --manifest /work/manifest.json --source-dir /work --output /work/out.dae
grep -q "domain(full: 'api.example.com') -> MY_GROUP" "$WORKDIR/out.dae"
grep -q "dip('203.0.113.0/24') -> MY_GROUP" "$WORKDIR/out.dae"
echo "  convert-rules.py output OK (custom target honored)"

# NOTE: the dae daemon itself is not booted here — it needs a Linux host with
# eBPF (CAP_BPF/CAP_NET_ADMIN, /sys/fs/bpf) and host networking, which CI
# runners do not provide. This smoke test covers the image's toolchain, config
# validation, the rule-conversion pipeline, and the updater guards.

echo "🎉 All dae image tests passed!"
