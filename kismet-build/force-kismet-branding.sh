#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EDIT_DIR="$ROOT_DIR/kismet-build/work/live-rootfs-edit"
WALLPAPER_DST_DIR="$EDIT_DIR/usr/share/backgrounds/kismet"
PLYMOUTH_DIR="$EDIT_DIR/usr/share/plymouth/themes/kismet"
GDM_DIR="$EDIT_DIR/etc/gdm3"
ICON_SRC="$ROOT_DIR/kismet-theme/icons/kismet-logo.svg"
ICON_DST_DIR="$EDIT_DIR/usr/share/icons/hicolor/scalable/apps"
PIXMAP_DST_DIR="$EDIT_DIR/usr/share/pixmaps"

if [ ! -d "$EDIT_DIR" ]; then
  echo "Editable live rootfs not found. Run prepare-live-rootfs.sh first." >&2
  exit 1
fi

mkdir -p \
  "$EDIT_DIR/etc/plymouth" \
  "$WALLPAPER_DST_DIR" \
  "$PLYMOUTH_DIR" \
  "$GDM_DIR" \
  "$ICON_DST_DIR" \
  "$PIXMAP_DST_DIR"

cp -f "$ROOT_DIR/kismet-theme/plymouth/kismet.plymouth" "$PLYMOUTH_DIR/"
cp -f "$ROOT_DIR/kismet-theme/plymouth/kismet.script" "$PLYMOUTH_DIR/"
for wallpaper in "$ROOT_DIR"/kismet-theme/wallpapers/*; do
  [ -f "$wallpaper" ] || continue
  cp -f "$wallpaper" "$WALLPAPER_DST_DIR/"
done
cp -f "$ICON_SRC" "$ICON_DST_DIR/kismet-logo.svg"
cp -f "$ICON_SRC" "$PIXMAP_DST_DIR/kismet-logo.svg"
cp -f "$ICON_SRC" "$PIXMAP_DST_DIR/distributor-logo.svg"

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
LOGO=kismet-logo
EOF

cat > "$EDIT_DIR/etc/lsb-release" <<'EOF'
DISTRIB_ID=KismetOS
DISTRIB_RELEASE=2
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Kismet OS 2 Preview"
EOF

printf 'Kismet OS 2 Preview \\n \\l\n' > "$EDIT_DIR/etc/issue"
printf 'Kismet OS 2 Preview\n' > "$EDIT_DIR/etc/issue.net"

mkdir -p "$EDIT_DIR/usr/share/gnome-background-properties"
cat > "$EDIT_DIR/usr/share/gnome-background-properties/kismet-wallpapers.xml" <<'EOF'
<?xml version="1.0"?>
<wallpapers>
  <wallpaper deleted="false">
    <name>Kismet OS</name>
    <filename>/usr/share/backgrounds/kismet/kismet-wallpaper.svg</filename>
    <options>zoom</options>
    <pcolor>#101828</pcolor>
    <scolor>#1cb4ff</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>Kismet AI Circuit</name>
    <filename>/usr/share/backgrounds/kismet/kismet-ai-circuit.svg</filename>
    <options>zoom</options>
    <pcolor>#09111d</pcolor>
    <scolor>#7df9ff</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>Kismet Neural Terminal</name>
    <filename>/usr/share/backgrounds/kismet/kismet-neural-terminal.svg</filename>
    <options>zoom</options>
    <pcolor>#05070d</pcolor>
    <scolor>#8a6cff</scolor>
  </wallpaper>
</wallpapers>
EOF

if [ -f "$EDIT_DIR/usr/share/gnome-background-properties/noble-wallpapers.xml" ]; then
  sed -i 's/Ubuntu 24\.04 Community Wallpapers/Kismet OS Wallpapers/g' "$EDIT_DIR/usr/share/gnome-background-properties/noble-wallpapers.xml"
fi

if [ -f "$EDIT_DIR/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth" ]; then
  sed -i 's/title=Ubuntu 24\.04/title=Kismet OS 2 Preview/g' "$EDIT_DIR/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth"
fi

if [ -f "$EDIT_DIR/usr/share/initramfs-tools/hook-functions" ]; then
  sed -i 's/Ubuntu 24\.04/Kismet OS 2 Preview/g' "$EDIT_DIR/usr/share/initramfs-tools/hook-functions"
fi

find "$EDIT_DIR/usr/share/applications" "$EDIT_DIR/var/lib/snapd/desktop/applications" -maxdepth 1 -type f 2>/dev/null | while read -r desktop_file; do
  sed -i 's/Install Ubuntu[^\r\n]*/Install Kismet OS 2 Preview/g' "$desktop_file" 2>/dev/null || true
  sed -i 's/Welcome to Ubuntu/Welcome to Kismet OS/g' "$desktop_file" 2>/dev/null || true
  sed -i 's/Preparing Ubuntu/Preparing Kismet OS/g' "$desktop_file" 2>/dev/null || true
  sed -i 's/Ubuntu 24\.04\.3 LTS/Kismet OS 2 Preview/g' "$desktop_file" 2>/dev/null || true
  sed -i 's/Icon=ubuntu-logo/Icon=kismet-logo/g' "$desktop_file" 2>/dev/null || true
  sed -i 's/Icon=distributor-logo/Icon=kismet-logo/g' "$desktop_file" 2>/dev/null || true
  sed -i 's/Ubuntu/Kismet OS/g' "$desktop_file" 2>/dev/null || true
 done

if command -v unsquashfs >/dev/null 2>&1 && command -v mksquashfs >/dev/null 2>&1; then
  SNAP_WORK="$ROOT_DIR/kismet-build/work/snap-branding"
  rm -rf "$SNAP_WORK"
  mkdir -p "$SNAP_WORK"

  for snap_path in \
    "$EDIT_DIR/var/lib/snapd/snaps/gnome-42-2204_202.snap" \
    "$EDIT_DIR/var/lib/snapd/seed/snaps/gnome-42-2204_202.snap"
  do
    [ -f "$snap_path" ] || continue
    snap_name="$(basename "$snap_path")"
    snap_dir="$SNAP_WORK/${snap_name%.snap}"
    rm -rf "$snap_dir"
    unsquashfs -d "$snap_dir" "$snap_path" >/dev/null 2>&1 || continue
    find "$snap_dir" -type f -name 'gnome-initial-setup.desktop' | while read -r desktop_file; do
      sed -i 's/Welcome to Ubuntu/Welcome to Kismet OS/g' "$desktop_file" 2>/dev/null || true
      sed -i 's/Install Ubuntu[^\r\n]*/Install Kismet OS 2 Preview/g' "$desktop_file" 2>/dev/null || true
      sed -i 's/Preparing Ubuntu/Preparing Kismet OS/g' "$desktop_file" 2>/dev/null || true
      sed -i 's/Ubuntu 24\.04\.3 LTS/Kismet OS 2 Preview/g' "$desktop_file" 2>/dev/null || true
      sed -i 's/Icon=ubuntu-logo/Icon=kismet-logo/g' "$desktop_file" 2>/dev/null || true
      sed -i 's/Ubuntu/Kismet OS/g' "$desktop_file" 2>/dev/null || true
    done
    rm -f "$snap_path"
    mksquashfs "$snap_dir" "$snap_path" -comp xz -noappend >/dev/null 2>&1 || true
  done
fi

if [ -f "$EDIT_DIR/var/cache/swcatalog/cache/C-os-catalog.xb" ]; then
  CATALOG_PATH="$EDIT_DIR/var/cache/swcatalog/cache/C-os-catalog.xb" python3 - <<'PY'
import os
from pathlib import Path
path = Path(os.environ['CATALOG_PATH'])
data = path.read_bytes()
data = data.replace(b'Install Ubuntu', b'Install Kismet')
data = data.replace(b'ubuntu-logo', b'kismet-logo')
path.write_bytes(data)
PY
fi

cat > "$EDIT_DIR/etc/plymouth/plymouthd.conf" <<'EOF'
[Daemon]
Theme=kismet
ShowDelay=0
EOF

mkdir -p "$EDIT_DIR/usr/share/xsessions" "$EDIT_DIR/usr/share/wayland-sessions"

# GNOME sessions (Zorin OS style)
cat > "$EDIT_DIR/usr/share/xsessions/gnome.desktop" <<'EOF'
[Desktop Entry]
Type=XSession
Exec=/usr/bin/gnome-session
DesktopNames=GNOME
Name=Kismet GNOME
Comment=Kismet OS GNOME Session
EOF

cat > "$EDIT_DIR/usr/share/xsessions/gnome-xorg.desktop" <<'EOF'
[Desktop Entry]
Type=XSession
Exec=/usr/bin/gnome-session --session=gnome-xorg
DesktopNames=GNOME
Name=Kismet GNOME (Xorg)
Comment=Kismet OS GNOME Session (X11)
EOF

cat > "$EDIT_DIR/usr/share/wayland-sessions/gnome.desktop" <<'EOF'
[Desktop Entry]
Type=WaylandSession
Exec=/usr/bin/gnome-session
DesktopNames=GNOME
Name=Kismet GNOME (Wayland)
Comment=Kismet OS GNOME Session (Wayland)
EOF

# Keep Plasma sessions too for users who want both
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

cat > "$GDM_DIR/custom.conf" <<'EOF'
[daemon]
WaylandEnable=true
DefaultSession=gnome.desktop

[security]
DisallowTCP=true

[xdmcp]

[chooser]

[debug]
EOF

mkdir -p "$EDIT_DIR/etc/X11" "$EDIT_DIR/etc/systemd/system/graphical.target.wants"
rm -f "$EDIT_DIR/etc/X11/default-display-manager"
printf '/usr/sbin/gdm3\n' > "$EDIT_DIR/etc/X11/default-display-manager"
rm -f "$EDIT_DIR/etc/systemd/system/display-manager.service"
if [ -f "$EDIT_DIR/lib/systemd/system/gdm.service" ]; then
  ln -s /lib/systemd/system/gdm.service "$EDIT_DIR/etc/systemd/system/display-manager.service"
elif [ -f "$EDIT_DIR/usr/lib/systemd/system/gdm.service" ]; then
  ln -s /usr/lib/systemd/system/gdm.service "$EDIT_DIR/etc/systemd/system/display-manager.service"
fi
rm -f "$EDIT_DIR/etc/systemd/system/graphical.target.wants/display-manager.service"
if [ -f "$EDIT_DIR/lib/systemd/system/gdm.service" ]; then
  ln -s /lib/systemd/system/gdm.service "$EDIT_DIR/etc/systemd/system/graphical.target.wants/display-manager.service"
elif [ -f "$EDIT_DIR/usr/lib/systemd/system/gdm.service" ]; then
  ln -s /usr/lib/systemd/system/gdm.service "$EDIT_DIR/etc/systemd/system/graphical.target.wants/display-manager.service"
fi
rm -rf "$EDIT_DIR/etc/systemd/system/display-manager.service.wants" || true
mkdir -p "$EDIT_DIR/etc/systemd/system/display-manager.service.wants"

for service in sddm.service gnome-initial-setup.service; do
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

echo "==> Forced Kismet branding, Kismet icon replacements, Plasma sessions, and GDM defaults into editable rootfs"
