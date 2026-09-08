# Deploy guide — YouPub View on Ubuntu VPS

Домен: **youtubview.1tlt.ru**  
Корень сайта: **/ssd/www/youpubview**  
DocumentRoot: **/ssd/www/youpubview/public**  
Стек: Apache 2.4 + PHP 8.2 + MySQL 5.7 + Let's Encrypt (certbot)

Также на том же VPS можно поставить Ubuntu QA worker (`worker/`) — см. конец файла.

---

## 0. DNS

Создайте A-запись:

```
youtubview.1tlt.ru  →  <IP_VPS>
```

Проверка: `dig +short youtubview.1tlt.ru`

---

## 1. Пакеты (Ubuntu 22.04)

```bash
sudo apt update
sudo apt install -y apache2 mysql-server \
  software-properties-common curl rsync unzip git

# PHP 8.2
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql \
  php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip libapache2-mod-php8.2

sudo a2enmod rewrite headers ssl
sudo systemctl enable --now apache2
```

Если MySQL 5.7 уже стоит отдельно — используйте её, модуль `php8.2-mysql` совместим.

---

## 2. Каталог и код

```bash
sudo mkdir -p /ssd/www/youpubview
sudo chown -R $USER:www-data /ssd/www

# Клонируйте репозиторий куда удобно, затем:
cd /path/to/repo
sudo bash deploy/install-web.sh
# или вручную:
# sudo rsync -a --exclude config.php web/ /ssd/www/youpubview/
```

Структура:

```
/ssd/www/youpubview/
├── config.php              # секреты (не в git)
├── config.example.php
├── lib/
├── sql/schema.sql
└── public/                 # DocumentRoot
    ├── index.php
    ├── dashboard.php
    ├── urls.php
    ├── tokens.php
    ├── logs.php
    ├── settings.php
    ├── assets/
    └── api/autoview/
```

---

## 3. MySQL

```bash
sudo mysql
```

```sql
CREATE DATABASE IF NOT EXISTS youpubview
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'youpubview'@'localhost'
  IDENTIFIED BY 'STRONG_DB_PASSWORD_HERE';

GRANT ALL PRIVILEGES ON youpubview.* TO 'youpubview'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Импорт схемы:

```bash
mysql -u youpubview -p youpubview < /ssd/www/youpubview/sql/schema.sql
```

Конфиг:

```bash
sudo nano /ssd/www/youpubview/config.php
```

Заполните `db.pass`, при необходимости `db.user` / `db.name`.  
`base_url` = `https://youtubview.1tlt.ru`

```bash
sudo chown www-data:www-data /ssd/www/youpubview/config.php
sudo chmod 640 /ssd/www/youpubview/config.php
```

---

## 4. Apache vhost

```bash
sudo cp /path/to/repo/deploy/apache-youtubview.1tlt.ru.conf \
  /etc/apache2/sites-available/youtubview.1tlt.ru.conf

sudo a2ensite youtubview.1tlt.ru.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

Проверка HTTP:

```bash
curl -I http://youtubview.1tlt.ru/
```

---

## 5. SSL (certbot)

```bash
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache -d youtubview.1tlt.ru
```

Certbot сам добавит SSL vhost и редирект HTTP→HTTPS.  
Автообновление: `systemctl status certbot.timer`

Проверка:

```bash
curl -I https://youtubview.1tlt.ru/
```

---

## 6. Первый вход в админку

URL: https://youtubview.1tlt.ru/login.php

| Поле | Значение |
|------|----------|
| Логин | `admin` |
| Пароль | `ChangeMeNow!` |

Сразу: **Настройки → смена пароля**.

Дальше:

1. **API-токены** → создать токен для worker  
2. **URL / очередь** → добавить видео  
3. Смотреть **Дашборд** и **Логи**

---

## 7. API для worker

```
GET  https://youtubview.1tlt.ru/api/autoview/urls?limit=5&worker_id=worker-01
POST https://youtubview.1tlt.ru/api/autoview/status
Authorization: Bearer <token>
```

Статус — `application/x-www-form-urlencoded`:

- `url_id`, `status` (`done`|`error`), `watch_time`, `worker_id`, `error` (опц.)

Тест:

```bash
TOKEN=your_token_here
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://youtubview.1tlt.ru/api/autoview/urls?limit=1&worker_id=curl-test"
```

---

## 8. Worker на том же VPS (опционально)

```bash
cd /path/to/repo/worker
sudo ./install.sh
sudo nano /opt/youtube-qa-worker/.env
```

```env
SERVER_API_URL=https://youtubview.1tlt.ru
WORKER_TOKEN=<токен из админки>
WORKER_ID=worker-vps-01
API_MODE=youpub
HEALTH_HOST=127.0.0.1
HEALTH_PORT=8080
```

```bash
sudo systemctl restart youtube-qa-worker
curl http://127.0.0.1:8080/health
```

Health worker наружу не открывайте (только localhost / firewall).

---

## 9. Права и безопасность

```bash
sudo chown -R www-data:www-data /ssd/www/youpubview
sudo find /ssd/www/youpubview -type d -exec chmod 755 {} \;
sudo find /ssd/www/youpubview -type f -exec chmod 644 {} \;
sudo chmod 640 /ssd/www/youpubview/config.php
```

- `config.php` не коммитить  
- Админку только по HTTPS  
- Сменить пароль `admin`  
- Токены worker — отдельные, с описанием VPS  
- Firewall: `80,443` открыты; MySQL и `:8080` worker — только localhost

---

## 10. Обновление с git

```bash
cd /path/to/repo
git pull
sudo bash deploy/install-web.sh
# config.php не затирается
sudo systemctl reload apache2
```

Worker:

```bash
cd /path/to/repo/worker
# обновить файлы в /opt/youtube-qa-worker (см. worker/install.sh)
sudo systemctl restart youtube-qa-worker
```

---

## 11. Чеклист приёмки

- [ ] `https://youtubview.1tlt.ru/login.php` открывается, сертификат валиден  
- [ ] Логин admin / смена пароля работает  
- [ ] Создан API-токен  
- [ ] Добавлен тестовый URL  
- [ ] `curl` к `/api/autoview/urls` с Bearer возвращает JSON  
- [ ] Worker (если есть) пишет в Логи и меняет статус URL  
- [ ] `journalctl -u youtube-qa-worker` без ошибок (если worker на этом VPS)

---

## Что есть в веб-морде

| Раздел | Зачем |
|--------|--------|
| Дашборд | Счётчики очереди, stuck processing, workers |
| URL / очередь | Добавление (одиночное/bulk), фильтры, requeue, delete |
| API-токены | Выдача Bearer для Ubuntu/Windows workers |
| Логи | `view_log` с фильтром по worker/action |
| Настройки | Имя, defaults, порог stuck, смена пароля |
