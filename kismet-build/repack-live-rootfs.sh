#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"
TARGET_FS="$($ROOT_DIR/kismet-build/detect-livefs-path.sh "$EXTRACT_DIR")"
NEW_FS="$WORK_DIR/$(basename "$TARGET_FS")"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first."
  exit 1
fi

rm -f "$NEW_FS"

echo "==> Repacking $(basename "$NEW_FS")"
mksquashfs "$EDIT_DIR" "$NEW_FS" -noappend

echo "==> Repacked rootfs at $NEW_FS"
