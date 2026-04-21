#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"
OUTPUT_ISO="$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso"
BASE_ISO="$ROOT_DIR/kismet-build/cache/ubuntu-24.04-desktop-amd64.iso"
TARGET_FS="$("$ROOT_DIR/kismet-build/detect-livefs-path.sh" "$EXTRACT_DIR")"
SNAP_WORK="$WORK_DIR/test-gnome-snap"

command -v xorriso >/dev/null 2>&1 || fail "xorriso is required for host-side smoke tests. Run through test-preview-in-container.sh or install xorriso on the host."
command -v unsquashfs >/dev/null 2>&1 || fail "unsquashfs is required for host-side smoke tests. Run through test-preview-in-container.sh or install squashfs-tools on the host."

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

pass() {
  echo "[PASS] $*"
}

[ -f "$OUTPUT_ISO" ] || fail "Preview ISO is missing at $OUTPUT_ISO"
[ -f "$BASE_ISO" ] || fail "Base ISO is missing at $BASE_ISO"
[ -d "$EXTRACT_DIR" ] || fail "Extracted ISO tree is missing at $EXTRACT_DIR"
[ -d "$EDIT_DIR" ] || fail "Editable live rootfs is missing at $EDIT_DIR"
[ -f "$TARGET_FS" ] || fail "Live filesystem image is missing at $TARGET_FS"

ISO_LABEL="$(xorriso -indev "$OUTPUT_ISO" -pvd_info 2>/dev/null | awk -F': ' '/Volume [iI]d/ {gsub(/\047/, "", $2); print $2; exit}')"
[ "$ISO_LABEL" = "KISMET_DEV_PREVIEW" ] || fail "Unexpected ISO label: ${ISO_LABEL:-<empty>}"
pass "ISO label is $ISO_LABEL"

OS_RELEASE="$EDIT_DIR/etc/os-release"
grep -q 'NAME="Kismet OS"' "$OS_RELEASE" || fail "os-release still lacks Kismet branding"
grep -q 'PRETTY_NAME="Kismet OS 2 Preview"' "$OS_RELEASE" || fail "PRETTY_NAME not updated"
pass "Rootfs os-release branding looks correct"

grep -q '^Kismet OS 2 Preview' "$EDIT_DIR/etc/issue" || fail "/etc/issue still contains the old distro name"
grep -q '^Kismet OS 2 Preview' "$EDIT_DIR/etc/issue.net" || fail "/etc/issue.net still contains the old distro name"
pass "TTY branding looks correct"

[ -f "$EDIT_DIR/usr/share/xsessions/plasma.desktop" ] || fail "Plasma X session desktop entry missing"
[ -f "$EDIT_DIR/usr/share/wayland-sessions/plasma.desktop" ] || fail "Plasma Wayland session desktop entry missing"
[ ! -f "$EDIT_DIR/usr/share/xsessions/ubuntu.desktop" ] || fail "Ubuntu X session desktop entry still present"
pass "Session branding/layout files are in place"

rm -rf "$SNAP_WORK"
unsquashfs -d "$SNAP_WORK" "$EDIT_DIR/var/lib/snapd/snaps/gnome-42-2204_202.snap" >/dev/null
SNAP_DESKTOP="$SNAP_WORK/usr/share/ubuntu/applications/gnome-initial-setup.desktop"
[ -f "$SNAP_DESKTOP" ] || fail "Expected gnome-initial-setup desktop file not found in GNOME snap"
grep -q 'Welcome to Kismet OS' "$SNAP_DESKTOP" || fail "GNOME snap still says Welcome to Ubuntu"
pass "GNOME snap branding patch is present"

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

TARGET_NAME="$(basename "$TARGET_FS")"
SIZE_FILE="${TARGET_FS%.squashfs}.size"
[ -f "$SIZE_FILE" ] || fail "filesystem.size metadata missing"
ACTUAL_SIZE="$(stat -c '%s' "$TARGET_FS")"
RECORDED_SIZE="$(tr -d '[:space:]' < "$SIZE_FILE")"
[ "$ACTUAL_SIZE" = "$RECORDED_SIZE" ] || fail "filesystem.size mismatch, expected $ACTUAL_SIZE got $RECORDED_SIZE"
pass "filesystem.size matches $TARGET_NAME"

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
