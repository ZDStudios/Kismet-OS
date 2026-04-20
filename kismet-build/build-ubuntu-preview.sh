#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/kismet-build/work"
OUTPUT_DIR="$ROOT_DIR/kismet-build/output"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

"$ROOT_DIR/kismet-build/fetch-ubuntu-base.sh"
"$ROOT_DIR/kismet-build/render-package-plan.sh"
"$ROOT_DIR/kismet-build/render-chroot-install.sh"
"$ROOT_DIR/kismet-build/make-dev-preview-layout.sh"
"$ROOT_DIR/kismet-build/assemble-rootfs.sh"

if command -v bsdtar >/dev/null 2>&1; then
  "$ROOT_DIR/kismet-build/extract-ubuntu-iso.sh"
  "$ROOT_DIR/kismet-build/overlay-kismet-files.sh"
  "$ROOT_DIR/kismet-build/prepare-live-rootfs.sh"
  "$ROOT_DIR/kismet-build/apply-kismet-overlay.sh"
  "$ROOT_DIR/kismet-build/repack-live-rootfs.sh"
  "$ROOT_DIR/kismet-build/rebuild-iso.sh"
else
  echo "==> bsdtar is unavailable, so ISO extraction/customization is not fully runnable yet"
  "$ROOT_DIR/kismet-build/overlay-kismet-files.sh"
fi

echo "==> Kismet Ubuntu preview build scaffold"
echo "Build dir:  $BUILD_DIR"
echo "Output dir: $OUTPUT_DIR"
echo ""
echo "Current completed stages:"
echo "- Ubuntu base fetch"
echo "- package plan rendering"
echo "- chroot install script rendering"
echo "- Kismet filesystem/dev-preview layout"
echo "- rootfs assembly scaffold"
echo "- ISO extraction"
echo "- overlay preparation and application"
echo "- live rootfs repack"
echo "- ISO metadata refresh and rebuild"
echo ""
echo "Current remaining blockers to a fuller preview ISO:"
echo "- chroot package install stage not yet executed automatically"
echo "- ISO metadata/manifest refresh still needs broader validation"
echo "- full boot validation in a VM has not happened yet"
