#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${KISMET_MODEL_CONFIG:-/etc/kismet/models.env}"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "kismet-ollama-loader: missing $CONFIG_FILE, nothing to preload"
  exit 0
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

if ! command -v ollama >/dev/null 2>&1; then
  echo "kismet-ollama-loader: ollama not installed"
  exit 0
fi

MODELS="${KISMET_OLLAMA_MODELS:-}"
KEEP_ALIVE="${KISMET_OLLAMA_KEEP_ALIVE:-30m}"

if [ -z "$MODELS" ]; then
  echo "kismet-ollama-loader: no models configured"
  exit 0
fi

systemctl start ollama.service
sleep 3

for model in $MODELS; do
  echo "==> ensuring model $model"
  ollama pull "$model"
  OLLAMA_KEEP_ALIVE="$KEEP_ALIVE" ollama run "$model" "Ready." >/dev/null 2>&1 || true
done
