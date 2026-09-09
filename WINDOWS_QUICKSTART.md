# Быстрый запуск старой версии (Windows 10)

Гайд для **AutoIt-клиента** `YouTube_Shorts_AutoView.au3` на новой машине с Windows 10.  
На ПК ставятся только клиент и Chrome. Сервер API уже должен работать.

> Это legacy Windows-бот. Для Ubuntu headless см. `worker/` и `deploy/DEPLOY.md`.

---

## Про токен (как было раньше)

Токен — это просто строка в таблице `api_tokens` на сервере.  
Админка для этого **не нужна**: как в старой версии — создали в MySQL → положили в `token.txt`.

### 1) Создать токен на сервере (MySQL)

```sql
INSERT INTO api_tokens (token, description, is_active)
VALUES ('my-win10-secret-token', 'Бот на компьютере Win10 №1', 1);
```

Подставьте свою длинную строку вместо `my-win10-secret-token`.

Проверка:

```sql
SELECT id, token, description, is_active FROM api_tokens;
```

### 2) Файл на Windows-ПК

Рядом со скриптом создайте `token.txt` — **одна строка**, тот же текст:

```
my-win10-secret-token
```

Без кавычек, без пробелов в начале/конце.

Готово. Скрипт читает только `token.txt` (или значение `$g_sApiToken` в коде). Веб-морда тут ни при чём.

---

## Что нужно заранее

1. Доступ к серверу API, например:
   - `https://you.1tlt.ru` (как в скрипте по умолчанию)
   - или `https://youtubview.1tlt.ru` (если переключили URL)
2. Токен в БД + `token.txt` (см. выше)
3. В очереди есть URL со статусом `pending`

---

## 1. Установить программы (5–10 мин)

| ПО | Куда |
|----|------|
| **Google Chrome** | [https://www.google.com/chrome/](https://www.google.com/chrome/) |
| **AutoIt v3** | [https://www.autoitscript.com/site/autoit/downloads/](https://www.autoitscript.com/site/autoit/downloads/) → *AutoIt Full Installation* |

Рекомендуется **SciTE4AutoIt3** — удобно править `$API_BASE_URL`.

Путь Chrome обычно:

```
C:\Program Files\Google\Chrome\Application\chrome.exe
```

---

## 2. Скопировать файлы на ПК

```
C:\bots\youtubview\
├── YouTube_Shorts_AutoView.au3
└── token.txt
```

`ChromeProfiles\` и `log.txt` появятся сами после запуска.

---

## 3. Указать сервер API

В начале `YouTube_Shorts_AutoView.au3`:

```autoit
Global Const $API_BASE_URL = "https://you.1tlt.ru"
Global Const $CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

Меняйте `$API_BASE_URL` только если API на другом домене. Сохраните файл.

---

## 4. Запуск

1. Нужен обычный рабочий стол (мышь/клавиатура) — не headless-сервер.
2. Двойной клик по `YouTube_Shorts_AutoView.au3` (или SciTE → `F5`).
3. При UAC — разрешить (`#RequireAdmin`).

В `log.txt`:

```
=== Скрипт запущен (v2.0 YouPub) ===
Токен загружен из token.txt (...)
Получено URL'ов: N
```

Стоп: **F10** или **Ctrl+Alt+Q**.

---

## 5. Быстрая проверка API

```powershell
$token = (Get-Content C:\bots\youtubview\token.txt -Raw).Trim()
$base = "https://you.1tlt.ru"   # тот же, что $API_BASE_URL
$uri = "$base/api/autoview/urls?limit=1&worker_id=win10-test"
Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" }
```

| Ответ | Значение |
|-------|----------|
| JSON с URL | токен и сервер OK |
| `401` | токена нет в БД / `is_active=0` / опечатка в `token.txt` |
| таймаут | сеть / DNS / неверный `$API_BASE_URL` |

---

## 6. Автозапуск (опционально)

`Win+R` → `shell:startup` → ярлык на `.au3` (или скомпилированный `.exe`).

---

## Типичные проблемы

| Симптом | Что сделать |
|---------|-------------|
| «API-токен не найден» | Создайте `token.txt` рядом со скриптом |
| `401 Unauthorized` | `INSERT` в `api_tokens`, строка в `token.txt` должна совпадать 1 в 1 |
| «Chrome не найден» | Поправьте `$CHROME_PATH` |
| Нет URL | Добавьте записи в таблицу `urls` со статусом `pending` |
| Не кликает | Нужна активная сессия Windows (не locked без GUI) |

---

## Чеклист

- [ ] Chrome + AutoIt  
- [ ] `INSERT` в `api_tokens`  
- [ ] `token.txt` = тот же токен  
- [ ] `$API_BASE_URL` верный  
- [ ] PowerShell-тест без 401  
- [ ] Скрипт пишет в `log.txt`, статусы URL на сервере меняются  

Как и раньше: Windows-клиент = `.au3` + `token.txt` + запись в MySQL.
