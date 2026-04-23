#!/usr/bin/env bash
# test-preview-in-container.sh - Run Kismet OS build and test inside Docker
#
# Usage:
#   ./test-preview-in-container.sh build          # Full pipeline rebuild + smoke tests + branding scan
#   ./test-preview-in-container.sh pipeline       # Full pipeline rebuild only
#   ./test-preview-in-container.sh smoke          # Smoke test existing ISO
#   ./run-smoke-test.sh                           # Prefer Docker smoke automatically, fallback to host
#   ./test-preview-in-container.sh branding       # Branding scan only
#   ./test-preview-in-container.sh qemu-boot      # Full rebuild + BIOS QEMU boot test
#   ./test-preview-in-container.sh qemu-uefi      # Full rebuild + UEFI QEMU boot test
#   ./test-preview-in-container.sh qemu-smoke     # BIOS QEMU boot smoke only
#   ./test-preview-in-container.sh qemu-smoke-uefi # UEFI QEMU boot smoke only
#   ./test-preview-in-container.sh interactive    # Drop into interactive shell
#
# Environment variables:
#   KISMET_ISO_PATH         - Path to ISO (default: /workspace/kismet-build/output/kismet-os-dev-preview.iso)
#   KISMET_MEMORY_MB        - QEMU RAM in MB (default: 4096, also mapped to QEMU_MEMORY_MB)
#   KISMET_SMP              - QEMU CPU count (default: 4, also mapped to QEMU_SMP_CPUS)
#   QEMU_MEMORY_MB          - Direct RAM override consumed by boot-preview-in-qemu.sh
#   QEMU_SMP_CPUS           - Direct CPU override consumed by boot-preview-in-qemu.sh
#   QEMU_BOOT_WAIT_SECONDS  - Wait before screenshotting booted VM (default from boot script)
#   QEMU_SENDKEYS           - Comma-separated QEMU monitor sendkey sequence (default: ret,ret)
#   QEMU_FIRMWARE           - Override firmware mode passed to boot-preview-in-qemu.sh (bios or uefi)
#   KISMET_SKIP_DOCKER_BUILD - Set to 1 to reuse the current kismet-ubuntu-build image

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-build}"

cd "$ROOT_DIR"

# Ensure docker image is up to date unless explicitly skipped
if [ "${KISMET_SKIP_DOCKER_BUILD:-0}" != "1" ]; then
  docker build -f kismet-build/Dockerfile.ubuntu-build -t kismet-ubuntu-build .
fi

run_inner() {
  docker run --rm \
    --privileged \
    -v "$ROOT_DIR":/workspace \
    -w /workspace \
    -e KISMET_ISO_PATH="${KISMET_ISO_PATH:-}" \
    -e KISMET_MEMORY_MB="${KISMET_MEMORY_MB:-4096}" \
    -e KISMET_SMP="${KISMET_SMP:-4}" \
    -e QEMU_MEMORY_MB="${QEMU_MEMORY_MB:-${KISMET_MEMORY_MB:-4096}}" \
    -e QEMU_SMP_CPUS="${QEMU_SMP_CPUS:-${KISMET_SMP:-4}}" \
    -e QEMU_BIN=/usr/bin/qemu-system-x86_64 \
    -e QEMU_BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-}" \
    -e QEMU_SENDKEYS="${QEMU_SENDKEYS:-}" \
    -e QEMU_FIRMWARE="${QEMU_FIRMWARE:-}" \
    kismet-ubuntu-build \
    bash -lc "$1"
}

case "$MODE" in
  build)
    echo "==> Full build: containerized preview pipeline + smoke + branding-scan"
    run_inner 'bash ./kismet-build/build-ubuntu-preview.sh
               bash ./kismet-build/smoke-test-preview.sh
               python3 ./kismet-build/scan-preview-branding.py'
    echo "==> Full build completed successfully"
    ;;

  pipeline)
    echo "==> Full pipeline rebuild only"
    run_inner 'bash ./kismet-build/build-ubuntu-preview.sh'
    echo "==> Full pipeline rebuild completed"
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
    echo "==> Full build + BIOS QEMU boot test"
    run_inner 'QEMU_FIRMWARE="${QEMU_FIRMWARE:-bios}" bash ./kismet-build/build-ubuntu-preview.sh
               bash ./kismet-build/smoke-test-preview.sh
               python3 ./kismet-build/scan-preview-branding.py
               QEMU_FIRMWARE="${QEMU_FIRMWARE:-bios}" bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> BIOS QEMU boot test completed"
    ;;

  qemu-uefi)
    echo "==> Full build + UEFI QEMU boot test"
    run_inner 'bash ./kismet-build/build-ubuntu-preview.sh
               bash ./kismet-build/smoke-test-preview.sh
               python3 ./kismet-build/scan-preview-branding.py
               QEMU_FIRMWARE=uefi bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> UEFI QEMU boot test completed"
    ;;

  qemu-smoke)
    echo "==> BIOS QEMU boot smoke only (requires existing ISO)"
    run_inner 'QEMU_FIRMWARE="${QEMU_FIRMWARE:-bios}" bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> BIOS QEMU boot smoke completed"
    ;;

  qemu-smoke-uefi)
    echo "==> UEFI QEMU boot smoke only (requires existing ISO)"
    run_inner 'QEMU_FIRMWARE=uefi bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> UEFI QEMU boot smoke completed"
    ;;

  qemu-gnome)
    echo "==> QEMU GNOME-focused boot smoke"
    run_inner 'QEMU_BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-75}" QEMU_SENDKEYS="${QEMU_SENDKEYS:-ret,ret,ret}" bash ./kismet-build/boot-preview-in-qemu.sh'
    echo "==> QEMU GNOME boot smoke completed"
    ;;

  interactive|shell)
    echo "==> Dropping into interactive shell in Kismet build container"
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
    echo "Usage: $0 [build|pipeline|smoke|branding|qemu-boot|qemu-uefi|qemu-smoke|qemu-smoke-uefi|qemu-gnome|interactive|prepare]" >&2
    exit 1
    ;;
esac
