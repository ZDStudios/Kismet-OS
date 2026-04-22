#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_PATH="$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso"
ZIP_PATH="$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.zip"
MODE="${1:-test}"

cd "$ROOT_DIR"

case "$MODE" in
  pipeline)
    echo "==> Rebuilding preview ISO in Docker"
    ./kismet-build/test-preview-in-container.sh pipeline
    ;;
  test)
    echo "==> Rebuilding preview ISO and running smoke validation in Docker"
    ./kismet-build/test-preview-in-container.sh build
    ;;
  qemu)
    echo "==> Rebuilding preview ISO, validating, and running BIOS QEMU boot smoke in Docker"
    ./kismet-build/test-preview-in-container.sh qemu-boot
    ;;
  qemu-uefi)
    echo "==> Rebuilding preview ISO, validating, and running UEFI QEMU boot smoke in Docker"
    ./kismet-build/test-preview-in-container.sh qemu-uefi
    ;;
  qemu-gnome)
    echo "==> Rebuilding preview ISO, validating, and running GNOME-focused QEMU boot smoke in Docker"
    ./kismet-build/test-preview-in-container.sh build
    ./kismet-build/test-preview-in-container.sh qemu-gnome
    ;;
  *)
    echo "Usage: $0 [pipeline|test|qemu|qemu-uefi|qemu-gnome]" >&2
    exit 1
    ;;
esac

[ -f "$ISO_PATH" ] || {
  echo "Preview ISO missing after run: $ISO_PATH" >&2
  exit 1
}

printf '\n==> Preview artifacts\n'
ls -lh "$ISO_PATH"
if [ -f "$ZIP_PATH" ]; then
  ls -lh "$ZIP_PATH"
fi

printf '\n==> SHA256\n'
sha256sum "$ISO_PATH"
if [ -f "$ZIP_PATH" ]; then
  sha256sum "$ZIP_PATH"
fi
