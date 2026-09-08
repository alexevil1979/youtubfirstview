<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
auth_start($config);

if (auth_check()) {
    redirect('/dashboard.php');
}

$error = '';
if (is_post()) {
    $username = trim((string) ($_POST['username'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');
    if (auth_login($pdo, $username, $password)) {
        redirect('/dashboard.php');
    }
    $error = 'Неверный логин или пароль';
}

$appName = setting_get($pdo, 'site_name', $config['app']['name'] ?? 'YouPub View');
?>
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Вход · <?= e($appName) ?></title>
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body>
  <div class="login-wrap">
    <div class="login-card">
      <h1><?= e($appName) ?></h1>
      <p class="muted">Админка очереди и workers</p>
      <?php if ($error): ?><div class="flash flash-err"><?= e($error) ?></div><?php endif; ?>
      <form method="post">
        <div class="field">
          <label for="username">Логин</label>
          <input id="username" name="username" type="text" autocomplete="username" required value="admin">
        </div>
        <div class="field">
          <label for="password">Пароль</label>
          <input id="password" name="password" type="password" autocomplete="current-password" required>
        </div>
        <button class="primary" type="submit" style="width:100%">Войти</button>
      </form>
      <p class="muted" style="margin-top:16px">После установки смените пароль в Настройках.</p>
    </div>
  </div>
</body>
</html>
