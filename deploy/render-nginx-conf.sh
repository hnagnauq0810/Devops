#!/usr/bin/env bash
set -euo pipefail

COLOR="${1:?Usage: deploy/render-nginx-conf.sh blue|green}"
if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
  echo "Color must be blue or green" >&2
  exit 1
fi

cat > deploy/nginx/default.conf <<CONF
server {
    listen 80;
    server_name _;

    resolver 127.0.0.11 valid=10s ipv6=off;
    set \$upstream fastapi_${COLOR}:8000;

    location / {
        proxy_pass http://\$upstream;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
CONF
