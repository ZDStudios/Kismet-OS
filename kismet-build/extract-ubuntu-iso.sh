#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$ROOT_DIR/kismet-build/cache"
WORK_DIR="$ROOT_DIR/kismet-build/work"
ISO_PATH="$CACHE_DIR/ubuntu-24.04-desktop-amd64.iso"
EXTRACT_DIR="$WORK_DIR/ubuntu-iso"

mkdir -p "$CACHE_DIR" "$WORK_DIR" "$EXTRACT_DIR"

if [ ! -f "$ISO_PATH" ]; then
  echo "Base ISO not found at $ISO_PATH"
  echo "Run fetch-ubuntu-base.sh first."
  exit 1
fi

if ! command -v bsdtar >/dev/null 2>&1; then
  echo "bsdtar is required to extract the ISO contents."
  exit 1
fi

echo "==> Extracting Ubuntu ISO into $EXTRACT_DIR"
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
bsdtar -C "$EXTRACT_DIR" -xf "$ISO_PATH"

echo "==> Extraction complete"
