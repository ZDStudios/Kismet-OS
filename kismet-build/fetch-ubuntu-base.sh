#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$ROOT_DIR/kismet-build/cache"
mkdir -p "$CACHE_DIR"

ISO_URL="https://old-releases.ubuntu.com/releases/24.04.0/ubuntu-24.04-desktop-amd64.iso"
ISO_PATH="$CACHE_DIR/ubuntu-24.04-desktop-amd64.iso"
TMP_PATH="$ISO_PATH.part"

if [ -e "$ISO_PATH" ]; then
  size=$(wc -c < "$ISO_PATH")
  if [ "$size" -gt 1000000000 ]; then
    echo "==> Ubuntu base ISO already present"
    echo "$ISO_PATH"
    exit 0
  fi
  echo "==> Cached ISO is too small or invalid, removing it"
  rm -f "$ISO_PATH"
fi

echo "==> Downloading Ubuntu base ISO"
curl -fL "$ISO_URL" -o "$TMP_PATH"

size=$(wc -c < "$TMP_PATH")
if [ "$size" -lt 1000000000 ]; then
  echo "Downloaded file is unexpectedly small ($size bytes)."
  rm -f "$TMP_PATH"
  exit 1
fi

mv "$TMP_PATH" "$ISO_PATH"
echo "$ISO_PATH"
