#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run the preview pipeline first." >&2
  exit 1
fi

test -x "$EDIT_DIR/usr/sbin/gdm3"
grep -qx '/usr/sbin/gdm3' "$EDIT_DIR/etc/X11/default-display-manager"
test -f "$EDIT_DIR/usr/share/xsessions/gnome.desktop"
test -f "$EDIT_DIR/usr/share/wayland-sessions/gnome.desktop"
grep -q '^AutomaticLogin=live$' "$EDIT_DIR/etc/gdm3/custom.conf"
grep -q '^DefaultSession=gnome.desktop$' "$EDIT_DIR/etc/gdm3/custom.conf"
grep -q '^disable-user-list=true$' "$EDIT_DIR/etc/dconf/db/gdm.d/00-kismet-greeter"
test -x "$EDIT_DIR/usr/local/bin/kismet-game-library"
test -f "$EDIT_DIR/etc/skel/.local/share/applications/kismet-game-library.desktop"
grep -q 'kismet-game-library.desktop' "$EDIT_DIR/etc/dconf/db/local.d/00-kismet-desktop"
for icon in kismet-ai-suite kismet-ai-center kismet-hermes kismet-opencode kismet-run-exe; do
  test -f "$EDIT_DIR/usr/share/icons/hicolor/scalable/apps/${icon}.svg"
done
grep -q '^Icon=kismet-ai-suite$' "$EDIT_DIR/etc/skel/.local/share/applications/kismet.desktop"
grep -q '^Icon=kismet-ai-center$' "$EDIT_DIR/etc/skel/.local/share/applications/kismet-ai-center.desktop"
grep -q '^Icon=kismet-hermes$' "$EDIT_DIR/etc/skel/.local/share/applications/kismet-hermes.desktop"
grep -q '^Icon=kismet-opencode$' "$EDIT_DIR/etc/skel/.local/share/applications/kismet-opencode.desktop"
grep -q '^Icon=kismet-run-exe$' "$EDIT_DIR/etc/skel/.local/share/applications/kismet-run-exe.desktop"

echo "==> Live rootfs GNOME, game-library, and custom app icon validation passed"
