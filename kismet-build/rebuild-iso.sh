#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
BASE_ISO="$ROOT_DIR/kismet-build/cache/ubuntu-24.04-desktop-amd64.iso"
TARGET_FS="$("$ROOT_DIR/kismet-build/detect-livefs-path.sh" "$EXTRACT_DIR")"
TARGET_NAME="$(basename "$TARGET_FS")"
NEW_FS="$WORK_DIR/$TARGET_NAME"
OUTPUT_DIR="$ROOT_DIR/kismet-build/output"
OUTPUT_ISO="$OUTPUT_DIR/kismet-os-dev-preview.iso"

if [ ! -d "$EXTRACT_DIR" ]; then
  echo "Extracted ISO tree not found. Run extract-ubuntu-iso.sh first."
  exit 1
fi

if [ ! -f "$NEW_FS" ]; then
  echo "Repacked squashfs not found at $NEW_FS. Run repack-live-rootfs.sh first."
  exit 1
fi

if [ ! -f "$BASE_ISO" ]; then
  echo "Base ISO not found at $BASE_ISO"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
cp -f "$NEW_FS" "$TARGET_FS"
"$ROOT_DIR/kismet-build/refresh-iso-metadata.sh" "$TARGET_FS"

if [ -f "$EXTRACT_DIR/md5sum.txt" ]; then
  echo "==> Refreshing md5sum.txt"
  (cd "$EXTRACT_DIR" && find . -type f ! -name md5sum.txt -exec md5sum {} + > md5sum.txt)
fi

echo "==> Building ISO with xorriso"
xorriso -as mkisofs \
  -r -V "KISMET_DEV_PREVIEW" \
  -o "$OUTPUT_ISO" \
  -J -l \
  --grub2-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$BASE_ISO" \
  --protective-msdos-label \
  -partition_cyl_align off \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b --interval:local_fs:12383488d-12393647d::"$BASE_ISO" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c /boot.catalog \
  -b /boot/grub/i386-pc/eltorito.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --grub2-boot-info \
  -eltorito-alt-boot \
  -e --interval:appended_partition_2_start_3095872s_size_10160d:all:: \
  -no-emul-boot \
  -boot-load-size 10160 \
  "$EXTRACT_DIR"

echo "==> ISO written to $OUTPUT_ISO"
