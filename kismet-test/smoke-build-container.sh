#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="kismet-ubuntu-build"

cd "$ROOT_DIR"

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  docker build -f kismet-build/Dockerfile.ubuntu-build -t "$IMAGE_NAME" .
fi

docker run --rm \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  "$IMAGE_NAME" \
  bash -lc '
set -euo pipefail
for bin in bsdtar xorriso unsquashfs mksquashfs curl python3; do
  command -v "$bin" >/dev/null
  echo "==> Found $bin"
done
./kismet-build/render-package-plan.sh >/dev/null
./kismet-build/render-chroot-install.sh >/dev/null
./kismet-build/make-dev-preview-layout.sh >/dev/null
./kismet-build/assemble-rootfs.sh >/dev/null
if [ -f ./kismet-build/cache/ubuntu-24.04-desktop-amd64.iso ]; then
  echo "==> Cached Ubuntu ISO is present for preview pipeline"
else
  echo "==> Ubuntu ISO cache not present yet, fetch step will run during full preview build"
fi
'

echo "==> Ubuntu build container smoke test passed"
