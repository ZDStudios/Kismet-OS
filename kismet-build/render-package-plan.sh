#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/kismet-build/output"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/package-plan.txt"

{
  echo "# Kismet OS package plan"
  echo
  for manifest in core desktop dev ai; do
    echo "## $manifest"
    cat "$ROOT_DIR/kismet-base/manifests/$manifest.txt"
    echo
  done
} > "$OUT_FILE"

echo "==> Wrote $OUT_FILE"
