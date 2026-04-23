#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/kismet-build/output"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/package-plan.txt"

# shellcheck source=./package-manifest-utils.sh
source "$ROOT_DIR/kismet-build/package-manifest-utils.sh"

{
  echo "# Kismet OS package plan"
  echo
  for manifest in core desktop dev ai; do
    manifest_path="$ROOT_DIR/kismet-base/manifests/$manifest.txt"
    [ -f "$manifest_path" ] || continue
    echo "## $manifest"
    cat "$manifest_path"
    echo
  done

  echo "## resolved-preview-install-set"
  manifest_packages core desktop dev
  echo

  echo "## deferred-vendor-or-extra-packages"
  manifest_packages ai
  echo
} > "$OUT_FILE"

echo "==> Wrote $OUT_FILE"
