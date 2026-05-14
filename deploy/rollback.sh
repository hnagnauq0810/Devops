#!/usr/bin/env bash
set -Eeuo pipefail

APP_PORT="${APP_PORT:-8080}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.bluegreen.yml}"
STATE_FILE="${STATE_FILE:-.deploy-state}"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "No deployment state found. Cannot rollback." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$STATE_FILE"

if [[ "$ACTIVE_COLOR" == "blue" ]]; then
  TARGET_COLOR="green"
elif [[ "$ACTIVE_COLOR" == "green" ]]; then
  TARGET_COLOR="blue"
else
  echo "Invalid ACTIVE_COLOR in ${STATE_FILE}: ${ACTIVE_COLOR}" >&2
  exit 1
fi

export IMAGE_NAME="${IMAGE_NAME:-fastapi-devops-pipeline}" BLUE_IMAGE_TAG GREEN_IMAGE_TAG APP_PORT

docker compose -f "$COMPOSE_FILE" up -d --no-deps "app_${TARGET_COLOR}"
CID="$(docker compose -f "$COMPOSE_FILE" ps -q "app_${TARGET_COLOR}")"
STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$CID")"

if [[ "$STATUS" != "healthy" ]]; then
  echo "Rollback target app_${TARGET_COLOR} is not healthy. Current status: ${STATUS}" >&2
  exit 1
fi

./deploy/render-nginx-conf.sh "$TARGET_COLOR"
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -s reload

ACTIVE_COLOR="$TARGET_COLOR"
cat > "$STATE_FILE" <<STATE
ACTIVE_COLOR=${ACTIVE_COLOR}
BLUE_IMAGE_TAG=${BLUE_IMAGE_TAG}
GREEN_IMAGE_TAG=${GREEN_IMAGE_TAG}
STATE

curl --fail --silent --show-error "http://127.0.0.1:${APP_PORT}/health" >/dev/null
echo "Rollback succeeded. Active color: ${ACTIVE_COLOR}"
