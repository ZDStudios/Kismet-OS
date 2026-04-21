#!/usr/bin/env bash
# test-preview-in-container.sh - Run Kismet OS build and test inside Docker
#
# Usage:
#   ./test-preview-in-container.sh build           # Full rebuild + smoke tests
#   ./test-preview-in-container.sh smoke           # Smoke test existing ISO
#   ./test-preview-in-container.sh branding        # Branding scan only
#   ./test-preview-in-container.sh qemu-boot        # Full rebuild + QEMU boot test
#   ./test-preview-in-container.sh qemu-smoke      # QEMU boot smoke only
#   ./test-preview-in-container.sh interactive     # Drop into interactive shell
#
# Environment variables:
#   KISMET_ISO_PATH   - Path to ISO (default: /workspace/kismet-build/output/kismet-os-dev-preview.iso)
#   KISMET_MEMORY_MB  - QEMU RAM in MB (default: 4096)
#   KISMET_SMP        - QEMU CPU count (default: 4)
#   QEMU_BOOT_WAIT_SECONDS - Wait before screenshotting booted VM (default from boot script)
#   QEMU_SENDKEYS     - Comma-separated QEMU monitor sendkey sequence (default: ret,ret)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-build}"

cd "$ROOT_DIR"

# Ensure docker image is up to date
docker build -f kismet-build/Dockerfile.ubuntu-build -t kismet-ubuntu-build .

run_inner() {
  docker run --rm \
    --privileged \
    -v "$ROOT_DIR":/workspace \
    -w /workspace \
    -e KISMET_ISO_PATH="${KISMET_ISO_PATH:-}" \
    -e KISMET_MEMORY_MB="${KISMET_MEMORY_MB:-4096}" \
    -e KISMET_SMP="${KISMET_SMP:-4}" \
    -e QEMU_BIN=/usr/bin/qemu-system-x86_64 \
    -e QEMU_BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-}" \
    -e QEMU_SENDKEYS="${QEMU_SENDKEYS:-}" \
    kismet-ubuntu-build \
    bash -lc "$1"
}

case "$MODE" in
  build)
    echo "==> Full build: layout + branding + live-user + repack + smoke + branding-scan"
    run_inner 'bash ./kismet-build/make-dev-preview-layout.sh
               bash ./kismet-build/overlay-kismet-files.sh
               bash ./kismet-build/apply-kismet-overlay.sh
               bash ./kismet-build/install-kismet-packages-into-rootfs.sh
               bash ./kismet-build/force-kismet-branding.sh
               bash ./kismet-build/setup-live-user.sh
               bash ./kismet-build/repack-live-rootfs.sh
               bash ./kismet-build/rebuild-iso.sh
               bash ./kismet-build/smoke-test-preview.sh
               python3 ./kismet-build/scan-preview-branding.py'
    echo "==> Full build completed successfully"
    ;;

  smoke)
    echo "==> Smoke test only"
    run_inner 'bash ./kismet-build/smoke-test-preview.sh'
    echo "==> Smoke tests passed"
    ;;

  branding)
    echo "==> Branding scan only"
    run_inner 'python3 ./kismet-build/scan-preview-branding.py'
    echo "==> Branding scan passed"
    ;;

  qemu-boot|boot)
    echo "==> Full build + QEMU boot test"
    run_inner 'bash ./kismet-build/make-dev-preview-layout.sh
               bash ./kismet-build/overlay-kismet-files.sh
               bash ./kismet-build/apply-kismet-overlay.sh
               bash ./kismet-build/install-kismet-packages-into-rootfs.sh
               bash ./kismet-build/force-kismet-branding.sh
               bash ./kismet-build/setup-live-user.sh
               bash ./kismet-build/repack-live-rootfs.sh
               bash ./kismet-build/rebuild-iso.sh
               bash ./kismet-build/smoke-test-preview.sh
               python3 ./kismet-build/scan-preview-branding.py
               bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> QEMU boot test completed"
    ;;

  qemu-smoke)
    echo "==> QEMU boot smoke only (requires existing ISO)"
    run_inner 'bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> QEMU boot smoke completed"
    ;;

  qemu-gnome)
    echo "==> QEMU GNOME-focused boot smoke"
    run_inner 'QEMU_BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-75}" QEMU_SENDKEYS="${QEMU_SENDKEYS:-ret,ret,ret}" bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> QEMU GNOME boot smoke completed"
    ;;

  interactive|shell)
    echo "==> Dropping into interactive shell in build container"
    docker run --rm -it \
      --privileged \
      -v "$ROOT_DIR":/workspace \
      -w /workspace \
      kismet-ubuntu-build \
      bash -lc 'echo "Container ready. Root: /workspace"; bash'
    ;;

  prepare)
    echo "==> Prepare live rootfs only (for debugging)"
    run_inner 'bash ./kismet-build/prepare-live-rootfs.sh'
    echo "==> Live rootfs prepared"
    ;;

  *)
    echo "Usage: $0 [build|smoke|branding|qemu-boot|qemu-smoke|qemu-gnome|interactive|prepare]" >&2
    exit 1
    ;;
esac