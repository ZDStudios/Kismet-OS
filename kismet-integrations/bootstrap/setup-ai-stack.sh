#!/usr/bin/env bash
set -euo pipefail

echo "==> Kismet AI stack bootstrap"

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama not found. Install it first or run the Kismet base bootstrap."
  exit 1
fi

if ! systemctl is-enabled ollama >/dev/null 2>&1; then
  sudo systemctl enable ollama || true
fi
sudo systemctl start ollama || true

echo "==> Ollama service ensured"
echo "Next steps to implement:"
echo "- pre-pull baseline models"
echo "- install OpenClaw setup hooks"
echo "- create desktop launchers and shortcuts"
