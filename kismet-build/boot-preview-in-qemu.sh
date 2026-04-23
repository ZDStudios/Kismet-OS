#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_PATH="${1:-$ROOT_DIR/kismet-build/output/kismet-os-dev-preview.iso}"
RUNTIME_DIR="${QEMU_RUNTIME_DIR:-/tmp/kismet-qemu-smoke}"
ARTIFACT_DIR="${QEMU_ARTIFACT_DIR:-$ROOT_DIR/kismet-build/output/qemu-smoke}"
MONITOR_SOCKET="$RUNTIME_DIR/monitor.sock"
SERIAL_LOG="$RUNTIME_DIR/serial.log"
SCREENSHOT_PATH="$RUNTIME_DIR/boot-screenshot.ppm"
SCREENSHOT_PNG="$RUNTIME_DIR/boot-screenshot.png"
MONITOR_LOG="$RUNTIME_DIR/monitor.log"
ARTIFACT_SERIAL_LOG="$ARTIFACT_DIR/serial.log"
ARTIFACT_MONITOR_LOG="$ARTIFACT_DIR/monitor.log"
ARTIFACT_SCREENSHOT_PPM="$ARTIFACT_DIR/boot-screenshot.ppm"
ARTIFACT_SCREENSHOT_PNG="$ARTIFACT_DIR/boot-screenshot.png"
MEMORY_MB="${QEMU_MEMORY_MB:-${KISMET_MEMORY_MB:-4096}}"
SMP_CPUS="${QEMU_SMP_CPUS:-${KISMET_SMP:-4}}"
BOOT_WAIT_SECONDS="${QEMU_BOOT_WAIT_SECONDS:-45}"
SCREENSHOT_WAIT_SECONDS="${QEMU_SCREENSHOT_WAIT_SECONDS:-10}"
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
QEMU_SENDKEYS="${QEMU_SENDKEYS:-ret,ret}"
QEMU_FIRMWARE="${QEMU_FIRMWARE:-bios}"
QEMU_OVMF_CODE="${QEMU_OVMF_CODE:-}"
QEMU_OVMF_VARS_TEMPLATE="${QEMU_OVMF_VARS_TEMPLATE:-}"
OVMF_VARS_PATH="$RUNTIME_DIR/OVMF_VARS.fd"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

[ -f "$ISO_PATH" ] || fail "ISO not found at $ISO_PATH"
command -v "$QEMU_BIN" >/dev/null 2>&1 || fail "qemu-system-x86_64 not found"
command -v python3 >/dev/null 2>&1 || fail "python3 is required for QEMU monitor access"

resolve_ovmf_code() {
  if [ -n "$QEMU_OVMF_CODE" ] && [ -f "$QEMU_OVMF_CODE" ]; then
    printf '%s\n' "$QEMU_OVMF_CODE"
    return 0
  fi
  for candidate in \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_ovmf_vars_template() {
  if [ -n "$QEMU_OVMF_VARS_TEMPLATE" ] && [ -f "$QEMU_OVMF_VARS_TEMPLATE" ]; then
    printf '%s\n' "$QEMU_OVMF_VARS_TEMPLATE"
    return 0
  fi
  for candidate in \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/edk2/ovmf/OVMF_VARS.fd \
    /usr/share/edk2/x64/OVMF_VARS.fd; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

mkdir -p "$RUNTIME_DIR" "$ARTIFACT_DIR"
rm -f "$MONITOR_SOCKET" "$SERIAL_LOG" "$SCREENSHOT_PATH" "$SCREENSHOT_PNG" "$MONITOR_LOG" \
      "$ARTIFACT_SERIAL_LOG" "$ARTIFACT_MONITOR_LOG" "$ARTIFACT_SCREENSHOT_PPM" "$ARTIFACT_SCREENSHOT_PNG" \
      "$OVMF_VARS_PATH"
echo "Runtime dir: $RUNTIME_DIR"
echo "Artifact dir: $ARTIFACT_DIR"
echo "Firmware mode: $QEMU_FIRMWARE"

ACCEL_ARGS=("-machine" "q35")
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL_ARGS=("-machine" "q35,accel=kvm")
fi

FIRMWARE_ARGS=()
case "$QEMU_FIRMWARE" in
  bios|legacy)
    ;;
  uefi|efi)
    OVMF_CODE_PATH="$(resolve_ovmf_code)" || fail "UEFI boot requested but no OVMF_CODE firmware was found"
    OVMF_VARS_TEMPLATE_PATH="$(resolve_ovmf_vars_template)" || fail "UEFI boot requested but no OVMF_VARS template was found"
    cp "$OVMF_VARS_TEMPLATE_PATH" "$OVMF_VARS_PATH"
    FIRMWARE_ARGS=(
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE_PATH"
      -drive "if=pflash,format=raw,file=$OVMF_VARS_PATH"
    )
    ;;
  *)
    fail "Unsupported QEMU_FIRMWARE value: $QEMU_FIRMWARE (expected bios or uefi)"
    ;;
esac

cleanup() {
  if [ -f "$RUNTIME_DIR/qemu.pid" ]; then
    kill "$(cat "$RUNTIME_DIR/qemu.pid")" 2>/dev/null || true
    rm -f "$RUNTIME_DIR/qemu.pid"
  fi
}
trap cleanup EXIT

"$QEMU_BIN" \
  "${ACCEL_ARGS[@]}" \
  "${FIRMWARE_ARGS[@]}" \
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

MONITOR_SOCKET="$MONITOR_SOCKET" SCREENSHOT_PATH="$SCREENSHOT_PATH" MONITOR_LOG="$MONITOR_LOG" SCREENSHOT_WAIT_SECONDS="$SCREENSHOT_WAIT_SECONDS" QEMU_SENDKEYS="$QEMU_SENDKEYS" python3 - <<'PY' || true
import os
import socket
import time
from pathlib import Path

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.settimeout(5)
sock.connect(os.environ['MONITOR_SOCKET'])
sendkeys = [key.strip() for key in os.environ.get('QEMU_SENDKEYS', 'ret').split(',') if key.strip()]
commands = ['info version']
commands.extend(f'sendkey {key}' for key in sendkeys)
commands.extend([
    f"screendump {os.environ['SCREENSHOT_PATH']}",
    'quit',
])
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

cp -f "$SERIAL_LOG" "$ARTIFACT_SERIAL_LOG" 2>/dev/null || true
cp -f "$MONITOR_LOG" "$ARTIFACT_MONITOR_LOG" 2>/dev/null || true

if [ -f "$SCREENSHOT_PATH" ] && head -c 2 "$SCREENSHOT_PATH" 2>/dev/null | grep -q '^P6'; then
  cp -f "$SCREENSHOT_PATH" "$ARTIFACT_SCREENSHOT_PPM"
  python3 - "$SCREENSHOT_PATH" "$ARTIFACT_SCREENSHOT_PNG" <<'PY'
import struct
import sys
import zlib
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
with src.open('rb') as f:
    if f.readline().strip() != b'P6':
        raise SystemExit('Unsupported PPM header')

    def next_token(handle):
        while True:
            line = handle.readline()
            if not line:
                raise SystemExit('Unexpected EOF while parsing PPM')
            line = line.strip()
            if not line or line.startswith(b'#'):
                continue
            return line

    dims = next_token(f)
    width, height = map(int, dims.split())
    maxval = int(next_token(f))
    if maxval != 255:
        raise SystemExit(f'Unsupported PPM maxval: {maxval}')
    pixels = f.read(width * height * 3)
    if len(pixels) != width * height * 3:
        raise SystemExit('PPM pixel data truncated')

raw = b''.join(b'\x00' + pixels[row * width * 3:(row + 1) * width * 3] for row in range(height))
compressed = zlib.compress(raw, 9)

def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)

png = [b'\x89PNG\r\n\x1a\n']
png.append(chunk(b'IHDR', struct.pack('!IIBBBBB', width, height, 8, 2, 0, 0, 0)))
png.append(chunk(b'IDAT', compressed))
png.append(chunk(b'IEND', b''))
dst.write_bytes(b''.join(png))
PY
  echo "Screenshot: $ARTIFACT_SCREENSHOT_PNG"
  strings "$ARTIFACT_SCREENSHOT_PPM" 2>/dev/null | grep -E -i 'oh no|administrator|kismet|gnome|plasma|try or install' | head -n 20 || true
else
  echo "Screenshot: unavailable"
fi

echo "Monitor log: $ARTIFACT_MONITOR_LOG"
echo "Serial log: $ARTIFACT_SERIAL_LOG"
if [ -s "$SERIAL_LOG" ]; then
  tail -n 40 "$SERIAL_LOG"
else
  echo "(serial log is empty, expected for a graphical boot path)"
fi

if [ -s "$SERIAL_LOG" ]; then
  if grep -Fq "grub_platform" "$SERIAL_LOG"; then
    fail "GRUB hit a grub_platform error during boot smoke"
  fi
  if grep -Eq 'Try or Install Ubuntu|Welcome to Ubuntu|Ubuntu \(safe graphics\)' "$SERIAL_LOG"; then
    fail "Boot menu still exposes Ubuntu branding in serial output"
  fi
fi

echo "QEMU boot smoke run completed."
