#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
GRUB_CFG="$EXTRACT_DIR/boot/grub/grub.cfg"
LOOPBACK_CFG="$EXTRACT_DIR/boot/grub/loopback.cfg"
TXT_CFG="$EXTRACT_DIR/isolinux/txt.cfg"

if [ ! -d "$EXTRACT_DIR" ]; then
  echo "Extracted ISO tree not found. Run extract-ubuntu-iso.sh first." >&2
  exit 1
fi

patch_grub_cfg() {
  local path="$1"
  [ -f "$path" ] || return 0

  python3 - "$path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = text.replace('menuentry "Try or Install Ubuntu" {', 'menuentry "Try or Install Kismet OS" {')
text = text.replace('menuentry "Ubuntu (safe graphics)" {', 'menuentry "Kismet OS (safe graphics)" {')
text = text.replace('menuentry \'Test memory\' {', 'menuentry \'Memory test\' {')
text = text.replace('\ngrub_platform\nif [ "$grub_platform" = "efi" ]; then\n', '\nif [ "$grub_platform" = "efi" ]; then\n')
path.write_text(text, encoding='utf-8')
PY
}

patch_isolinux_cfg() {
  local path="$1"
  [ -f "$path" ] || return 0

  python3 - "$path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = text.replace('menu label ^Try or Install Ubuntu', 'menu label ^Try or Install Kismet OS')
text = text.replace('menu label Ubuntu (^safe graphics)', 'menu label Kismet OS (^safe graphics)')
text = text.replace('menu label ^OEM install (for manufacturers)', 'menu label ^OEM install (for builders)')
text = text.replace('menu default', 'menu default', 1)
path.write_text(text, encoding='utf-8')
PY
}

patch_grub_cfg "$GRUB_CFG"
patch_grub_cfg "$LOOPBACK_CFG"
patch_isolinux_cfg "$TXT_CFG"

echo "==> Patched bootloader branding in extracted ISO"
