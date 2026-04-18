#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/kismet-build/output"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/chroot-install-packages.sh"

mapfile -t packages < <(
  cat \
    "$ROOT_DIR/kismet-base/manifests/core.txt" \
    "$ROOT_DIR/kismet-base/manifests/desktop.txt" \
    "$ROOT_DIR/kismet-base/manifests/dev.txt" \
  | sed '/^#/d;/^$/d'
)

{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  echo 'apt update'
  printf 'apt install -y'
  for pkg in "${packages[@]}"; do
    printf ' %s' "$pkg"
  done
  printf '\n\n'
  echo '# AI packages and vendor installers are handled separately.'
} > "$OUT_FILE"

chmod +x "$OUT_FILE"
echo "==> Wrote $OUT_FILE"
