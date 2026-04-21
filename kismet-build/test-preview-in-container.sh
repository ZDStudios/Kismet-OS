#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-smoke}"

cd "$ROOT_DIR"

docker build -f kismet-build/Dockerfile.ubuntu-build -t kismet-ubuntu-build .

case "$MODE" in
  smoke)
    INNER='./kismet-build/smoke-test-preview.sh'
    ;;
  branding-scan)
    INNER='./kismet-build/scan-preview-branding.py'
    ;;
  build-and-smoke)
    INNER='./kismet-build/build-ubuntu-preview.sh && ./kismet-build/smoke-test-preview.sh'
    ;;
  build-smoke-scan)
    INNER='./kismet-build/build-ubuntu-preview.sh && ./kismet-build/smoke-test-preview.sh && ./kismet-build/scan-preview-branding.py'
    ;;
  refresh-branding-scan)
    INNER='./kismet-build/force-kismet-branding.sh && ./kismet-build/repack-live-rootfs.sh && ./kismet-build/rebuild-iso.sh && ./kismet-build/smoke-test-preview.sh && ./kismet-build/scan-preview-branding.py'
    ;;
  *)
    echo "Usage: $0 [smoke|branding-scan|build-and-smoke|build-smoke-scan|refresh-branding-scan]" >&2
    exit 1
    ;;
esac

docker run --rm \
  --privileged \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  kismet-ubuntu-build \
  bash -lc "$INNER"
