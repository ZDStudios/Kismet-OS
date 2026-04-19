#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

docker build -f kismet-build/Dockerfile.ubuntu-build -t kismet-ubuntu-build .

docker run --rm -it \
  --privileged \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  kismet-ubuntu-build \
  bash
