<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_once dirname(__DIR__) . '/lib/layout.php';
auth_start($config);
auth_require();

$user = auth_user();

if (is_post()) {
    csrf_verify();
    $action = (string) ($_POST['action'] ?? '');

    if ($action === 'save_settings') {
        setting_set($pdo, 'site_name', trim((string) ($_POST['site_name'] ?? 'YouPub View')));
        setting_set($pdo, 'default_watch_time', (string) max(0, (int) ($_POST['default_watch_time'] ?? 30)));
        setting_set($pdo, 'default_priority', (string) (int) ($_POST['default_priority'] ?? 0));
        setting_set($pdo, 'stuck_processing_minutes', (string) max(5, (int) ($_POST['stuck_processing_minutes'] ?? 30)));
        flash_set('ok', 'Настройки сохранены');
        redirect('/settings.php');
    }

    if ($action === 'change_password') {
        $current = (string) ($_POST['current_password'] ?? '');
        $new = (string) ($_POST['new_password'] ?? '');
        $confirm = (string) ($_POST['confirm_password'] ?? '');
        if ($new !== $confirm) {
            flash_set('err', 'Новый пароль и подтверждение не совпадают');
        } elseif (strlen($new) < 8) {
            flash_set('err', 'Пароль должен быть не короче 8 символов');
        } elseif (!auth_change_password($pdo, (int) $user['id'], $current, $new)) {
            flash_set('err', 'Текущий пароль неверен');
        } else {
            flash_set('ok', 'Пароль изменён');
        }
        redirect('/settings.php');
    }
}

$settings = settings_all($pdo);

render_header('Настройки', 'settings');
?>
<section class="panel">
  <h2 style="margin-top:0;font-size:1.05rem">Параметры сайта</h2>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="save_settings">
    <div class="field">
      <label>Название</label>
      <input type="text" name="site_name" value="<?= e($settings['site_name'] ?? ($config['app']['name'] ?? 'YouPub View')) ?>">
    </div>
    <div class="grid grid-2">
      <div class="field">
        <label>Default watch time (сек)</label>
        <input type="number" name="default_watch_time" min="0" value="<?= e($settings['default_watch_time'] ?? '30') ?>">
      </div>
      <div class="field">
        <label>Default priority</label>
        <input type="number" name="default_priority" value="<?= e($settings['default_priority'] ?? '0') ?>">
      </div>
    </div>
    <div class="field">
      <label>Считать processing «застрявшим» после (мин)</label>
      <input type="number" name="stuck_processing_minutes" min="5" value="<?= e($settings['stuck_processing_minutes'] ?? '30') ?>">
    </div>
    <button class="primary" type="submit">Сохранить</button>
  </form>
</section>

<section class="panel" style="margin-top:16px">
  <h2 style="margin-top:0;font-size:1.05rem">Смена пароля админа</h2>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="change_password">
    <div class="field">
      <label>Текущий пароль</label>
      <input type="password" name="current_password" required>
    </div>
    <div class="field">
      <label>Новый пароль</label>
      <input type="password" name="new_password" required minlength="8">
    </div>
    <div class="field">
      <label>Подтверждение</label>
      <input type="password" name="confirm_password" required minlength="8">
    </div>
    <button class="primary" type="submit">Сменить пароль</button>
  </form>
</section>

<section class="panel" style="margin-top:16px">
  <h2 style="margin-top:0;font-size:1.05rem">Инфо</h2>
  <p class="muted">Пользователь: <strong><?= e($user['username'] ?? '') ?></strong></p>
  <p class="muted">Base URL: <code><?= e($config['app']['base_url'] ?? '') ?></code></p>
  <p class="muted">PHP: <?= e(PHP_VERSION) ?></p>
  <p class="muted">Документация деплоя: <code>deploy/DEPLOY.md</code></p>
</section>
<?php render_footer(); ?>
