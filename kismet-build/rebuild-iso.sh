#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
NEW_FS="$WORK_DIR/filesystem.squashfs"
OUTPUT_DIR="$ROOT_DIR/kismet-build/output"
OUTPUT_ISO="$OUTPUT_DIR/kismet-os-dev-preview.iso"

if [ ! -d "$EXTRACT_DIR" ]; then
  echo "Extracted ISO tree not found. Run extract-ubuntu-iso.sh first."
  exit 1
fi

if [ ! -f "$NEW_FS" ]; then
  echo "Repacked squashfs not found. Run repack-live-rootfs.sh first."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
cp -f "$NEW_FS" "$EXTRACT_DIR/casper/minimal.standard.live.squashfs"

if [ -f "$EXTRACT_DIR/md5sum.txt" ]; then
  echo "==> Refreshing md5sum.txt"
  (cd "$EXTRACT_DIR" && find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt)
fi

echo "==> Building ISO with xorriso"
xorriso -as mkisofs \
  -r -V "KISMET_DEV_PREVIEW" \
  -o "$OUTPUT_ISO" \
  -J -l \
  "$EXTRACT_DIR"

echo "==> ISO written to $OUTPUT_ISO"
