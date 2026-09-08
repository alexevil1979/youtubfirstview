<?php
declare(strict_types=1);

function render_header(string $title, string $active = ''): void
{
    global $config;
    $user = auth_user();
    $appName = setting_get($GLOBALS['pdo'], 'site_name', $config['app']['name'] ?? 'YouPub View');
    $flashes = flash_get();
    ?>
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= e($title) ?> · <?= e($appName) ?></title>
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body>
  <div class="shell">
    <aside class="sidebar">
      <div class="brand"><?= e($appName) ?></div>
      <nav>
        <a class="<?= $active === 'dashboard' ? 'active' : '' ?>" href="/dashboard.php">Дашборд</a>
        <a class="<?= $active === 'urls' ? 'active' : '' ?>" href="/urls.php">URL / очередь</a>
        <a class="<?= $active === 'tokens' ? 'active' : '' ?>" href="/tokens.php">API-токены</a>
        <a class="<?= $active === 'logs' ? 'active' : '' ?>" href="/logs.php">Логи</a>
        <a class="<?= $active === 'settings' ? 'active' : '' ?>" href="/settings.php">Настройки</a>
      </nav>
      <div class="sidebar-foot">
        <div class="muted"><?= e($user['username'] ?? '') ?></div>
        <a href="/logout.php">Выйти</a>
      </div>
    </aside>
    <main class="content">
      <header class="page-head">
        <h1><?= e($title) ?></h1>
      </header>
      <?php foreach ($flashes as $flash): ?>
        <div class="flash flash-<?= e($flash['type']) ?>"><?= e($flash['message']) ?></div>
      <?php endforeach; ?>
<?php
}

function render_footer(): void
{
    ?>
    </main>
  </div>
</body>
</html>
<?php
}
