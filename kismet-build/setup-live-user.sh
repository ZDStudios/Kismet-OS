#!/usr/bin/env bash
# Creates the live user in the editable live rootfs and configures a default account.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="${EDIT_DIR:-$ROOT_DIR/kismet-build/work/live-rootfs-edit}"
LIVE_USER="${LIVE_USER:-live}"
LIVE_UID="${LIVE_UID:-999}"
LIVE_GID="${LIVE_GID:-999}"
LIVE_GECOS="${LIVE_GECOS:-Kismet Live User}"
LIVE_SHELL="${LIVE_SHELL:-/bin/bash}"
LIVE_HOME="${LIVE_HOME:-/home/$LIVE_USER}"
LIVE_PASSWORD="${LIVE_PASSWORD:-kismet}"

[ -d "$EDIT_DIR" ] || {
  echo "Editable live rootfs not found at $EDIT_DIR. Run prepare-live-rootfs.sh first." >&2
  exit 1
}

mkdir -p "$EDIT_DIR/proc" "$EDIT_DIR/sys" "$EDIT_DIR/dev" "$EDIT_DIR/run"

cleanup() {
  umount "$EDIT_DIR/proc" 2>/dev/null || true
  umount "$EDIT_DIR/sys" 2>/dev/null || true
  umount "$EDIT_DIR/dev" 2>/dev/null || true
  umount "$EDIT_DIR/run" 2>/dev/null || true
}
trap cleanup EXIT

mountpoint -q "$EDIT_DIR/proc" || mount --bind /proc "$EDIT_DIR/proc"
mountpoint -q "$EDIT_DIR/sys" || mount --bind /sys "$EDIT_DIR/sys"
mountpoint -q "$EDIT_DIR/dev" || mount --bind /dev "$EDIT_DIR/dev"
mountpoint -q "$EDIT_DIR/run" || mount --bind /run "$EDIT_DIR/run"

chroot "$EDIT_DIR" /usr/bin/env \
  LIVE_USER="$LIVE_USER" \
  LIVE_UID="$LIVE_UID" \
  LIVE_GID="$LIVE_GID" \
  LIVE_GECOS="$LIVE_GECOS" \
  LIVE_SHELL="$LIVE_SHELL" \
  LIVE_HOME="$LIVE_HOME" \
  LIVE_PASSWORD="$LIVE_PASSWORD" \
  bash <<'EOF'
set -euo pipefail

create_group_if_missing() {
  grp="$1"
  if ! getent group "$grp" >/dev/null 2>&1; then
    groupadd --system "$grp" 2>/dev/null || true
  fi
}

resolve_group_name() {
  if getent group "$LIVE_USER" >/dev/null 2>&1; then
    getent group "$LIVE_USER" | cut -d: -f1
    return
  fi

  existing_gid_group="$(getent group "$LIVE_GID" | cut -d: -f1 || true)"
  if [ -n "$existing_gid_group" ]; then
    echo "$existing_gid_group"
    return
  fi

  groupadd --gid "$LIVE_GID" "$LIVE_USER"
  echo "$LIVE_USER"
}

resolve_uid() {
  existing_uid_user="$(getent passwd "$LIVE_UID" | cut -d: -f1 || true)"
  if [ -n "$existing_uid_user" ] && [ "$existing_uid_user" != "$LIVE_USER" ]; then
    echo "1000"
  else
    echo "$LIVE_UID"
  fi
}

for grp in sudo adm cdrom dip plugdev lpadmin; do
  create_group_if_missing "$grp"
done

groups="$(getent group sudo adm cdrom dip plugdev lpadmin 2>/dev/null | cut -d: -f1 | paste -sd, -)"
live_group="$(resolve_group_name)"
live_uid="$(resolve_uid)"

if ! id "$LIVE_USER" >/dev/null 2>&1; then
  echo "==> Creating live user: $LIVE_USER"
  if [ -n "$groups" ]; then
    useradd --uid "$live_uid" --gid "$live_group" --groups "$groups" \
      --create-home --home-dir "$LIVE_HOME" \
      --shell "$LIVE_SHELL" --comment "$LIVE_GECOS" "$LIVE_USER"
  else
    useradd --uid "$live_uid" --gid "$live_group" \
      --create-home --home-dir "$LIVE_HOME" \
      --shell "$LIVE_SHELL" --comment "$LIVE_GECOS" "$LIVE_USER"
  fi
fi

echo "$LIVE_USER:$LIVE_PASSWORD" | chpasswd
passwd -u "$LIVE_USER" >/dev/null 2>&1 || true

actual_uid="$(id -u "$LIVE_USER")"
actual_gid="$(id -g "$LIVE_USER")"

if [ -d /etc/skel ] && [ -d "$LIVE_HOME" ]; then
  find /etc/skel -mindepth 1 -maxdepth 1 -exec cp -a {} "$LIVE_HOME/" \; 2>/dev/null || true
  chown -R "$actual_uid:$actual_gid" "$LIVE_HOME" 2>/dev/null || true
fi

echo "==> Live user '$LIVE_USER' ready with configured password (uid=$actual_uid gid=$actual_gid)"
EOF

echo "==> Live user '$LIVE_USER' injected into $EDIT_DIR"
