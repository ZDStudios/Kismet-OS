#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"
OVERLAY_DIR="$ROOT_DIR/kismet-build/work/kismet-overlay"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first."
  exit 1
fi

if [ ! -d "$OVERLAY_DIR" ]; then
  echo "Kismet overlay not found. Run overlay-kismet-files.sh first."
  exit 1
fi

echo "==> Applying Kismet overlay into live rootfs"
cp -a "$OVERLAY_DIR/." "$EDIT_DIR/"

echo "==> Overlay applied"
