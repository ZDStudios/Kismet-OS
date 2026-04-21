#!/usr/bin/env bash
# Creates the live user and configures GDM for auto-login
# Run this INSIDE the chroot of the live rootfs

set -euo pipefail

LIVE_USER="${LIVE_USER:-admin}"
LIVE_UID="${LIVE_UID:-1000}"
LIVE_GID="${LIVE_GID:-1000}"
LIVE_GECOS="${LIVE_GECOS:-Administrator}"
LIVE_SHELL="${LIVE_SHELL:-/bin/bash}"
LIVE_HOME="${LIVE_HOME:-/home/$LIVE_USER}"
LIVE_PASSWORD="${LIVE_PASSWORD:-admin}"

# Create groups if needed (some may not exist in base image)
create_group_if_missing() {
  local grp="$1"
  if ! getent group "$grp" >/dev/null 2>&1; then
    groupadd --system "$grp" 2>/dev/null || true
  fi
}

# Create live user if it doesn't exist
if ! id "$LIVE_USER" >/dev/null 2>&1; then
  echo "==> Creating live user: $LIVE_USER"
  
  # Ensure core groups exist
  for grp in sudo adm cdrom dip plugdev lpadmin; do
    create_group_if_missing "$grp"
  done
  
  # Create user with just the groups that exist
  local groups=$(getent group sudo adm cdrom dip plugdev lpadmin 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  
  useradd --uid "$LIVE_UID" --gid "$LIVE_GID" --groups "$groups" \
    --create-home --home-dir "$LIVE_HOME" \
    --shell "$LIVE_SHELL" --comment "$LIVE_GECOS" "$LIVE_USER" || {
    # Fallback: create without specific groups
    useradd --uid "$LIVE_UID" --gid "$LIVE_GID" \
      --create-home --home-dir "$LIVE_HOME" \
      --shell "$LIVE_SHELL" --comment "$LIVE_GECOS" "$LIVE_USER"
  }
  
  # Set password for the admin user
  echo "$LIVE_USER:$LIVE_PASSWORD" | chpasswd 2>/dev/null || true
fi

# Ensure home directory has skel content
if [ -d /etc/skel ] && [ -d "$LIVE_HOME" ]; then
  cp -rf /etc/skel/.[!.]* "$LIVE_HOME/" 2>/dev/null || true
  chown -R "$LIVE_UID:$LIVE_GID" "$LIVE_HOME" 2>/dev/null || true
fi

echo "==> Live user '$LIVE_USER' created"