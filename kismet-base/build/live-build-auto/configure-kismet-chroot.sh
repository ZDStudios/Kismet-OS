#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE=/var/log/kismet-chroot-setup.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Kismet chroot setup started at $(date -Is)"

apt-get update
apt-get purge -y gdm3 gnome-shell ubuntu-session ubuntu-desktop-minimal ubuntu-desktop gnome-initial-setup || true
apt-get autoremove -y || true

apt-get install -y \
  plasma-desktop plasma-workspace-wayland sddm sddm-theme-breeze \
  konsole dolphin kate plasma-discover kde-config-sddm kde-config-gtk-style \
  kde-style-breeze plymouth plymouth-themes \
  curl wget git vim neovim htop unzip zip tmux zsh openssh-client openssh-server flatpak \
  ca-certificates software-properties-common apt-transport-https \
  build-essential cmake gdb python3 python3-flask python3-psutil python3-requests python3-pip python3-venv python3-inotify python3-watchdog python3-pydantic \
  nodejs npm ripgrep fd-find jq gh smartmontools lm-sensors

mkdir -p /etc/sddm.conf.d /etc/plymouth /usr/share/plymouth/themes/default.plymouth
printf '/usr/sbin/sddm\n' > /etc/X11/default-display-manager
cat > /etc/sddm.conf.d/10-kismet.conf <<'EOF'
[Theme]
Current=breeze

[Users]
DefaultSession=plasma.desktop
EOF

update-alternatives --set default.plymouth /usr/share/plymouth/themes/kismet/kismet.plymouth || true
cat > /etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=kismet
ShowDelay=0
EOF

cat > /etc/os-release <<'EOF'
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

cat > /etc/lsb-release <<'EOF'
DISTRIB_ID=KismetOS
DISTRIB_RELEASE=2
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Kismet OS 2 Preview"
EOF

rm -f /usr/share/ubuntu-wayland/applications/gnome-initial-setup.desktop || true
rm -f /usr/share/xsessions/ubuntu.desktop /usr/share/xsessions/ubuntu-xorg.desktop || true
rm -f /usr/share/wayland-sessions/ubuntu.desktop /usr/share/wayland-sessions/ubuntu-wayland.desktop || true
cat > /usr/share/xsessions/plasma.desktop <<'EOF'
[Desktop Entry]
Type=XSession
Exec=/usr/bin/startplasma-x11
DesktopNames=KDE
Name=Kismet Plasma
Comment=Kismet OS Plasma Session
EOF
cat > /usr/share/wayland-sessions/plasma.desktop <<'EOF'
[Desktop Entry]
Type=WaylandSession
Exec=/usr/bin/startplasma-wayland
DesktopNames=KDE
Name=Kismet Plasma (Wayland)
Comment=Kismet OS Plasma Session
EOF

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh || true
fi

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh || true
fi

systemctl disable gdm3 || true
systemctl enable sddm || true
systemctl enable ollama || true
systemctl enable kismet-agent || true
systemctl enable kismet-ollama-loader || true
systemctl enable kismet-ollama-bridge || true
systemctl enable kismet-firstboot || true

mkdir -p /etc/openclaw/config.d
cat > /etc/openclaw/ollama.env <<'EOF'
OLLAMA_HOST=http://127.0.0.1:11434
OPENCLAW_OLLAMA_ENABLED=true
EOF
cat > /etc/openclaw/config.d/20-kismet-local-ollama.json <<'EOF'
{
  "kismet": {
    "generated": true,
    "ollama": {
      "baseUrl": "http://127.0.0.1:11434",
      "preferredModel": "qwen2.5-coder:7b",
      "embeddingModel": "nomic-embed-text",
      "fallbackModels": [
        "llama3.1:8b",
        "phi3:mini"
      ]
    },
    "notes": [
      "Template generated during ISO build.",
      "Review and merge with the deployed OpenClaw config as needed."
    ]
  }
}
EOF

if npm view @anthropic-ai/claude-code version >/dev/null 2>&1; then
  npm install -g @anthropic-ai/claude-code || true
else
  echo "Claude Code package lookup failed during chroot build, leaving install to first boot" >&2
fi

mkdir -p /etc/skel/.kismet
printf '%s\n' "$LOG_FILE" > /etc/skel/.kismet/chroot-log-path

echo "==> Kismet chroot setup completed at $(date -Is)"
apt-get clean
rm -rf /var/lib/apt/lists/*
