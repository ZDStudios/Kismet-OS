#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/kismet-base/build/live-build-auto/work"
CONFIG_DIR="$BUILD_DIR/config"
OVERLAY_DIR="$CONFIG_DIR/includes.chroot"
HOOK_DIR="$CONFIG_DIR/hooks/live"
PACKAGE_LIST="$CONFIG_DIR/package-lists/kismet.list.chroot"
AUTO_DIR="$CONFIG_DIR/auto"
LOG_DIR="$ROOT_DIR/kismet-base/build/live-build-auto/logs"
PROFILE="${KISMET_PROFILE:-minimal}"
KEEP_WORK="${KISMET_KEEP_WORK:-0}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/live-build-$PROFILE-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"
if [ "$KEEP_WORK" != "1" ]; then
  rm -rf "$BUILD_DIR"
fi
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

case "$PROFILE" in
  minimal)
    cp "$SCRIPT_DIR/kismet-packages.minimal.chroot" "$PACKAGE_LIST"
    ;;
  full)
    cp "$SCRIPT_DIR/kismet-packages.full.chroot" "$PACKAGE_LIST"
    ;;
  *)
    echo "Unsupported KISMET_PROFILE=$PROFILE (use minimal or full)" >&2
    exit 1
    ;;
esac

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
{
  echo "==> Kismet live-build"
  echo "Profile: $PROFILE"
  echo "Workdir: $BUILD_DIR"
  echo "Log: $LOG_FILE"
  lb clean --purge || true
  cp -a "$CONFIG_DIR/." .
  ./auto/config
  lb build
  echo "==> Live-build ISO should be under $BUILD_DIR"
} 2>&1 | tee "$LOG_FILE"
