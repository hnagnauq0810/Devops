#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_TAG="${1:-${IMAGE_TAG:-latest}}"
IMAGE_NAME="${IMAGE_NAME:-fastapi-devops-pipeline}"
APP_PORT="${APP_PORT:-8080}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.bluegreen.yml}"
STATE_FILE="${STATE_FILE:-.deploy-state}"
STOP_OLD="${STOP_OLD:-false}"

ACTIVE_COLOR="none"
BLUE_IMAGE_TAG="latest"
GREEN_IMAGE_TAG="latest"

if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

if [[ "$ACTIVE_COLOR" == "blue" ]]; then
  TARGET_COLOR="green"
  OLD_COLOR="blue"
else
  TARGET_COLOR="blue"
  OLD_COLOR="green"
fi

if [[ "$TARGET_COLOR" == "blue" ]]; then
  BLUE_IMAGE_TAG="$IMAGE_TAG"
else
  GREEN_IMAGE_TAG="$IMAGE_TAG"
fi

export IMAGE_NAME BLUE_IMAGE_TAG GREEN_IMAGE_TAG APP_PORT

echo "Deploying image ${IMAGE_NAME}:${IMAGE_TAG} to ${TARGET_COLOR} environment"

docker compose -f "$COMPOSE_FILE" pull "app_${TARGET_COLOR}" || true
docker compose -f "$COMPOSE_FILE" up -d nginx
docker compose -f "$COMPOSE_FILE" up -d --no-deps "app_${TARGET_COLOR}"

CID="$(docker compose -f "$COMPOSE_FILE" ps -q "app_${TARGET_COLOR}")"
if [[ -z "$CID" ]]; then
  echo "Could not find container for app_${TARGET_COLOR}" >&2
  exit 1
fi

echo "Waiting for app_${TARGET_COLOR} health check..."
for i in $(seq 1 40); do
  STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$CID")"
  if [[ "$STATUS" == "healthy" ]]; then
    echo "app_${TARGET_COLOR} is healthy"
    break
  fi
  if [[ "$STATUS" == "unhealthy" ]]; then
    echo "app_${TARGET_COLOR} became unhealthy" >&2
    docker logs "$CID" --tail 80 >&2 || true
    exit 1
  fi
  sleep 3
  if [[ "$i" == "40" ]]; then
    echo "Timed out waiting for app_${TARGET_COLOR} to become healthy" >&2
    docker logs "$CID" --tail 80 >&2 || true
    exit 1
  fi
done

./deploy/render-nginx-conf.sh "$TARGET_COLOR"
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -s reload

ACTIVE_COLOR="$TARGET_COLOR"
cat > "$STATE_FILE" <<STATE
ACTIVE_COLOR=${ACTIVE_COLOR}
BLUE_IMAGE_TAG=${BLUE_IMAGE_TAG}
GREEN_IMAGE_TAG=${GREEN_IMAGE_TAG}
STATE

echo "Traffic switched to ${TARGET_COLOR}. Verifying proxy..."
curl --fail --silent --show-error "http://127.0.0.1:${APP_PORT}/health" >/dev/null

if [[ "$STOP_OLD" == "true" && "$OLD_COLOR" != "none" ]]; then
  docker compose -f "$COMPOSE_FILE" stop "app_${OLD_COLOR}" || true
fi

echo "Deployment succeeded. Active color: ${ACTIVE_COLOR}"
