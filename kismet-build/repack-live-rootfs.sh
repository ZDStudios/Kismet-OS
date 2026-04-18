#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"
NEW_FS="$WORK_DIR/filesystem.squashfs"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first."
  exit 1
fi

rm -f "$NEW_FS"

echo "==> Repacking filesystem.squashfs"
mksquashfs "$EDIT_DIR" "$NEW_FS" -noappend

echo "==> Repacked rootfs at $NEW_FS"
