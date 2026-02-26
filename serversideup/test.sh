#!/bin/bash
set -e

IMAGE_NAME=$1

if [ -z "$IMAGE_NAME" ]; then
  echo "Error: Image name is required."
  echo "Usage: $0 <image_name>"
  exit 1
fi

echo "Testing image: $IMAGE_NAME"

# 1. Check if PHP can run and print its version
echo "Checking PHP version..."
docker run --rm "$IMAGE_NAME" php -v

# 2. Check if the required extensions from Dockerfile are successfully installed and loaded
echo "Checking required PHP extensions..."
REQUIRED_EXTS=("igbinary" "zstd" "lzf" "mysqli" "exif" "imagick" "gd" "intl" "timezonedb" "bcmath" "shmop" "redis")

for ext in "${REQUIRED_EXTS[@]}"; do
  echo "Verifying extension: $ext"
  if ! docker run --rm "$IMAGE_NAME" php -m | grep -qi "$ext"; then
    echo "❌ Error: PHP extension '$ext' is not loaded!"
    exit 1
  fi
  echo "✅ Extension '$ext' is loaded."
done

echo "🎉 All serversideup tests passed successfully!"
