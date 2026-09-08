# Architecture — YouTube QA Worker (Ubuntu)

## Цель

Headless worker на Ubuntu 22.04 без GUI для **технического smoke-тестирования** собственных опубликованных YouTube-видео:

- URL доступен (DNS/TLS/HTTP);
- страница открывается в Chromium;
- YouTube-плеер загрузился;
- playback технически стартует;
- результат уходит на сервер публикаций.

**Не цель:** накрутка просмотров, engagement, обход anti-bot.

## Компоненты

```
┌─────────────────────────────────────────────────────────┐
│ Worker (systemd / docker)                               │
│  ┌────────────┐  ┌──────────┐  ┌─────────────────────┐  │
│  │ JobFetcher │→│ JobQueue │→│ VideoSmokeTest       │  │
│  └────────────┘  └──────────┘  │  └─ BrowserManager  │  │
│         │              │       └─────────────────────┘  │
│         │              │                │               │
│         ▼              ▼                ▼               │
│  ┌────────────┐  ┌──────────┐  ┌─────────────────────┐  │
│  │ API Client │  │ SQLite   │  │ ResultReporter      │  │
│  └────────────┘  └──────────┘  └─────────────────────┘  │
│  ┌────────────┐  ┌──────────┐  ┌─────────────────────┐  │
│  │ RetryMgr   │  │ Health   │  │ ResourceMonitor     │  │
│  └────────────┘  └──────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

| Модуль | Ответственность |
|--------|-----------------|
| `JobFetcher` | Poll сервера, claim jobs |
| `JobQueue` | Локальная очередь + статусы + SQLite lock |
| `BrowserManager` | Lifecycle Chromium/context/page |
| `VideoSmokeTest` | HTTP preflight + Playwright проверки |
| `ResultReporter` | POST результата на сервер |
| `RetryManager` | Exponential backoff |
| `HealthMonitor` | `/health`, `/metrics` |
| `Storage` | SQLite persistence + crash recovery |
| `ResourceMonitor` | RAM/load перед запуском browser |

## Поток задачи

1. Poll API → получить jobs.
2. Claim (сервер или локальный lock) → `pending` → `running`.
3. Resource check (RAM/slots).
4. HTTP HEAD/GET preflight.
5. Headless Chromium: open URL → player → short playback check.
6. Report result → `success` / `failed` / `retry`.
7. Закрыть context/page; проверить отсутствие zombie Chromium.

## API modes

| Mode | Fetch | Report | Назначение |
|------|-------|--------|------------|
| `youpub` | `GET /api/autoview/urls` | `POST /api/autoview/status` | Существующий YouPub |
| `video-tests` | `GET /api/video-tests/jobs` + claim/complete | `POST .../result` | Новый контракт |

## Concurrency

- `MAX_CONCURRENT_JOBS` — semaphore slots.
- Один job = один BrowserContext.
- Browser не держится idle между jobs.

## Persistence & recovery

При старте: все `running` → `pending` (crash recovery).
Graceful shutdown: stop poll → drain → close browsers → flush SQLite.

## Масштабирование

Несколько Ubuntu VPS, у каждого свой `WORKER_ID`. Распределение jobs — на стороне сервера.
