#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE=/var/log/kismet-chroot-setup.log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Kismet chroot setup started at $(date -Is)"

apt-get update
apt-get install -y \
  plasma-desktop sddm konsole dolphin kate plasma-discover plasma-workspace-wayland \
  kitty plymouth plymouth-themes \
  curl wget git vim neovim htop unzip zip tmux zsh openssh-client openssh-server flatpak \
  ca-certificates software-properties-common apt-transport-https \
  build-essential cmake gdb python3 python3-flask python3-psutil python3-requests python3-pip python3-venv python3-inotify python3-watchdog python3-pydantic \
  nodejs npm ripgrep fd-find jq gh smartmontools lm-sensors

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh || true
fi

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh || true
fi

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
        "phi4-mini"
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
