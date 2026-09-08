#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/youtube-qa-worker}"
SERVICE_USER="${SERVICE_USER:-youtube-worker}"
REPO_SRC="$(cd "$(dirname "$0")" && pwd)"

echo "==> YouTube QA Worker installer"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh"
  exit 1
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "Warning: expected Ubuntu, found ID=${ID:-unknown}"
  fi
  if [[ "${VERSION_ID:-}" != "22.04" ]]; then
    echo "Warning: tested on 22.04, found VERSION_ID=${VERSION_ID:-unknown}"
  fi
else
  echo "Cannot detect OS (/etc/os-release missing)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates build-essential python3

if ! command -v node >/dev/null 2>&1; then
  echo "==> Installing Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

NODE_MAJOR="$(node -v | sed 's/v//;s/\..*//')"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  echo "Node.js >= 22 required, found $(node -v)"
  exit 1
fi

if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
  useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
fi

mkdir -p "$APP_DIR" "$APP_DIR/data" "$APP_DIR/logs"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude node_modules \
    --exclude data \
    --exclude .env \
    --exclude dist \
    "$REPO_SRC/" "$APP_DIR/"
else
  apt-get install -y rsync
  rsync -a --delete \
    --exclude node_modules \
    --exclude data \
    --exclude .env \
    --exclude dist \
    "$REPO_SRC/" "$APP_DIR/"
fi

cd "$APP_DIR"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created $APP_DIR/.env — edit WORKER_TOKEN / SERVER_API_URL / WORKER_ID before production use"
fi

npm install --omit=dev
npx playwright install-deps chromium || true
npx playwright install chromium
npm run build

chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"

install -m 644 "$APP_DIR/systemd/youtube-qa-worker.service" /etc/systemd/system/youtube-qa-worker.service
systemctl daemon-reload
systemctl enable youtube-qa-worker

# Only start if token looks configured
if grep -q '^WORKER_TOKEN=.\+' .env; then
  systemctl restart youtube-qa-worker
  systemctl --no-pager --full status youtube-qa-worker || true
  echo "==> Health check"
  sleep 2
  curl -fsS "http://127.0.0.1:8080/health" || echo "Health endpoint not ready yet — check journalctl -u youtube-qa-worker"
else
  echo "==> Service enabled but not started: set WORKER_TOKEN in $APP_DIR/.env then: systemctl start youtube-qa-worker"
fi

echo "==> Done"
echo "Commands:"
echo "  systemctl status youtube-qa-worker"
echo "  journalctl -u youtube-qa-worker -f"
echo "  curl http://127.0.0.1:8080/health"
