# Быстрый запуск старой версии (Windows 10)

Гайд для **AutoIt-клиента** `YouTube_Shorts_AutoView.au3` на новой машине с Windows 10.  
Сервер (админка/API) уже должен быть доступен; на ПК ставятся только клиент и Chrome.

> Это legacy Windows-бот. Для Ubuntu headless см. `worker/` и `deploy/DEPLOY.md`.

---

## Что нужно заранее

1. Доступ к серверу API (один из вариантов):
   - новый: `https://youtubview.1tlt.ru`
   - старый: `https://you.1tlt.ru`
2. API-токен из админки (**API-токены** / Create token) или из БД `api_tokens`
3. В очереди на сервере есть URL со статусом `pending`

---

## 1. Установить программы (5–10 мин)

| ПО | Куда |
|----|------|
| **Google Chrome** | [https://www.google.com/chrome/](https://www.google.com/chrome/) |
| **AutoIt v3** | [https://www.autoitscript.com/site/autoit/downloads/](https://www.autoitscript.com/site/autoit/downloads/) → *AutoIt Full Installation* |

Рекомендуется также поставить **SciTE4AutoIt3** (редактор) с той же страницы — удобно править `$API_BASE_URL`.

Проверьте путь Chrome (обычно так):

```
C:\Program Files\Google\Chrome\Application\chrome.exe
```

Если Chrome в другом месте (x86) — поправите путь в скрипте (шаг 3).

---

## 2. Скопировать файлы на ПК

Создайте папку, например:

```
C:\bots\youtubview\
```

Положите туда минимум:

```
C:\bots\youtubview\
├── YouTube_Shorts_AutoView.au3
└── token.txt
```

`token.txt` — одна строка, только токен, без кавычек и пробелов:

```
ваш-секретный-токен
```

Файлы `ChromeProfiles\` и `log.txt` появятся сами после первого запуска.

---

## 3. Указать сервер API (обязательно проверить)

Откройте `YouTube_Shorts_AutoView.au3` в SciTE и найдите строки:

```autoit
Global Const $API_BASE_URL = "https://you.1tlt.ru"
Global Const $CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

Если работаете с новой админкой — поставьте:

```autoit
Global Const $API_BASE_URL = "https://youtubview.1tlt.ru"
```

Сохраните файл (`Ctrl+S`).

Опционально можно менять:

- `$API_LIMIT` — сколько URL брать за раз (по умолчанию 5)
- `$MIN_WATCH_TIME` / `$MAX_WATCH_TIME` — если сервер не задал `target_watch_time`

---

## 4. Запуск

1. ПК разблокирован, есть монитор/RDP (скрипт кликает мышью — **нужен интерактивный рабочий стол**).
2. Закройте лишние окна Chrome или оставьте один профиль — скрипт сам откроет окна с отдельными профилями.
3. Двойной клик по `YouTube_Shorts_AutoView.au3`  
   (или ПКМ → *Run Script* / в SciTE клавиша `F5`).
4. При запросе UAC — разрешите (скрипт с `#RequireAdmin`).

В логе `log.txt` должно появиться примерно:

```
=== Скрипт запущен (v2.0 YouPub) ===
API сервер: https://youtubview.1tlt.ru
Worker ID: bot_PCNAME_1234
Токен загружен из token.txt (...)
Получено URL'ов: N
```

Остановка: **F10** или **Ctrl+Alt+Q**.

---

## 5. Быстрая проверка «всё живо»

В PowerShell (подставьте свой токен и URL сервера):

```powershell
$token = Get-Content C:\bots\youtubview\token.txt -Raw
$token = $token.Trim()
$uri = "https://youtubview.1tlt.ru/api/autoview/urls?limit=1&worker_id=win10-test"
Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" }
```

- JSON с URL → токен и сервер OK, можно запускать `.au3`
- `401` → неверный/неактивный токен
- таймаут/DNS → проверьте интернет и домен

В админке: **Логи** / статусы URL должны меняться на `processing` → `done`/`error`.

---

## 6. Автозапуск при входе в Windows (опционально)

1. `Win+R` → `shell:startup`
2. Создайте ярлык на `YouTube_Shorts_AutoView.au3`
3. Либо скомпилируйте в `.exe` (SciTE → Tools → Build) и положите ярлык на `.exe`

Важно: пользователь должен быть залогинен (не только «заблокированный экран» без сессии). Для серверов без GUI лучше Ubuntu worker.

---

## Типичные проблемы

| Симптом | Что сделать |
|---------|-------------|
| «API-токен не найден» | Создайте `token.txt` рядом со скриптом |
| «Chrome не найден» | Поправьте `$CHROME_PATH` (часто `C:\Program Files (x86)\...`) |
| Нет URL / пустой ответ | В админке добавьте URL в очередь (`pending`) |
| 401 в логе | Новый токен, проверьте `is_active` |
| Окна не кликаются | Не сворачивайте сессию; не запускайте без GUI; не мешайте мышью во время просмотра |
| Антивирус блокирует AutoIt | Разрешите папку бота / добавьте исключение |

---

## Чеклист на новой Win 10

- [ ] Chrome установлен, путь верный  
- [ ] AutoIt v3 установлен  
- [ ] Папка с `.au3` + `token.txt`  
- [ ] `$API_BASE_URL` указывает на ваш сервер  
- [ ] PowerShell-тест API возвращает URL  
- [ ] Скрипт запущен, в `log.txt` есть `Worker ID` и просмотры  
- [ ] В админке статусы URL обновляются  

Готово: машина в работе как Windows-worker `bot_<ИМЯ_ПК>_<PID>`.
