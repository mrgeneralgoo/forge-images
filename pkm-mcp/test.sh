#!/bin/bash
set -e

IMAGE_NAME=$1

if [ -z "$IMAGE_NAME" ]; then
  echo "Error: Image name is required."
  echo "Usage: $0 <image_name>"
  exit 1
fi

echo "Testing base image: $IMAGE_NAME"

echo "Checking Node.js..."
docker run --rm "$IMAGE_NAME" node -v

echo "Checking npm..."
docker run --rm "$IMAGE_NAME" npm -v

echo "Checking git..."
docker run --rm "$IMAGE_NAME" git --version

echo "Checking ripgrep..."
docker run --rm "$IMAGE_NAME" rg --version

echo "Checking python3 (native module build)..."
docker run --rm "$IMAGE_NAME" python3 --version

echo "Checking make (native module build)..."
docker run --rm "$IMAGE_NAME" make --version | head -1

echo "🎉 All pkm-mcp base image tests passed!"
