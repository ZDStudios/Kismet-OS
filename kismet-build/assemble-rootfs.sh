#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_DIR="$ROOT_DIR/kismet-build/stage-rootfs"

mkdir -p "$STAGE_DIR"
mkdir -p "$STAGE_DIR/etc/systemd/system"
mkdir -p "$STAGE_DIR/usr/local/bin"
mkdir -p "$STAGE_DIR/etc/skel/.config/kismet"

echo "==> Assembling Kismet rootfs scaffold into $STAGE_DIR"
cp -f "$ROOT_DIR/kismet-base/config/etc/systemd/system/kismet-firstboot.service" "$STAGE_DIR/etc/systemd/system/"
cp -f "$ROOT_DIR/kismet-base/config/usr/local/bin/kismet-firstboot" "$STAGE_DIR/usr/local/bin/"
cp -f "$ROOT_DIR/kismet-base/config/skel/.config/kismet/kismet.conf" "$STAGE_DIR/etc/skel/.config/kismet/"
chmod +x "$STAGE_DIR/usr/local/bin/kismet-firstboot"

echo "==> Rootfs scaffold assembled"
