#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

docker run --rm \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  kismet-ubuntu-build \
  bash -lc './kismet-build/build-ubuntu-preview.sh'
