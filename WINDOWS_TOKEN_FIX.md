# Почему 401 и как получить рабочий токен YouPub

## Диагноз

Проверено запросами к `https://you.1tlt.ru/api/autoview/urls`:

- Все 3 значения из `youpub.api_tokens.token` → **401 Invalid or revoked token**
- Ответ API: `Generate a token at /admin/api-tokens`

В таблице хранится **хеш** (и `plain_prefix`), а не тот секрет, который надо класть в `token.txt`.  
Старый plaintext из БД **не восстановить**. Нужен **новый** токен.

## Рабочий способ (обязательно)

1. Открой: https://you.1tlt.ru/admin/api-tokens  
2. Войди в аккаунт YouPub  
3. Создай токен (permission `autoview` / для AutoView)  
4. Скопируй показанную строку **сразу** (потом не покажут)  
5. Впиши в `C:\bots\viewer\token.txt` **одной строкой**, без пробелов  
6. Проверка:

```powershell
$token = (Get-Content C:\bots\viewer\token.txt -Raw).Trim()
Invoke-RestMethod -Uri "https://you.1tlt.ru/api/autoview/urls?limit=1&worker_id=test" -Headers @{ Authorization = "Bearer $token" }
```

Ожидание: JSON (массив URL или `[]`), не 401.

7. Запусти `YouTube_Shorts_AutoView.au3`

## Опционально: вставить свой секрет через MySQL

Только если бэкенд YouPub сверяет `hash('sha256', plaintext)`.  
На VPS:

```sql
INSERT INTO youpub.api_tokens
  (name, token, plain_prefix, permissions, user_id, is_active, created_at)
VALUES
  (
    'Win10 Bot',
    '42378d6bf04d05ccffa21ed7c247980700f35cdd600e6c40ca29458f9b57b90a',
    'ypub_win',
    'autoview',
    1,
    1,
    NOW()
  );
```

Тогда в `token.txt`:

```
ypub_win_a7c3e91f2b4d6800c1e5f9a2d3b4768e0f1a2b3c
```

Если после INSERT всё равно 401 — хеш у YouPub другой (HMAC/app key). Тогда **только** UI `/admin/api-tokens`.
