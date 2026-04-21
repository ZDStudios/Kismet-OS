#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"
TARGET_FS="$("$ROOT_DIR/kismet-build/detect-livefs-path.sh" "$EXTRACT_DIR")"
NEW_FS="$WORK_DIR/$(basename "$TARGET_FS")"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first."
  exit 1
fi

rm -f "$NEW_FS"

MKSQUASHFS_COMP="${MKSQUASHFS_COMP:-xz}"
MKSQUASHFS_PROCS="${MKSQUASHFS_PROCS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"

echo "==> Repacking $(basename "$NEW_FS") with $MKSQUASHFS_COMP compression"
mksquashfs "$EDIT_DIR" "$NEW_FS" -noappend -comp "$MKSQUASHFS_COMP" -processors "$MKSQUASHFS_PROCS"

echo "==> Repacked rootfs at $NEW_FS"
