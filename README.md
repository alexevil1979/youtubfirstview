# YouTube Shorts AutoView v2.0 (YouPub)

Автоматический просмотр YouTube Shorts с имитацией поведения реального пользователя.
Интеграция с сервером YouPub (`https://you.1tlt.ru`).

## Описание

Система состоит из двух частей:

1. **AutoIt скрипт** (`YouTube_Shorts_AutoView.au3`) — клиентская часть (бот), запускается на Windows
2. **PHP сервер** (`server/`) — серверная часть YouPub, управляет очередью URL'ов

### Как работает

1. Скрипт загружает Bearer-токен из `token.txt`
2. Запрашивает URL'ы с сервера (GET с авторизацией)
3. Открывает каждый URL в отдельном окне Chrome с уникальным профилем
4. Имитирует поведение человека: плавные движения мыши по кривой Безье, скроллинг, случайные клики, паузы
5. Время просмотра берётся от сервера (`target_watch_time`) ±20%, или случайное 45–130 сек
6. Отправляет статус на сервер (POST: `done` или `error` с описанием)
7. Повторяет цикл каждые 30–60 секунд

### Worker ID

Каждый запущенный экземпляр скрипта генерирует уникальный `worker_id` в формате:
`bot_COMPUTERNAME_XXXX` (последние 4 цифры PID). Это позволяет серверу отслеживать, какой бот обрабатывает какие URL'ы.

## Требования

### Клиент (Windows)
- Windows 7/10/11
- [AutoIt v3](https://www.autoitscript.com/site/autoit/downloads/)
- Google Chrome

### Сервер
- PHP 7.4+
- MySQL 5.7+ / MariaDB 10.3+
- Веб-сервер (Apache / Nginx)

## Установка

### 1. Настройка сервера

```sql
-- Импортируйте базу данных
mysql -u root -p < server/setup_database.sql
```

Настройте подключение к БД в файлах:
- `server/get_urls.php` — переменные `$db_host`, `$db_name`, `$db_user`, `$db_pass`
- `server/status.php` — аналогично

Разместите файлы на вашем веб-сервере. Настройте маршруты:
- `GET /api/autoview/urls` → `server/get_urls.php`
- `POST /api/autoview/status` → `server/status.php`

### 2. Создание API-токена

```sql
INSERT INTO api_tokens (token, description)
VALUES ('ваш-секретный-токен', 'Бот на компьютере №1');
```

### 3. Настройка клиента

1. Создайте файл `token.txt` рядом со скриптом и вставьте в него API-токен
2. При необходимости отредактируйте настройки в начале `YouTube_Shorts_AutoView.au3`:

```autoit
Global Const $API_BASE_URL = "https://you.1tlt.ru"    ; Адрес сервера YouPub
Global Const $CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 4. Запуск

1. Установите AutoIt v3
2. Добавьте URL'ы в базу данных (таблица `urls`)
3. Запустите скрипт двойным кликом по `YouTube_Shorts_AutoView.au3`

## Управление

| Горячая клавиша | Действие |
|----------------|----------|
| `F10` | Остановка скрипта |
| `Ctrl+Alt+Q` | Остановка скрипта |

## Логирование

Все действия записываются в файл `log.txt` в директории скрипта.

Пример лога:
```
[2026-02-08 15:30:01] === Скрипт запущен (v2.0 YouPub) ===
[2026-02-08 15:30:01] API сервер: https://you.1tlt.ru
[2026-02-08 15:30:01] Worker ID: bot_PC01_7842
[2026-02-08 15:30:01] Токен загружен из token.txt (a1b2c3d4...)
[2026-02-08 15:30:02] Получено URL'ов: 5
[2026-02-08 15:30:02] Целевое время (от сервера ±20%): 35 сек. (базовое: 30)
[2026-02-08 15:31:15] URL #1 отработан. Время просмотра: 35 сек.
```

## Структура проекта

```
autoityoutube/
├── YouTube_Shorts_AutoView.au3   # Основной скрипт AutoIt (v2.0)
├── token.txt                      # API-токен (НЕ коммитится в git!)
├── README.md                      # Документация
├── .gitignore                     # Исключения Git
├── server/
│   ├── get_urls.php               # API: GET /api/autoview/urls
│   ├── status.php                 # API: POST /api/autoview/status
│   └── setup_database.sql         # SQL-схема БД (v2.0)
└── ChromeProfiles/                # Профили Chrome (создаются автоматически)
```

## API v2.0

### GET /api/autoview/urls

Получение URL'ов для просмотра.

**Заголовки:**
- `Authorization: Bearer <token>`

**Параметры:**
- `limit` (int) — количество URL'ов (по умолчанию 5, максимум 20)
- `worker_id` (string) — идентификатор бота

**Ответ (200):**
```json
[
  {"id": 1, "url": "https://youtube.com/shorts/xxxxx", "target_watch_time": 30},
  {"id": 2, "url": "https://youtube.com/shorts/yyyyy", "target_watch_time": 0}
]
```

**Ошибки:**
- `401` — неверный или просроченный токен
- `500` — ошибка сервера

### POST /api/autoview/status

Отправка статуса просмотра.

**Заголовки:**
- `Authorization: Bearer <token>`

**Параметры (form-data):**
- `url_id` (int) — ID просмотренного URL
- `status` (string) — `done` или `error`
- `watch_time` (int) — время просмотра в секундах
- `worker_id` (string) — идентификатор бота
- `error` (string, опционально) — описание ошибки

**Ответ (200):**
```json
{"success": true, "message": "Status updated"}
```

## БД: Таблицы

| Таблица | Описание |
|---------|----------|
| `api_tokens` | Токены авторизации ботов |
| `urls` | Очередь URL'ов с приоритетами |
| `view_log` | Лог всех действий ботов (JSON-детали) |

## Лицензия

MIT
