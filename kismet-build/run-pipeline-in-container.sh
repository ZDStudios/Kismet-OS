#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-preview}"

cd "$ROOT_DIR"

case "$MODE" in
  preview)
    INNER='./kismet-build/build-ubuntu-preview.sh'
    ;;
  live-build)
    INNER='./kismet-base/build/live-build-auto/build-kismet-live.sh'
    ;;
  *)
    echo "Usage: $0 [preview|live-build]" >&2
    exit 1
    ;;
esac

docker run --rm \
  --privileged \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  kismet-ubuntu-build \
  bash -lc "$INNER"
