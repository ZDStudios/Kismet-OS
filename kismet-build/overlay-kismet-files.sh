#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAYOUT_DIR="$ROOT_DIR/kismet-build/dev-preview-layout/filesystem"
OVERLAY_DIR="$ROOT_DIR/kismet-build/work/kismet-overlay"

mkdir -p "$OVERLAY_DIR"
rm -rf "$OVERLAY_DIR"
mkdir -p "$OVERLAY_DIR"

if [ ! -d "$LAYOUT_DIR" ]; then
  echo "Dev preview layout not found. Run make-dev-preview-layout.sh first."
  exit 1
fi

echo "==> Copying Kismet overlay files"
cp -a "$LAYOUT_DIR/." "$OVERLAY_DIR/"

echo "==> Overlay prepared at $OVERLAY_DIR"
