#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/kismet-test/docker-compose.vnc.yml"
SERVICE="kismet-test-desktop"

cd "$ROOT_DIR/kismet-test"

docker compose -f "$COMPOSE_FILE" up --build -d

CONTAINER_ID="$(docker compose -f "$COMPOSE_FILE" ps -q "$SERVICE")"
if [ -z "$CONTAINER_ID" ]; then
  echo "Preview test container did not start." >&2
  exit 1
fi

for _ in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER_ID")"
  if [ "$STATUS" = "healthy" ] || [ "$STATUS" = "running" ]; then
    break
  fi
  sleep 2
done

STATUS="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER_ID")"
if [ "$STATUS" != "healthy" ] && [ "$STATUS" != "running" ]; then
  docker compose -f "$COMPOSE_FILE" logs --tail=200
  echo "Preview test container is not healthy: $STATUS" >&2
  exit 1
fi

echo "==> Checking preview web root"
curl -fsS http://127.0.0.1:6080/ >/dev/null

echo "==> Checking firstboot wizard availability"
docker exec "$CONTAINER_ID" test -x /usr/local/bin/kismet-firstboot-wizard

echo "==> Preview test container is up and passed smoke checks"
