#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run the preview pipeline first." >&2
  exit 1
fi

test -x "$EDIT_DIR/usr/bin/sddm"
grep -qx '/usr/bin/sddm' "$EDIT_DIR/etc/X11/default-display-manager"
test -f "$EDIT_DIR/usr/share/sddm/themes/kismet/Main.qml"
grep -q '^Current=kismet$' "$EDIT_DIR/etc/sddm.conf.d/10-kismet.conf"
grep -q 'kismet-wallpaper.svg' "$EDIT_DIR/usr/share/sddm/themes/kismet/theme.conf.user"
test -L "$EDIT_DIR/etc/systemd/system/display-manager.service"
test -L "$EDIT_DIR/etc/systemd/system/graphical.target.wants/display-manager.service"

echo "==> Live rootfs branding validation passed"
