#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD_DIR="$ROOT_DIR/kismet-base/build/live-build-auto/work"
CONFIG_DIR="$BUILD_DIR/config"
OVERLAY_DIR="$CONFIG_DIR/includes.chroot"
HOOK_DIR="$CONFIG_DIR/hooks/live"
PACKAGE_LIST="$CONFIG_DIR/package-lists/kismet.list.chroot"
AUTO_DIR="$CONFIG_DIR/auto"

rm -rf "$BUILD_DIR"
mkdir -p "$OVERLAY_DIR" "$HOOK_DIR" "$AUTO_DIR" "$(dirname "$PACKAGE_LIST")"
mkdir -p \
  "$OVERLAY_DIR/usr/share/plymouth/themes/kismet" \
  "$OVERLAY_DIR/usr/share/backgrounds/kismet" \
  "$OVERLAY_DIR/usr/share/sddm/themes/kismet" \
  "$OVERLAY_DIR/usr/local/lib/kismet"

cat > "$AUTO_DIR/config" <<'EOF'
#!/bin/sh
set -e
lb config noauto \
  --mode ubuntu \
  --distribution noble \
  --archive-areas "main restricted universe multiverse" \
  --binary-images iso-hybrid \
  --debian-installer false \
  --apt-indices false \
  --bootappend-live "boot=live components quiet splash" \
  --iso-application "Kismet OS" \
  --iso-publisher "Kismet OS" \
  --iso-volume "KISMET_OS"
EOF
chmod +x "$AUTO_DIR/config"

cat > "$PACKAGE_LIST" <<'EOF'
plasma-desktop
sddm
konsole
dolphin
kate
plasma-discover
plasma-workspace-wayland
kitty
plymouth
plymouth-themes
curl
wget
git
vim
neovim
htop
unzip
zip
tmux
zsh
openssh-client
openssh-server
flatpak
ca-certificates
software-properties-common
apt-transport-https
build-essential
cmake
gdb
python3
python3-pip
python3-venv
python3-fastapi
python3-uvicorn
python3-watchdog
python3-requests
python3-pydantic
nodejs
npm
ripgrep
fd-find
jq
gh
ollama
EOF

cp -a "$ROOT_DIR/kismet-base/config/." "$OVERLAY_DIR/"
mkdir -p "$OVERLAY_DIR/usr/local/lib/kismet"
cp -f "$ROOT_DIR/kismet-base/config/usr/local/lib/kismet/kismet_agent_runner.py" "$OVERLAY_DIR/usr/local/lib/kismet/"
cp -f "$ROOT_DIR/kismet-base/config/usr/local/lib/kismet/kismet-firstboot-wizard" "$OVERLAY_DIR/usr/local/lib/kismet/"
cp -f "$ROOT_DIR/kismet-base/config/usr/local/lib/kismet/kismet-ctl" "$OVERLAY_DIR/usr/local/lib/kismet/"
cp -f "$ROOT_DIR/kismet-base/config/usr/local/lib/kismet/model-loader.sh" "$OVERLAY_DIR/usr/local/lib/kismet/"
cp -a "$ROOT_DIR/kismet-theme/plymouth/." "$OVERLAY_DIR/usr/share/plymouth/themes/kismet/"
cp -a "$ROOT_DIR/kismet-theme/wallpapers/." "$OVERLAY_DIR/usr/share/backgrounds/kismet/"
cp -a "$ROOT_DIR/kismet-theme/sddm/." "$OVERLAY_DIR/usr/share/sddm/themes/kismet/"
cp -f "$ROOT_DIR/kismet-base/build/live-build-auto/configure-kismet-chroot.sh" "$HOOK_DIR/9999-kismet-setup.chroot"
chmod +x "$HOOK_DIR/9999-kismet-setup.chroot"

cd "$BUILD_DIR"
lb clean --purge || true
cp -a "$CONFIG_DIR/." .
./auto/config
lb build

echo "==> Live-build ISO should be under $BUILD_DIR"
