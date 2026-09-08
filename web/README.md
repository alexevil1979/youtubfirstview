# Web admin — YouPub View

PHP 8.2 админка и API для очереди YouTube URL.

- Публичный DocumentRoot: `public/`
- Конфиг: скопировать `config.example.php` → `config.php`
- Схема БД: `sql/schema.sql`
- Деплой: [`../deploy/DEPLOY.md`](../deploy/DEPLOY.md)

## Локально (кратко)

```bash
cp config.example.php config.php
# настроить DB
mysql -u ... < sql/schema.sql
# указать Apache/Nginx DocumentRoot на public/
```

Логин по умолчанию: `admin` / `ChangeMeNow!`
