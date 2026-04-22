#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

have_tool() {
  command -v "$1" >/dev/null 2>&1
}

if have_tool docker; then
  echo "==> Running preview smoke test in Docker build environment"
  exec "$ROOT_DIR/kismet-build/test-preview-in-container.sh" smoke
fi

echo "==> Docker not found, attempting host smoke test"
exec "$ROOT_DIR/kismet-build/smoke-test-preview.sh"
