#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/kismet-build/work"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"
EDIT_DIR="$WORK_DIR/live-rootfs-edit"
TARGET_FS="${1:-$("$ROOT_DIR/kismet-build/detect-livefs-path.sh" "$EXTRACT_DIR")}"
TARGET_NAME="$(basename "$TARGET_FS")"
TARGET_SIZE="$(stat -c '%s' "$TARGET_FS")"
SIZE_FILE="${TARGET_FS%.squashfs}.size"
MANIFEST_FILE="${TARGET_FS%.squashfs}.manifest"
DEFAULT_MANIFEST="$EXTRACT_DIR/casper/filesystem.manifest"
DEFAULT_SIZE_FILE="$EXTRACT_DIR/casper/filesystem.size"
INSTALL_SOURCES="$EXTRACT_DIR/casper/install-sources.yaml"

if [ ! -f "$TARGET_FS" ]; then
  echo "Live filesystem image not found at $TARGET_FS" >&2
  exit 1
fi

printf '%s\n' "$TARGET_SIZE" > "$SIZE_FILE"
printf '%s\n' "$TARGET_SIZE" > "$DEFAULT_SIZE_FILE"

echo "==> Updated size metadata for $TARGET_NAME"

if [ -d "$EDIT_DIR/var/lib/dpkg" ] && command -v chroot >/dev/null 2>&1 && [ -x "$EDIT_DIR/usr/bin/dpkg-query" ]; then
  echo "==> Refreshing package manifest from editable rootfs"
  chroot "$EDIT_DIR" /usr/bin/dpkg-query -W --showformat='${Package} ${Version}\n' | sort > "$MANIFEST_FILE"
  cp "$MANIFEST_FILE" "$DEFAULT_MANIFEST"
else
  echo "==> Skipping manifest refresh, editable rootfs or dpkg-query is unavailable"
fi

if [ -f "$INSTALL_SOURCES" ]; then
  python3 - "$INSTALL_SOURCES" "$TARGET_NAME" "$TARGET_SIZE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
target_name = sys.argv[2]
target_size = sys.argv[3]
text = path.read_text()
current = None
out = []
for line in text.splitlines(True):
    m_path = re.match(r'^(\s*path:\s*)(\S+)(\s*)$', line)
    if m_path:
        current = m_path.group(2)
        out.append(line)
        continue
    m_size = re.match(r'^(\s*size:\s*)(\d+)(\s*)$', line)
    if m_size and current == target_name:
        out.append(f"{m_size.group(1)}{target_size}{m_size.group(3)}")
        continue
    out.append(line)
path.write_text(''.join(out))
PY
  echo "==> Updated install-sources.yaml size for $TARGET_NAME"
fi
