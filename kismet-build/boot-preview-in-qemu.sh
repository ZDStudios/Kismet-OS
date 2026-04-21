#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_PATH="${1:-$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso}"
RUNTIME_DIR="${QEMU_RUNTIME_DIR:-/tmp/kismet-qemu-smoke}"
MONITOR_SOCKET="$RUNTIME_DIR/monitor.sock"
SERIAL_LOG="$RUNTIME_DIR/serial.log"
SCREENSHOT_PATH="$RUNTIME_DIR/boot-screenshot.ppm"
SCREENSHOT_PNG="$RUNTIME_DIR/boot-screenshot.png"
MONITOR_LOG="$RUNTIME_DIR/monitor.log"
MEMORY_MB="${QEMU_MEMORY_MB:-4096}"
SMP_CPUS="${QEMU_SMP_CPUS:-4}"
BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-45}"
SCREENSHOT_WAIT_SECONDS="${QEMU_SCREENSHOT_WAIT_SECONDS:-10}"
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

[ -f "$ISO_PATH" ] || fail "ISO not found at $ISO_PATH"
command -v "$QEMU_BIN" >/dev/null 2>&1 || fail "qemu-system-x86_64 not found"
command -v python3 >/dev/null 2>&1 || fail "python3 is required for QEMU monitor access"

mkdir -p "$RUNTIME_DIR"
rm -f "$MONITOR_SOCKET" "$SERIAL_LOG" "$SCREENSHOT_PATH" "$SCREENSHOT_PNG" "$MONITOR_LOG"
echo "Runtime dir: $RUNTIME_DIR"

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
  -vga std \
  -monitor "unix:$MONITOR_SOCKET,server,nowait" \
  -serial "file:$SERIAL_LOG" \
  -netdev user,id=n1 -device virtio-net-pci,netdev=n1 \
  -daemonize \
  -pidfile "$RUNTIME_DIR/qemu.pid"

sleep "$BOOT_WAIT_SECONDS"

if [ ! -S "$MONITOR_SOCKET" ]; then
  fail "QEMU monitor socket was not created"
fi

MONITOR_SOCKET="$MONITOR_SOCKET" SCREENSHOT_PATH="$SCREENSHOT_PATH" MONITOR_LOG="$MONITOR_LOG" SCREENSHOT_WAIT_SECONDS="$SCREENSHOT_WAIT_SECONDS" python3 - <<'PY' || true
import os
import socket
import time
from pathlib import Path

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.settimeout(5)
sock.connect(os.environ['MONITOR_SOCKET'])
commands = [
    'info version',
    'sendkey ret',
    f"screendump {os.environ['SCREENSHOT_PATH']}",
    'quit',
]
Path(os.environ['MONITOR_LOG']).write_text('', encoding='utf-8')
with Path(os.environ['MONITOR_LOG']).open('a', encoding='utf-8') as log:
    for command in commands:
        sock.sendall((command + '\n').encode())
        time.sleep(0.5)
        try:
            data = sock.recv(8192)
        except socket.timeout:
            data = b''
        if data:
            log.write(data.decode('utf-8', 'ignore'))
try:
    sock.shutdown(socket.SHUT_WR)
except OSError:
    pass
sock.close()
for _ in range(int(os.environ['SCREENSHOT_WAIT_SECONDS'])):
    path = Path(os.environ['SCREENSHOT_PATH'])
    if path.exists() and path.stat().st_size > 0:
        break
    time.sleep(1)
PY

if [ -f "$SCREENSHOT_PATH" ] && head -c 2 "$SCREENSHOT_PATH" 2>/dev/null | grep -q '^P6'; then
  echo "Screenshot: $SCREENSHOT_PATH"
else
  echo "Screenshot: unavailable"
  [ -f "$MONITOR_LOG" ] && echo "Monitor log: $MONITOR_LOG"
fi

echo "Serial log: $SERIAL_LOG"
if [ -s "$SERIAL_LOG" ]; then
  tail -n 40 "$SERIAL_LOG"
else
  echo "(serial log is empty, expected for a graphical boot path)"
fi

echo "QEMU boot smoke run completed."
