#!/usr/bin/env bash
set -euo pipefail

echo "==> Kismet OS Ubuntu-first bootstrap"

sudo apt update
sudo apt install -y \
  plasma-desktop sddm konsole dolphin kate plasma-discover plasma-workspace-wayland \
  plymouth plymouth-themes \
  curl wget git vim neovim htop unzip zip tmux zsh openssh-client openssh-server flatpak \
  ca-certificates software-properties-common apt-transport-https \
  build-essential cmake gdb python3 python3-pip python3-venv nodejs npm \
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

echo "==> Base bootstrap complete"
echo "Log out and back in for group/shell changes to fully apply."
