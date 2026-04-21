#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"
WALLPAPER_SRC_SVG="$ROOT_DIR/kismet-theme/wallpapers/kismet-wallpaper.svg"
WALLPAPER_DST_DIR="$EDIT_DIR/usr/share/backgrounds/kismet"
PLYMOUTH_DIR="$EDIT_DIR/usr/share/plymouth/themes/kismet"
SDDM_THEME_DIR="$EDIT_DIR/usr/share/sddm/themes/kismet"
SDDM_BREEZE_THEME_DIR="$EDIT_DIR/usr/share/sddm/themes/breeze"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first." >&2
  exit 1
fi

mkdir -p "$EDIT_DIR/etc/sddm.conf.d" "$EDIT_DIR/etc/plymouth" "$WALLPAPER_DST_DIR" "$PLYMOUTH_DIR"
cp -f "$ROOT_DIR/kismet-theme/plymouth/kismet.plymouth" "$PLYMOUTH_DIR/"
cp -f "$ROOT_DIR/kismet-theme/plymouth/kismet.script" "$PLYMOUTH_DIR/"
cp -f "$WALLPAPER_SRC_SVG" "$WALLPAPER_DST_DIR/kismet-wallpaper.svg"

if [ -d "$SDDM_BREEZE_THEME_DIR" ]; then
  rm -rf "$SDDM_THEME_DIR"
  cp -a "$SDDM_BREEZE_THEME_DIR" "$SDDM_THEME_DIR"
else
  mkdir -p "$SDDM_THEME_DIR"
fi

cat > "$SDDM_THEME_DIR/theme.conf.user" <<'EOF'
[General]
Background=/usr/share/backgrounds/kismet/kismet-wallpaper.svg
ScreenWidth=1920
ScreenHeight=1080
CursorTheme=breeze_cursors
Font=Inter,10,-1,5,50,0,0,0,0,0
EOF

cat > "$EDIT_DIR/etc/os-release" <<'EOF'
NAME="Kismet OS"
VERSION="2 Preview"
ID=kismet
ID_LIKE=ubuntu
PRETTY_NAME="Kismet OS 2 Preview"
VERSION_ID="2"
HOME_URL="https://kismetos.dev"
SUPPORT_URL="https://kismetos.dev/docs"
BUG_REPORT_URL="https://github.com/kismetos/kismet-os/issues"
PRIVACY_POLICY_URL="https://kismetos.dev/privacy"
UBUNTU_CODENAME=noble
LOGO=kismet
EOF

cat > "$EDIT_DIR/etc/lsb-release" <<'EOF'
DISTRIB_ID=KismetOS
DISTRIB_RELEASE=2
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Kismet OS 2 Preview"
EOF

cat > "$EDIT_DIR/etc/sddm.conf.d/10-kismet.conf" <<'EOF'
[Theme]
Current=kismet

[Users]
DefaultSession=plasma.desktop
EOF

cat > "$EDIT_DIR/etc/plymouth/plymouthd.conf" <<'EOF'
[Daemon]
Theme=kismet
ShowDelay=0
EOF

mkdir -p "$EDIT_DIR/usr/share/xsessions" "$EDIT_DIR/usr/share/wayland-sessions"
cat > "$EDIT_DIR/usr/share/xsessions/plasma.desktop" <<'EOF'
[Desktop Entry]
Type=XSession
Exec=/usr/bin/startplasma-x11
DesktopNames=KDE
Name=Kismet Plasma
Comment=Kismet OS Plasma Session
EOF
cat > "$EDIT_DIR/usr/share/wayland-sessions/plasma.desktop" <<'EOF'
[Desktop Entry]
Type=WaylandSession
Exec=/usr/bin/startplasma-wayland
DesktopNames=KDE
Name=Kismet Plasma (Wayland)
Comment=Kismet OS Plasma Session
EOF
rm -f \
  "$EDIT_DIR/usr/share/xsessions/ubuntu.desktop" \
  "$EDIT_DIR/usr/share/xsessions/ubuntu-xorg.desktop" \
  "$EDIT_DIR/usr/share/wayland-sessions/ubuntu.desktop" \
  "$EDIT_DIR/usr/share/wayland-sessions/ubuntu-wayland.desktop" \
  "$EDIT_DIR/usr/share/ubuntu-wayland/applications/gnome-initial-setup.desktop"

mkdir -p "$EDIT_DIR/etc/X11" "$EDIT_DIR/etc/systemd/system/graphical.target.wants"
rm -f "$EDIT_DIR/etc/X11/default-display-manager"
printf '/usr/bin/sddm\n' > "$EDIT_DIR/etc/X11/default-display-manager"
rm -f "$EDIT_DIR/etc/systemd/system/display-manager.service"
ln -s /lib/systemd/system/sddm.service "$EDIT_DIR/etc/systemd/system/display-manager.service"
rm -f "$EDIT_DIR/etc/systemd/system/graphical.target.wants/display-manager.service"
ln -s /lib/systemd/system/sddm.service "$EDIT_DIR/etc/systemd/system/graphical.target.wants/display-manager.service"
rm -rf "$EDIT_DIR/etc/systemd/system/display-manager.service.wants" || true
mkdir -p "$EDIT_DIR/etc/systemd/system/display-manager.service.wants"

for service in gdm3.service gnome-initial-setup.service; do
  rm -f "$EDIT_DIR/etc/systemd/system/graphical.target.wants/$service" || true
  rm -f "$EDIT_DIR/lib/systemd/system/$service" || true
  rm -f "$EDIT_DIR/usr/lib/systemd/system/$service" || true
done

mkdir -p "$EDIT_DIR/etc/skel/.config/plasma-workspace/env"
cat > "$EDIT_DIR/etc/skel/.config/plasma-workspace/env/kismet-branding.sh" <<'EOF'
export XDG_CURRENT_DESKTOP=KDE
export DESKTOP_SESSION=plasma
export XDG_SESSION_DESKTOP=KDE
EOF
chmod +x "$EDIT_DIR/etc/skel/.config/plasma-workspace/env/kismet-branding.sh"

echo "==> Forced Kismet branding, Plasma sessions, and SDDM defaults into editable rootfs"
