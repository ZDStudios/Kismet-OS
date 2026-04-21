#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"
KISMET_PACKAGES="plasma-desktop plasma-workspace-wayland plasma-widgets-addons sddm sddm-theme-breeze konsole dolphin kate plasma-discover kde-config-sddm kde-config-gtk-style kde-style-breeze papirus-icon-theme python3-flask python3-psutil python3-requests python3-pip python3-venv python3-watchdog python3-pydantic python3-inotify curl wget git tmux zsh jq wine64 winetricks lutris"
KISMET_PURGE_PACKAGES="gdm3 gnome-shell ubuntu-session ubuntu-desktop ubuntu-desktop-minimal gnome-initial-setup"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first." >&2
  exit 1
fi

mount_if_needed() {
  local source="$1"
  local target="$2"
  mkdir -p "$target"
  if ! mountpoint -q "$target"; then
    mount --bind "$source" "$target"
  fi
}

seed_resolv_conf() {
  local target="$EDIT_DIR/etc/resolv.conf"
  local backup="$EDIT_DIR/etc/resolv.conf.kismet-backup"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f "$backup"
    cp -a "$target" "$backup"
    rm -f "$target"
  fi
  cp /etc/resolv.conf "$target"
}

cleanup() {
  rm -f "$EDIT_DIR/usr/sbin/policy-rc.d"
  rm -f "$EDIT_DIR/etc/machine-id"
  touch "$EDIT_DIR/etc/machine-id"
  rm -f "$EDIT_DIR/var/lib/dbus/machine-id"
  ln -sf /etc/machine-id "$EDIT_DIR/var/lib/dbus/machine-id"

  if [ -e "$EDIT_DIR/etc/resolv.conf.kismet-backup" ] || [ -L "$EDIT_DIR/etc/resolv.conf.kismet-backup" ]; then
    rm -f "$EDIT_DIR/etc/resolv.conf"
    mv "$EDIT_DIR/etc/resolv.conf.kismet-backup" "$EDIT_DIR/etc/resolv.conf"
  fi

  for target in \
    "$EDIT_DIR/run" \
    "$EDIT_DIR/sys" \
    "$EDIT_DIR/proc" \
    "$EDIT_DIR/dev/pts" \
    "$EDIT_DIR/dev"
  do
    if mountpoint -q "$target"; then
      umount "$target"
    fi
  done
}
trap cleanup EXIT

mount_if_needed /dev "$EDIT_DIR/dev"
mount_if_needed /dev/pts "$EDIT_DIR/dev/pts"
mount_if_needed /proc "$EDIT_DIR/proc"
mount_if_needed /sys "$EDIT_DIR/sys"
mount_if_needed /run "$EDIT_DIR/run"
seed_resolv_conf

cat > "$EDIT_DIR/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
chmod +x "$EDIT_DIR/usr/sbin/policy-rc.d"

chroot "$EDIT_DIR" env \
  KISMET_PACKAGES="$KISMET_PACKAGES" \
  KISMET_PURGE_PACKAGES="$KISMET_PURGE_PACKAGES" \
  bash -lc '
set -e
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
mkdir -p /etc/dpkg/dpkg.cfg.d
printf "force-confdef\nforce-confold\n" > /etc/dpkg/dpkg.cfg.d/99kismet-ci
apt-get update
apt-get install -y --no-install-recommends $KISMET_PACKAGES
apt-get purge -y $KISMET_PURGE_PACKAGES || true
apt-get autoremove -y --purge || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
'

echo "$KISMET_PACKAGES" | tr ' ' '\n' | sed '/^$/d' > "$ROOT_DIR/kismet-build/output/installed-package-set.txt"

echo "==> Installed Kismet package set into editable rootfs"
