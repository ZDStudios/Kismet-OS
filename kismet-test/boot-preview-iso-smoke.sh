#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_PATH="${1:-$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso}"
WORK_DIR="$ROOT_DIR/kismet-test/work/qemu-smoke"
QEMU_RUNTIME_DIR="/tmp/kismet-qemu-smoke"
MONITOR_SOCKET="$QEMU_RUNTIME_DIR/monitor.sock"
SCREENSHOT_PATH="$QEMU_RUNTIME_DIR/boot-smoke.ppm"
SCREENSHOT_COPY_PATH="$WORK_DIR/boot-smoke.ppm"
SERIAL_LOG="$WORK_DIR/serial.log"
MONITOR_LOG="$WORK_DIR/monitor.log"
PID_FILE="$WORK_DIR/qemu.pid"
BOOT_WAIT_SECS="${BOOT_WAIT_SECS:-45}"
MEMORY_MB="${MEMORY_MB:-4096}"
SSH_PORT="${SSH_PORT:-2222}"
VGA_DEVICE="${VGA_DEVICE:-std}"

mkdir -p "$WORK_DIR" "$QEMU_RUNTIME_DIR"
rm -f "$MONITOR_SOCKET" "$SCREENSHOT_PATH" "$SCREENSHOT_COPY_PATH" "$SERIAL_LOG" "$MONITOR_LOG" "$PID_FILE"

if [ ! -f "$ISO_PATH" ]; then
  echo "ISO not found at $ISO_PATH" >&2
  exit 1
fi

for bin in qemu-system-x86_64 python3; do
  command -v "$bin" >/dev/null
 done

cleanup() {
  if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE")"
    if kill -0 "$PID" >/dev/null 2>&1; then
      kill "$PID" >/dev/null 2>&1 || true
      sleep 2
      kill -9 "$PID" >/dev/null 2>&1 || true
    fi
  fi
}
trap cleanup EXIT

(
  cd "$QEMU_RUNTIME_DIR"
  exec qemu-system-x86_64 \
    -m "$MEMORY_MB" \
    -smp 2 \
    -cdrom "$ISO_PATH" \
    -boot d \
    -snapshot \
    -vga "$VGA_DEVICE" \
    -netdev user,id=n1,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
    -device e1000,netdev=n1 \
    -monitor unix:"$MONITOR_SOCKET",server,nowait \
    -serial file:"$SERIAL_LOG" \
    -display none
) >"$WORK_DIR/qemu.stdout.log" 2>"$WORK_DIR/qemu.stderr.log" &

echo $! > "$PID_FILE"

for _ in $(seq 1 40); do
  if [ -S "$MONITOR_SOCKET" ]; then
    break
  fi
  sleep 1
done

if [ ! -S "$MONITOR_SOCKET" ]; then
  echo "QEMU monitor socket did not appear." >&2
  exit 1
fi

sleep "$BOOT_WAIT_SECS"

if ! kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "QEMU exited before smoke window completed." >&2
  tail -100 "$WORK_DIR/qemu.stderr.log" >&2 || true
  exit 1
fi

python3 - "$MONITOR_SOCKET" "$SCREENSHOT_PATH" "$MONITOR_LOG" <<'PY'
import socket
import sys
import time

sock_path = sys.argv[1]
out_path = sys.argv[2]
log_path = sys.argv[3]
chunks = []
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
    sock.connect(sock_path)
    time.sleep(0.5)
    try:
        chunks.append(sock.recv(4096))
    except Exception:
        pass
    sock.sendall(f"info status\ninfo registers\nscreendump {out_path}\nquit\n".encode())
    time.sleep(1)
    while True:
        try:
            data = sock.recv(4096)
        except Exception:
            break
        if not data:
            break
        chunks.append(data)
with open(log_path, 'wb') as fh:
    for chunk in chunks:
        fh.write(chunk)
PY

if [ ! -f "$SCREENSHOT_PATH" ]; then
  echo "Smoke screenshot was not captured." >&2
  exit 1
fi

cp -f "$SCREENSHOT_PATH" "$SCREENSHOT_COPY_PATH"

FILE_SIZE="$(wc -c < "$SCREENSHOT_COPY_PATH")"
if [ "$FILE_SIZE" -lt 1024 ]; then
  echo "Smoke screenshot looks too small to be useful." >&2
  exit 1
fi

echo "==> QEMU smoke boot completed"
echo "Screenshot: $SCREENSHOT_COPY_PATH"
echo "Serial log:  $SERIAL_LOG"
echo "Monitor log: $MONITOR_LOG"
