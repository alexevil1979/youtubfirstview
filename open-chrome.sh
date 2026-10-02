#!/usr/bin/env bash
# Открывает Google Chrome (или Chromium) на Ubuntu и загружает заданный сайт.
#
# Использование:
#   ./open-chrome.sh https://example.com
#   ./open-chrome.sh example.com
#
# Необязательно:
#   CHROME_BIN=/usr/bin/google-chrome ./open-chrome.sh https://example.com
#   ./open-chrome.sh --profile /tmp/chrome-profile https://example.com

set -euo pipefail

usage() {
  cat <<'EOF'
Использование: open-chrome.sh [--profile КАТАЛОГ] <url>

Открывает Google Chrome в новом окне и загружает указанный сайт.

Аргументы:
  <url>                 Адрес сайта. Если схема не указана, подставляется https://
  --profile КАТАЛОГ     Отдельный каталог профиля Chrome (не трогает обычный профиль)

Переменные окружения:
  CHROME_BIN            Полный путь к бинарнику Chrome, если автопоиск не подходит

Примеры:
  ./open-chrome.sh https://www.youtube.com
  ./open-chrome.sh example.com
  ./open-chrome.sh --profile "$HOME/.config/chrome-site" https://example.com
EOF
}

find_chrome() {
  if [[ -n "${CHROME_BIN:-}" ]]; then
    if [[ -x "$CHROME_BIN" ]]; then
      printf '%s\n' "$CHROME_BIN"
      return 0
    fi
    echo "CHROME_BIN задан, но файл не найден или не исполняемый: $CHROME_BIN" >&2
    return 1
  fi

  local name candidate
  local names=(google-chrome google-chrome-stable chromium-browser chromium google-chrome-beta)
  local paths=(
    /usr/bin/google-chrome
    /usr/bin/google-chrome-stable
    /usr/bin/chromium-browser
    /usr/bin/chromium
    /snap/bin/chromium
    /opt/google/chrome/chrome
    /opt/google/chrome/google-chrome
  )

  for name in "${names[@]}"; do
    if candidate="$(command -v "$name" 2>/dev/null)"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  for candidate in "${paths[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

normalize_url() {
  local raw="$1"
  if [[ "$raw" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    printf '%s\n' "$raw"
    return 0
  fi
  printf 'https://%s\n' "$raw"
}

PROFILE=""
URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --profile)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Для --profile нужно указать каталог." >&2
        exit 1
      fi
      PROFILE="$2"
      shift 2
      ;;
    --)
      shift
      URL="${1:-}"
      break
      ;;
    -*)
      echo "Неизвестный аргумент: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$URL" ]]; then
        echo "Можно указать только один адрес." >&2
        exit 1
      fi
      URL="$1"
      shift
      ;;
  esac
done

if [[ -z "$URL" ]]; then
  usage >&2
  exit 1
fi

URL="$(normalize_url "$URL")"

if ! CHROME="$(find_chrome)"; then
  echo "Google Chrome не найден. Установите его, например:" >&2
  echo "  wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg" >&2
  echo "  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main' | sudo tee /etc/apt/sources.list.d/google-chrome.list" >&2
  echo "  sudo apt update && sudo apt install -y google-chrome-stable" >&2
  exit 1
fi

ARGS=(--new-window)
if [[ -n "$PROFILE" ]]; then
  mkdir -p "$PROFILE"
  ARGS+=(--user-data-dir="$PROFILE")
fi

echo "Chrome: $CHROME"
echo "Сайт:   $URL"
exec "$CHROME" "${ARGS[@]}" "$URL"
