#!/usr/bin/env bash
set -euo pipefail

echo "==> Kismet OS Ubuntu-first bootstrap"

sudo apt update
sudo apt install -y \
  plasma-desktop sddm konsole dolphin kate plasma-discover plasma-workspace-wayland \
  plymouth plymouth-themes \
  curl wget git vim neovim htop unzip zip tmux zsh openssh-client openssh-server flatpak \
  ca-certificates software-properties-common apt-transport-https \
  build-essential cmake gdb python3 python3-pip python3-venv python3-fastapi python3-uvicorn python3-watchdog python3-requests python3-pydantic nodejs npm \
  ripgrep fd-find jq gh kitty

if ! command -v fastfetch >/dev/null 2>&1; then
  echo "==> fastfetch not in default repos on this system, skipping"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker"
  curl -fsSL https://get.docker.com | sh
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "==> Installing Ollama"
  curl -fsSL https://ollama.com/install.sh | sh
fi

sudo systemctl enable sddm || true
sudo systemctl enable docker || true
sudo usermod -aG docker "$USER" || true

chsh -s "$(command -v zsh)" "$USER" || true

sudo install -Dm755 "$PWD/kismet-base/config/usr/local/bin/kismet-firstboot" /usr/local/bin/kismet-firstboot || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/bin/kismet-firstboot-wizard" /usr/local/bin/kismet-firstboot-wizard || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/bin/kismet-ctl" /usr/local/bin/kismet-ctl || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/bin/kismet-ollama-loader" /usr/local/bin/kismet-ollama-loader || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/lib/kismet/kismet_agent_runner.py" /usr/local/lib/kismet/kismet_agent_runner.py || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/lib/kismet/kismet-firstboot-wizard" /usr/local/lib/kismet/kismet-firstboot-wizard || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/lib/kismet/kismet-ctl" /usr/local/lib/kismet/kismet-ctl || true
sudo install -Dm755 "$PWD/kismet-base/config/usr/local/lib/kismet/model-loader.sh" /usr/local/lib/kismet/model-loader.sh || true
sudo install -Dm644 "$PWD/kismet-base/config/etc/systemd/system/kismet-agent.service" /etc/systemd/system/kismet-agent.service || true
sudo install -Dm644 "$PWD/kismet-base/config/etc/systemd/system/kismet-ollama-loader.service" /etc/systemd/system/kismet-ollama-loader.service || true
sudo install -Dm644 "$PWD/kismet-base/config/etc/systemd/system/kismet-firstboot.service" /etc/systemd/system/kismet-firstboot.service || true
sudo install -Dm644 "$PWD/kismet-base/config/etc/kismet/models.env" /etc/kismet/models.env || true
sudo systemctl daemon-reload || true
sudo systemctl enable kismet-agent kismet-ollama-loader kismet-firstboot sddm docker || true

echo "==> Base bootstrap complete"
echo "Log out and back in for group/shell changes to fully apply."
