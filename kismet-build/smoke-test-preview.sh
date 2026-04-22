#!/usr/bin/env bash
# smoke-test-preview.sh - Validate the Kismet OS preview ISO
# Run AFTER the ISO is rebuilt.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"
OUTPUT_ISO="$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso"
BASE_ISO="$ROOT_DIR/kismet-build/cache/ubuntu-24.04-desktop-amd64.iso"
TARGET_FS="$("$ROOT_DIR/kismet-build/detect-livefs-path.sh" "$EXTRACT_DIR")"
SNAP_WORK="$WORK_DIR/test-gnome-snap"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

pass() {
  echo "[PASS] $*"
}

# Verify ISO exists
[ -f "$OUTPUT_ISO" ] || fail "Preview ISO is missing at $OUTPUT_ISO"
[ -f "$BASE_ISO" ] || fail "Base ISO is missing at $BASE_ISO"
[ -d "$EXTRACT_DIR" ] || fail "Extracted ISO tree is missing at $EXTRACT_DIR"
[ -d "$EDIT_DIR" ] || fail "Editable live rootfs is missing at $EDIT_DIR"
[ -f "$TARGET_FS" ] || fail "Live filesystem image is missing at $TARGET_FS"

# Verify ISO label
ISO_LABEL="$(xorriso -indev "$OUTPUT_ISO" -pvd_info 2>/dev/null | awk -F': ' '/Volume [iI]d/ {gsub(/\047/, "", $2); print $2; exit}')"
[ "$ISO_LABEL" = "KISMET_DEV_PREVIEW" ] || fail "Unexpected ISO label: ${ISO_LABEL:-<empty>}"
pass "ISO label is $ISO_LABEL"

# Verify os-release
OS_RELEASE="$EDIT_DIR/etc/os-release"
grep -q 'NAME="Kismet OS"' "$OS_RELEASE" || fail "os-release still lacks Kismet branding"
grep -q 'PRETTY_NAME="Kismet OS 2 Preview"' "$OS_RELEASE" || fail "PRETTY_NAME not updated"
pass "Rootfs os-release branding looks correct"

# Verify TTY branding
grep -q '^Kismet OS 2 Preview' "$EDIT_DIR/etc/issue" || fail "/etc/issue still contains the old distro name"
grep -q '^Kismet OS 2 Preview' "$EDIT_DIR/etc/issue.net" || fail "/etc/issue.net still contains the old distro name"
pass "TTY branding looks correct"

# Verify GNOME sessions (primary) and Plasma sessions (optional)
[ -f "$EDIT_DIR/usr/share/xsessions/gnome.desktop" ] || fail "GNOME X session desktop entry missing"
[ -f "$EDIT_DIR/usr/share/xsessions/gnome-xorg.desktop" ] || fail "GNOME Xorg session desktop entry missing"
[ -f "$EDIT_DIR/usr/share/wayland-sessions/gnome.desktop" ] || fail "GNOME Wayland session desktop entry missing"
pass "GNOME session desktop entries are in place"

# Verify core GNOME session packages exist in the live rootfs
for pkg in ubuntu-desktop-minimal gnome-shell gnome-session-bin gdm3 gnome-shell-common xwayland gnome-shell-extension-ubuntu-dock; do
  chroot "$EDIT_DIR" dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q 'install ok installed' || fail "Required GNOME package missing from live rootfs: $pkg"
done
pass "Core GNOME session packages are installed"

# Verify Ubuntu sessions are removed
[ ! -f "$EDIT_DIR/usr/share/xsessions/ubuntu.desktop" ] || fail "Ubuntu X session desktop entry still present"
[ ! -f "$EDIT_DIR/usr/share/wayland-sessions/ubuntu-wayland.desktop" ] || fail "Ubuntu Wayland session still present"
pass "Ubuntu session entries removed"

# Verify display manager
grep -q '/usr/sbin/gdm3' "$EDIT_DIR/etc/X11/default-display-manager" || fail "GDM is not set as the default display manager"
pass "GDM is the default display manager"

# Verify GDM auto-login for live user
if [ -f "$EDIT_DIR/etc/gdm3/custom.conf" ]; then
  grep -q 'AutomaticLogin=live' "$EDIT_DIR/etc/gdm3/custom.conf" || fail "GDM auto-login for live user not configured"
  grep -q 'DefaultSession=gnome.desktop' "$EDIT_DIR/etc/gdm3/custom.conf" || fail "GDM default GNOME session is not configured"
  grep -q 'InitialSetupEnable=false' "$EDIT_DIR/etc/gdm3/custom.conf" || fail "GDM initial setup is not disabled"
  pass "GDM auto-login for live user configured"
fi

# Verify live account exists in the editable rootfs
chroot "$EDIT_DIR" getent passwd live >/dev/null 2>&1 || fail "live user is missing from live rootfs"
chroot "$EDIT_DIR" getent shadow live >/dev/null 2>&1 || fail "live user shadow entry is missing from live rootfs"
pass "live account exists in live rootfs"

# Verify GDM user list hiding (via dconf database)
if [ -f "$EDIT_DIR/etc/dconf/db/gdm.d/00-kismet-greeter" ]; then
  grep -q 'disable-user-list=true' "$EDIT_DIR/etc/dconf/db/gdm.d/00-kismet-greeter" || fail "GDM disable-user-list not set in dconf"
  pass "GDM user list hiding configured via dconf"
fi

# Verify kismet assets
[ -f "$EDIT_DIR/usr/share/pixmaps/kismet-logo.svg" ] || fail "Kismet logo asset missing from pixmaps"
[ -f "$EDIT_DIR/usr/local/bin/kismet" ] || fail "kismet CLI missing"
[ -f "$EDIT_DIR/usr/local/bin/kismet-game-library" ] || fail "kismet-game-library launcher missing"
[ -f "$EDIT_DIR/etc/skel/.local/share/applications/kismet-game-library.desktop" ] || fail "Kismet Game Library desktop entry missing"
chmod +x "$EDIT_DIR/usr/local/bin/kismet" 2>/dev/null || true
chmod +x "$EDIT_DIR/usr/local/bin/kismet-game-library" 2>/dev/null || true
pass "Kismet CLI, game library launcher, and branding assets are present"

# Verify bundled game packages are present
for pkg in aisleriot gnome-2048 gnome-chess gnome-mahjongg gnome-mines gnome-sudoku frozen-bubble atomix; do
  chroot "$EDIT_DIR" dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q 'install ok installed' || fail "Bundled game package missing from live rootfs: $pkg"
done
pass "Bundled game package set is present"

# Verify GNOME favorite apps include the game library
if [ -f "$EDIT_DIR/etc/dconf/db/local.d/00-kismet-desktop" ]; then
  grep -q "kismet-game-library.desktop" "$EDIT_DIR/etc/dconf/db/local.d/00-kismet-desktop" || fail "Game library is not pinned in GNOME favorites"
  pass "GNOME favorites include the game library"
fi

# Verify GNOME snap branding patch
rm -rf "$SNAP_WORK"
if [ -f "$EDIT_DIR/var/lib/snapd/snaps/gnome-42-2204_202.snap" ]; then
  unsquashfs -d "$SNAP_WORK" "$EDIT_DIR/var/lib/snapd/snaps/gnome-42-2204_202.snap" >/dev/null
  SNAP_DESKTOP="$SNAP_WORK/usr/share/ubuntu/applications/gnome-initial-setup.desktop"
  if [ -f "$SNAP_DESKTOP" ]; then
    grep -q 'Welcome to Kismet OS' "$SNAP_DESKTOP" || fail "GNOME snap still says Welcome to Ubuntu"
    pass "GNOME snap branding patch is present"
  fi
fi

# Verify software catalog cache
if [ -f "$EDIT_DIR/var/cache/swcatalog/cache/C-os-catalog.xb" ]; then
  python3 - "$EDIT_DIR/var/cache/swcatalog/cache/C-os-catalog.xb" <<'PY' || fail "Software catalog cache still contains Install Ubuntu"
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = path.read_bytes()
if b'Install Ubuntu' in data:
    raise SystemExit(1)
PY
  pass "Software catalog cache no longer advertises Install Ubuntu"
fi

# Verify filesystem size metadata
TARGET_NAME="$(basename "$TARGET_FS")"
SIZE_FILE="${TARGET_FS%.squashfs}.size"
[ -f "$SIZE_FILE" ] || fail "filesystem.size metadata missing"
ACTUAL_SIZE="$(stat -c '%s' "$TARGET_FS")"
RECORDED_SIZE="$(tr -d '[:space:]' < "$SIZE_FILE")"
[ "$ACTUAL_SIZE" = "$RECORDED_SIZE" ] || fail "filesystem.size mismatch, expected $ACTUAL_SIZE got $RECORDED_SIZE"
pass "filesystem.size matches $TARGET_NAME"

# Verify install-sources.yaml
if [ -f "$EXTRACT_DIR/casper/install-sources.yaml" ]; then
  awk -v target="$TARGET_NAME" -v size="$ACTUAL_SIZE" '
    $1 == "path:" { current=$2 }
    $1 == "size:" && current == target { found=1; if ($2 != size) exit 2 }
    END { if (!found) exit 3 }
  ' "$EXTRACT_DIR/casper/install-sources.yaml" || fail "install-sources.yaml was not refreshed for $TARGET_NAME"
  pass "install-sources.yaml matches the rebuilt squashfs"
fi

rm -rf "$SNAP_WORK"
pass "Preview ISO smoke tests completed"