#!/bin/bash
set -e

IMAGE_NAME=$1

if [ -z "$IMAGE_NAME" ]; then
  echo "Error: Image name is required."
  echo "Usage: $0 <image_name>"
  exit 1
fi

echo "Testing openclaw base image: $IMAGE_NAME"

# Confirm we did not regress the upstream non-root user.
echo "Checking image runs as non-root..."
USER_OUTPUT=$(docker run --rm --entrypoint sh "$IMAGE_NAME" -c "id -un")
if [ "$USER_OUTPUT" != "node" ]; then
  echo "❌ Error: image runs as '$USER_OUTPUT', expected 'node'."
  exit 1
fi
echo "✅ User is 'node'."

# Layered tools must be on PATH for the agent to invoke them.
echo "Checking defuddle..."
docker run --rm --entrypoint defuddle "$IMAGE_NAME" --version

# Smoke check the upstream binary is still callable through the original
# entrypoint. We're not booting the gateway here — just exercising node.
echo "Checking node..."
docker run --rm --entrypoint node "$IMAGE_NAME" --version

echo "🎉 All openclaw base image tests passed!"
