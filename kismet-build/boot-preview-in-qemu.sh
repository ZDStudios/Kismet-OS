#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_PATH="${1:-$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso}"
RUNTIME_DIR="$ROOT_DIR/kismet-build/work/qemu-smoke"
MONITOR_SOCKET="$RUNTIME_DIR/monitor.sock"
SERIAL_LOG="$RUNTIME_DIR/serial.log"
SCREENSHOT_PATH="$RUNTIME_DIR/boot-screenshot.ppm"
SCREENSHOT_PNG="$RUNTIME_DIR/boot-screenshot.png"
MEMORY_MB="${QEMU_MEMORY_MB:-4096}"
SMP_CPUS="${QEMU_SMP_CPUS:-4}"
BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-45}"
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

[ -f "$ISO_PATH" ] || fail "ISO not found at $ISO_PATH"
command -v "$QEMU_BIN" >/dev/null 2>&1 || fail "qemu-system-x86_64 not found"
command -v python3 >/dev/null 2>&1 || fail "python3 is required for QEMU monitor access"

mkdir -p "$RUNTIME_DIR"
rm -f "$MONITOR_SOCKET" "$SERIAL_LOG" "$SCREENSHOT_PATH" "$SCREENSHOT_PNG"

ACCEL_ARGS=("-machine" "q35")
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL_ARGS=("-machine" "q35,accel=kvm")
fi

cleanup() {
  if [ -f "$RUNTIME_DIR/qemu.pid" ]; then
    kill "$(cat "$RUNTIME_DIR/qemu.pid")" 2>/dev/null || true
    rm -f "$RUNTIME_DIR/qemu.pid"
  fi
}
trap cleanup EXIT

"$QEMU_BIN" \
  "${ACCEL_ARGS[@]}" \
  -m "$MEMORY_MB" \
  -smp "$SMP_CPUS" \
  -boot d \
  -cdrom "$ISO_PATH" \
  -display none \
  -vga virtio \
  -monitor "unix:$MONITOR_SOCKET,server,nowait" \
  -serial "file:$SERIAL_LOG" \
  -netdev user,id=n1 -device virtio-net-pci,netdev=n1 \
  -daemonize \
  -pidfile "$RUNTIME_DIR/qemu.pid"

sleep "$BOOT_WAIT_SECONDS"

if [ ! -S "$MONITOR_SOCKET" ]; then
  fail "QEMU monitor socket was not created"
fi

MONITOR_SOCKET="$MONITOR_SOCKET" SCREENSHOT_PATH="$SCREENSHOT_PATH" python3 - <<'PY' >/dev/null 2>&1 || true
import os
import socket
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(os.environ['MONITOR_SOCKET'])
cmd = f"screendump {os.environ['SCREENSHOT_PATH']}\nquit\n".encode()
sock.sendall(cmd)
try:
    sock.shutdown(socket.SHUT_WR)
except OSError:
    pass
sock.close()
PY

if [ -f "$SCREENSHOT_PNG" ]; then
  echo "Screenshot: $SCREENSHOT_PNG"
elif [ -f "$SCREENSHOT_PATH" ]; then
  echo "Screenshot: $SCREENSHOT_PATH"
else
  echo "Screenshot: unavailable"
fi

echo "Serial log: $SERIAL_LOG"
if [ -s "$SERIAL_LOG" ]; then
  tail -n 40 "$SERIAL_LOG"
else
  echo "(serial log is empty, expected for a graphical boot path)"
fi

echo "QEMU boot smoke run completed."
