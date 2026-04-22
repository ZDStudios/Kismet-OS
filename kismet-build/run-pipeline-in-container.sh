#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-preview}"
EXTRA_ARGS="${*:2}"

cd "$ROOT_DIR"

case "$MODE" in
  preview)
    INNER='./kismet-build/build-ubuntu-preview.sh'
    ;;
  preview-test)
    INNER='./kismet-build/test-preview-in-container.sh build'
    ;;
  preview-qemu)
    INNER='./kismet-build/test-preview-in-container.sh qemu-boot'
    ;;
  preview-qemu-uefi)
    INNER='./kismet-build/test-preview-in-container.sh qemu-uefi'
    ;;
  preview-qemu-gnome)
    INNER='./kismet-build/test-preview-in-container.sh build && ./kismet-build/test-preview-in-container.sh qemu-gnome'
    ;;
  live-build)
    INNER='./kismet-base/build/live-build-auto/build-kismet-live.sh'
    ;;
  *)
    echo "Usage: $0 [preview|preview-test|preview-qemu|preview-qemu-uefi|preview-qemu-gnome|live-build]" >&2
    exit 1
    ;;
esac

docker run --rm \
  --privileged \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  -e KISMET_SKIP_DOCKER_BUILD=1 \
  kismet-ubuntu-build \
  bash -lc "$INNER${EXTRA_ARGS:+ $EXTRA_ARGS}"
