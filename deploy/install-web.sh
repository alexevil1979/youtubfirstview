#!/usr/bin/env bash
# Deploy / refresh web app files into /ssd/www/youpubview
set -euo pipefail

TARGET="${TARGET:-/ssd/www/youpubview}"
SRC="$(cd "$(dirname "$0")/.." && pwd)/web"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo ./deploy/install-web.sh"
  exit 1
fi

mkdir -p "$TARGET"
rsync -a --delete \
  --exclude config.php \
  --exclude '.git' \
  "$SRC/" "$TARGET/"

if [[ ! -f "$TARGET/config.php" ]]; then
  cp "$TARGET/config.example.php" "$TARGET/config.php"
  echo "Created $TARGET/config.php — edit DB credentials"
fi

chown -R www-data:www-data "$TARGET"
find "$TARGET" -type d -exec chmod 755 {} \;
find "$TARGET" -type f -exec chmod 644 {} \;
chmod 640 "$TARGET/config.php" || true

echo "Web deployed to $TARGET"
echo "DocumentRoot should be $TARGET/public"
