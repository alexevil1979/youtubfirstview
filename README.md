# YouTube Shorts AutoView

Автоматический просмотр YouTube Shorts с имитацией поведения реального пользователя.

## Описание

Система состоит из двух частей:

1. **AutoIt скрипт** (`YouTube_Shorts_AutoView.au3`) — клиентская часть, запускается на Windows
2. **PHP сервер** (`server/`) — серверная часть, управляет очередью URL'ов

### Как работает

1. Скрипт запрашивает URL'ы с сервера (GET запрос)
2. Открывает каждый URL в отдельном окне Chrome с уникальным профилем
3. Имитирует поведение человека: плавные движения мыши по кривой Безье, скроллинг, случайные клики, паузы
4. Находится на странице 45–130 секунд
5. Отправляет статус на сервер (POST запрос)
6. Повторяет цикл

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

Разместите файлы `get_urls.php` и `status.php` на вашем веб-сервере.

### 2. Настройка клиента

Откройте `YouTube_Shorts_AutoView.au3` и измените настройки в начале файла:

```autoit
Global Const $API_BASE_URL = "http://your-server.ru"    ; Адрес вашего сервера
Global Const $CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 3. Запуск

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
[2026-02-08 15:30:01] === Скрипт запущен ===
[2026-02-08 15:30:01] Запрашиваю URL'ы с сервера...
[2026-02-08 15:30:02] Получено URL'ов: 5
[2026-02-08 15:30:02] Начинаю просмотр URL #1: https://youtube.com/shorts/xxx
[2026-02-08 15:30:10] Действие: Движение мыши -> 450,320
[2026-02-08 15:31:15] URL #1 отработан. Время просмотра: 73 сек.
```

## Структура проекта

```
autoityoutube/
├── YouTube_Shorts_AutoView.au3   # Основной скрипт AutoIt
├── README.md                      # Документация
├── .gitignore                     # Исключения Git
├── server/
│   ├── get_urls.php               # API: получение URL'ов
│   ├── status.php                 # API: приём статуса просмотра
│   └── setup_database.sql         # SQL для создания БД
└── ChromeProfiles/                # Профили Chrome (создаются автоматически)
```

## API

### GET /get_urls.php

Получение URL'ов для просмотра.

**Параметры:**
- `limit` (int) — количество URL'ов (по умолчанию 5, максимум 20)

**Ответ:**
```json
[
  {"id": "1", "url": "https://youtube.com/shorts/xxxxx"},
  {"id": "2", "url": "https://youtube.com/shorts/yyyyy"}
]
```

### POST /status.php

Отправка статуса просмотра.

**Параметры (form-data):**
- `url_id` (int) — ID просмотренного URL
- `status` (string) — `done` или `error`
- `watch_time` (int) — время просмотра в секундах

**Ответ:**
```json
{"success": true, "message": "Status updated"}
```

## Лицензия

MIT
