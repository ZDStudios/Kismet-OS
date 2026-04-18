#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAYOUT_DIR="$ROOT_DIR/kismet-build/dev-preview-layout"

mkdir -p "$LAYOUT_DIR/filesystem/usr/local/bin"
mkdir -p "$LAYOUT_DIR/filesystem/etc/systemd/system"
mkdir -p "$LAYOUT_DIR/filesystem/etc/skel/.config/kismet"
mkdir -p "$LAYOUT_DIR/filesystem/etc/skel/.config"
mkdir -p "$LAYOUT_DIR/filesystem/usr/share/plymouth/themes/kismet"
mkdir -p "$LAYOUT_DIR/filesystem/usr/share/backgrounds/kismet"
mkdir -p "$LAYOUT_DIR/filesystem/usr/share/sddm/themes/kismet"

cp -f "$ROOT_DIR/kismet-base/config/usr/local/bin/kismet-firstboot" "$LAYOUT_DIR/filesystem/usr/local/bin/"
cp -f "$ROOT_DIR/kismet-base/config/etc/systemd/system/kismet-firstboot.service" "$LAYOUT_DIR/filesystem/etc/systemd/system/"
cp -f "$ROOT_DIR/kismet-base/config/skel/.config/kismet/kismet.conf" "$LAYOUT_DIR/filesystem/etc/skel/.config/kismet/"
cp -f "$ROOT_DIR/kismet-base/config/skel/.config/kismet/desktop-defaults.md" "$LAYOUT_DIR/filesystem/etc/skel/.config/kismet/"
cp -f "$ROOT_DIR/kismet-base/config/skel/.config/kdeglobals" "$LAYOUT_DIR/filesystem/etc/skel/.config/"
cp -f "$ROOT_DIR/kismet-base/config/skel/.config/konsolerc" "$LAYOUT_DIR/filesystem/etc/skel/.config/"
cp -f "$ROOT_DIR/kismet-base/config/skel/.zshrc" "$LAYOUT_DIR/filesystem/etc/skel/"
cp -f "$ROOT_DIR/kismet-theme/plymouth/kismet.plymouth" "$LAYOUT_DIR/filesystem/usr/share/plymouth/themes/kismet/"
cp -f "$ROOT_DIR/kismet-theme/plymouth/kismet.script" "$LAYOUT_DIR/filesystem/usr/share/plymouth/themes/kismet/"
cp -f "$ROOT_DIR/kismet-theme/sddm/theme.conf.user" "$LAYOUT_DIR/filesystem/usr/share/sddm/themes/kismet/"
cp -f "$ROOT_DIR/kismet-theme/wallpapers/kismet-wallpaper.svg" "$LAYOUT_DIR/filesystem/usr/share/backgrounds/kismet/"

chmod +x "$LAYOUT_DIR/filesystem/usr/local/bin/kismet-firstboot"

echo "==> Dev preview filesystem layout prepared at $LAYOUT_DIR"
