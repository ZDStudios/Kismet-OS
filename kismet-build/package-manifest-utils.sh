#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_DIR="$ROOT_DIR/kismet-base/manifests"

resolve_package_name() {
  case "$1" in
    gnome-disks)
      echo "gnome-disk-utility"
      ;;
    yaru-gtk-theme)
      echo "yaru-theme-gtk"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

manifest_packages() {
  local manifest
  for manifest in "$@"; do
    [ -f "$MANIFEST_DIR/$manifest.txt" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%%#*}"
      line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -n "$line" ] || continue
      resolve_package_name "$line"
    done < "$MANIFEST_DIR/$manifest.txt"
  done | awk '!seen[$0]++'
}
