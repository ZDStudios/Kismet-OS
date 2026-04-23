#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/kismet-build/output"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/chroot-install-packages.sh"

# shellcheck source=./package-manifest-utils.sh
source "$ROOT_DIR/kismet-build/package-manifest-utils.sh"

mapfile -t packages < <(manifest_packages core desktop dev)

{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  echo 'apt update'
  printf 'apt install -y'
  for pkg in "${packages[@]}"; do
    printf ' %s' "$pkg"
  done
  printf '\n\n'
  echo '# AI/vendor packages are intentionally excluded here until their repo/bundle install path is wired.'
} > "$OUT_FILE"

chmod +x "$OUT_FILE"
echo "==> Wrote $OUT_FILE"
