# YouPub: где брать AutoView-токен (из кода проекта)

Проверено в `C:\Users\1\Documents\youpub`.

## Правильный URL

Не `/admin/api-tokens` (его нет).

Нужно:

**https://you.1tlt.ru/admin/autoview**  
или зеркало: **https://youpub.site/admin/autoview**

Сначала логин: `/login` (нужен пользователь с `role = admin`).

На странице AutoView — блок «API-токены для AutoIt» → создать.  
Plaintext показывают **один раз**.

В коде: `routes/admin.php` → `GET /admin/autoview`, `POST /admin/autoview/tokens/create`.  
Хранение: `hash('sha256', $plainToken)` в `api_tokens.token` (`AutoViewService::generateToken`).

## Быстрый обход без UI (MySQL на VPS)

```bash
sudo mysql < /path/to/insert_win_token.sql
# или вставь SQL вручную из deploy/insert_win_token.sql
```

В `C:\bots\viewer\token.txt`:

```
a7c3e91f2b4d6800c1e5f9a2d3b4768e0f1a2b3c4d5e6f708192a3b4c5d6e7f8
```

Проверка:

```powershell
$token = (Get-Content C:\bots\viewer\token.txt -Raw).Trim()
Invoke-RestMethod -Uri "https://you.1tlt.ru/api/autoview/urls?limit=1&worker_id=test" -Headers @{ Authorization = "Bearer $token" }
```

## Админ-логин

Дефолтный email в скрипте сброса: `admin@youpub.site`  
(`youpub/scripts/reset_admin_password.php`). Пароль в репо не хранится — сброс на VPS:

```bash
cd /path/to/youpub && php scripts/reset_admin_password.php 'НовыйПароль'
```
