#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTRACT_DIR="${1:-$ROOT_DIR/kismet-build/work/ubuntu-iso}"
INSTALL_SOURCES="$EXTRACT_DIR/casper/install-sources.yaml"

if [ -f "$INSTALL_SOURCES" ]; then
  DETECTED_PATH="$(awk '
    /^- default: true$/ { in_default=1; next }
    /^- default: / { in_default=0 }
    in_default && $1 == "path:" { print $2; exit }
  ' "$INSTALL_SOURCES")"

  if [ -n "${DETECTED_PATH:-}" ] && [ -f "$EXTRACT_DIR/casper/$DETECTED_PATH" ]; then
    printf '%s\n' "$EXTRACT_DIR/casper/$DETECTED_PATH"
    exit 0
  fi
fi

FIRST_MATCH="$(find "$EXTRACT_DIR/casper" -maxdepth 1 -type f -name '*.squashfs' ! -name '*.gpg' | sort | head -n 1)"
if [ -n "$FIRST_MATCH" ]; then
  printf '%s\n' "$FIRST_MATCH"
  exit 0
fi

echo "Unable to detect a live squashfs image under $EXTRACT_DIR/casper" >&2
exit 1
