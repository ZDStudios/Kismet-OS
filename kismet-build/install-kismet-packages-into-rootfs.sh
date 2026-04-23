#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"
KISMET_PURGE_PACKAGES="sddm plasma-desktop plasma-workspace plasma-discover kwin-x11 kwin-common kwin-wayland kactivitymanagerd kdepim-addons akonadi-backend-mysql akonadi-backend-sqlite akonadi-backend-postgresql akonadi-server akregator dragonplayer ffmpegthumbs filelight juk k3b kaffeine kdevelop khelpcenter kio-extras kleopatra kmag kmousetool knotes kopete kpat kwrited sddm-theme-breeze systemsettings kubuntu-notification-helper kubuntu-desktop kubuntu-settings-desktop"

# shellcheck source=./package-manifest-utils.sh
source "$ROOT_DIR/kismet-build/package-manifest-utils.sh"

mapfile -t KISMET_PACKAGE_ARRAY < <(manifest_packages core desktop dev)
KISMET_PACKAGES="ubuntu-desktop-minimal ${KISMET_PACKAGE_ARRAY[*]}"

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

chroot "$EDIT_DIR" /usr/bin/env \
  KISMET_PACKAGES="$KISMET_PACKAGES" \
  KISMET_PURGE_PACKAGES="$KISMET_PURGE_PACKAGES" \
  bash <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
mkdir -p /etc/dpkg/dpkg.cfg.d
printf "force-confdef\nforce-confold\n" > /etc/dpkg/dpkg.cfg.d/99kismet-ci
apt-get update
apt-get install -y --no-install-recommends $KISMET_PACKAGES
INSTALLED_PURGE_PACKAGES=""
for pkg in $KISMET_PURGE_PACKAGES; do
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    INSTALLED_PURGE_PACKAGES="$INSTALLED_PURGE_PACKAGES $pkg"
  fi
done
if [ -n "$INSTALLED_PURGE_PACKAGES" ]; then
  apt-get purge -y $INSTALLED_PURGE_PACKAGES || true
fi
apt-get autoremove -y --purge || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

echo "$KISMET_PACKAGES" | tr ' ' '\n' | sed '/^$/d' > "$ROOT_DIR/kismet-build/output/installed-package-set.txt"

echo "==> Installed Kismet package set into editable rootfs"
