# YouTube QA Worker (Ubuntu 22.04)

Headless Node.js/TypeScript worker для **технического smoke-тестирования** собственных опубликованных YouTube-видео на сервере без GUI.

> Это не система накрутки просмотров. Нет лайков, комментариев, подписок, stealth/CAPTCHA bypass, прокси-ротации аккаунтов.

Замена Windows AutoIt-клиента (`YouTube_Shorts_AutoView.au3`) — см. [MIGRATION.md](./MIGRATION.md). Архитектура: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Требования

- Ubuntu Server 22.04 LTS (без Desktop/X11/VNC)
- Node.js 22+
- systemd (для прод)
- Доступ к серверу публикаций (YouPub) по HTTPS

## Быстрый старт

```bash
cd worker
cp .env.example .env
# заполните SERVER_API_URL, WORKER_TOKEN, WORKER_ID

npm install
npx playwright install --with-deps chromium
npm run build
npm start
```

Или одной командой на чистой Ubuntu:

```bash
sudo ./install.sh
```

## Команды

| Команда | Описание |
|---------|----------|
| `npm start` | Запуск worker |
| `npm run dev` | Dev с tsx watch |
| `npm run build` | Компиляция TypeScript |
| `npm run typecheck` | Проверка типов |
| `npm test` | Тесты |
| `npm run worker:status` | Статус из SQLite |
| `npm run worker:jobs` | Список локальных jobs |
| `npm run worker:health` | HTTP health |
| `npm run worker:test -- <url>` | Ручной smoke test одного URL |

## systemd

```bash
sudo systemctl enable youtube-qa-worker
sudo systemctl start youtube-qa-worker
sudo systemctl status youtube-qa-worker
journalctl -u youtube-qa-worker -f
```

Health:

```bash
curl http://127.0.0.1:8080/health
```

## Конфигурация (.env)

См. `.env.example`. Ключевые переменные:

- `SERVER_API_URL` — базовый URL YouPub (например `https://you.1tlt.ru`)
- `WORKER_TOKEN` — Bearer-токен (не логируется)
- `WORKER_ID` — уникальный id инстанса
- `API_MODE` — `youpub` (по умолчанию) или `video-tests`
- `MAX_CONCURRENT_JOBS` — лимит параллельных Chromium (обычно 1–2)
- `PLAYBACK_TEST_SECONDS` — длительность playback smoke check

## API contract

### Режим youpub (существующий сервер)

- `GET /api/autoview/urls?limit=&worker_id=` + `Authorization: Bearer …`
- `POST /api/autoview/status` — form: `url_id`, `status`, `watch_time`, `worker_id`, `error`

### Режим video-tests (новый контракт)

- `GET /api/video-tests/jobs`
- `POST /api/video-tests/jobs/{id}/claim`
- `POST /api/video-tests/jobs/{id}/result`
- `POST /api/video-tests/jobs/{id}/complete`

Пример результата smoke test:

```json
{
  "status": "success",
  "video_id": "xxxx",
  "started_at": "2026-09-09T00:00:00.000Z",
  "finished_at": "2026-09-09T00:00:12.000Z",
  "page_loaded": true,
  "player_loaded": true,
  "playback_started": true,
  "duration_checked": 5,
  "error": null
}
```

## Docker (опционально)

```bash
docker compose up -d --build
```

## Структура

```
worker/
├── src/
│   ├── index.ts
│   ├── api/
│   ├── browser/
│   ├── queue/
│   ├── storage/
│   ├── health/
│   ├── logging/
│   ├── config/
│   └── …
├── scripts/
├── systemd/
├── tests/
├── Dockerfile
├── docker-compose.yml
├── install.sh
└── .env.example
```

## Безопасность

- Токены только в `.env` / EnvironmentFile systemd
- `WORKER_TOKEN` никогда не пишется в логи
- Worker не запускается от root (пользователь `youtube-worker`)
