#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
LIVE_FS="$($ROOT_DIR/kismet-build/detect-livefs-path.sh "$EXTRACT_DIR")"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"

if [ ! -f "$LIVE_FS" ]; then
  echo "Live filesystem not found at $LIVE_FS"
  echo "Run fetch-ubuntu-base.sh and extract-ubuntu-iso.sh first."
  exit 1
fi

mkdir -p "$WORK_DIR"
rm -rf "$EDIT_DIR"
mkdir -p "$EDIT_DIR"

echo "==> Unsquashing live filesystem"
unsquashfs -no-xattrs -d "$EDIT_DIR" "$LIVE_FS"

echo "==> Writable live rootfs prepared at $EDIT_DIR"
