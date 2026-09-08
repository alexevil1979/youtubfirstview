# Migration: Windows AutoIt → Ubuntu QA Worker

## Что делала Windows-программа

`YouTube_Shorts_AutoView.au3` (AutoIt + GUI Chrome):

1. Читала Bearer-токен из `token.txt`.
2. Запрашивала URL с `GET /api/autoview/urls`.
3. Открывала Chrome с отдельным профилем.
4. Имитировала человека (мышь по Безье, скролл, клики, длинный watch time 45–130с).
5. Отправляла `POST /api/autoview/status` (`done` / `error`, `watch_time`).

Требовала Windows GUI, AutoIt, установленный Chrome.

## Что перенесено

| Функция Windows | Ubuntu worker |
|-----------------|---------------|
| Poll URL с сервера | `JobFetcher` + API client |
| Bearer auth + `worker_id` | `.env` → `Authorization: Bearer` |
| Отчёт статуса | `ResultReporter` |
| Локальный цикл | Worker + SQLite queue |
| Уникальный worker id | `WORKER_ID` |

## Что заменено

| Было | Стало |
|------|-------|
| AutoIt | Node.js 22 + TypeScript |
| GUI Chrome | Playwright Chromium **headless** |
| Имитация человека / длинный watch | Короткий **smoke playback check** (сек.) |
| `log.txt` | Pino JSON → journald / файл |
| Hotkeys F10 | systemd + SIGTERM/SIGINT |
| ChromeProfiles на диске | Ephemeral BrowserContext |

## Что намеренно НЕ реализовано

Согласно политике QA-only:

- искусственная генерация просмотров / длинный watch ради views;
- лайки, комментарии, подписки;
- CAPTCHA bypass / anti-bot stealth;
- прокси-ротация под «разных пользователей»;
- пул Google-аккаунтов;
- кривые Безье / fake human mouse.

## Интеграция с YouPub

Режим по умолчанию: `API_MODE=youpub`.

```
GET  {SERVER_API_URL}/api/autoview/urls?limit=&worker_id=
POST {SERVER_API_URL}/api/autoview/status
     form: url_id, status(done|error), watch_time, worker_id, error?
```

Smoke-результат мапится так:

- success → `status=done`, `watch_time` = фактические секунды проверки;
- failed → `status=error`, `error` = код + сообщение;
- waiting (видео не готово) → локальный retry, без финального `done`.

Опциональный режим `API_MODE=video-tests` — новый контракт из спецификации QA.

## Несколько Ubuntu workers

1. На каждом VPS: `./install.sh`, свой `.env`.
2. Разные `WORKER_ID` (`worker-istanbul-01`, …).
3. Один и тот же `WORKER_TOKEN` или отдельные токены в `api_tokens`.
4. Сервер выдаёт `pending` URL и ставит `processing` + `worker_id` — дубликаты между workers исключаются на стороне MySQL.

## Запуск рядом со старым ботом

Windows AutoIt и Ubuntu worker могут работать параллельно на одном YouPub API.  
Рекомендуется постепенно выводить Windows-клиенты из эксплуатации после стабилизации Ubuntu QA worker.
