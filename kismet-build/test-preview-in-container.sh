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
  build-and-smoke)
    INNER='./kismet-build/build-ubuntu-preview.sh && ./kismet-build/smoke-test-preview.sh'
    ;;
  *)
    echo "Usage: $0 [smoke|build-and-smoke]" >&2
    exit 1
    ;;
esac

docker run --rm \
  --privileged \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  kismet-ubuntu-build \
  bash -lc "$INNER"
