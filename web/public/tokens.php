<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_once dirname(__DIR__) . '/lib/layout.php';
auth_start($config);
auth_require();

$createdToken = null;

if (is_post()) {
    csrf_verify();
    $action = (string) ($_POST['action'] ?? '');

    if ($action === 'create') {
        $desc = trim((string) ($_POST['description'] ?? ''));
        $token = generate_api_token();
        $pdo->prepare('INSERT INTO api_tokens (token, description, is_active) VALUES (?, ?, 1)')
            ->execute([$token, $desc]);
        $createdToken = $token;
        flash_set('ok', 'Токен создан. Скопируйте его сейчас — повторно целиком не показывается.');
    }

    if ($action === 'toggle') {
        $id = (int) ($_POST['id'] ?? 0);
        $pdo->prepare('UPDATE api_tokens SET is_active = IF(is_active=1,0,1) WHERE id=?')->execute([$id]);
        flash_set('ok', "Токен #{$id} переключён");
        redirect('/tokens.php');
    }

    if ($action === 'delete') {
        $id = (int) ($_POST['id'] ?? 0);
        $pdo->prepare('DELETE FROM api_tokens WHERE id=?')->execute([$id]);
        flash_set('ok', "Токен #{$id} удалён");
        redirect('/tokens.php');
    }
}

$rows = $pdo->query('SELECT * FROM api_tokens ORDER BY id DESC')->fetchAll();

render_header('API-токены', 'tokens');
?>
<?php if ($createdToken): ?>
  <div class="flash flash-ok">
    Новый токен (сохраните в `.env` worker как <code>WORKER_TOKEN</code>):
    <div class="mono" style="margin-top:8px;word-break:break-all"><?= e($createdToken) ?></div>
  </div>
<?php endif; ?>

<section class="panel">
  <h2 style="margin-top:0;font-size:1.05rem">Создать токен</h2>
  <form method="post" class="grid grid-2">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="create">
    <div class="field" style="grid-column:1 / -1">
      <label>Описание (worker / VPS)</label>
      <input type="text" name="description" placeholder="worker-istanbul-01" required>
    </div>
    <div><button class="primary" type="submit">Создать</button></div>
  </form>
</section>

<div class="table-wrap" style="margin-top:16px">
  <table>
    <thead>
      <tr><th>ID</th><th>Токен</th><th>Описание</th><th>Активен</th><th>Создан</th><th>Last used</th><th></th></tr>
    </thead>
    <tbody>
    <?php foreach ($rows as $row): ?>
      <tr>
        <td><?= (int) $row['id'] ?></td>
        <td class="mono"><?= e(substr($row['token'], 0, 8) . '…' . substr($row['token'], -4)) ?></td>
        <td><?= e($row['description']) ?></td>
        <td><?= ((int) $row['is_active'] === 1) ? 'yes' : 'no' ?></td>
        <td><?= e($row['created_at']) ?></td>
        <td><?= e((string) ($row['last_used_at'] ?? '—')) ?></td>
        <td class="actions">
          <form method="post" class="inline">
            <?= csrf_field() ?>
            <input type="hidden" name="action" value="toggle">
            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
            <button class="btn-sm" type="submit">on/off</button>
          </form>
          <form method="post" class="inline" onsubmit="return confirm('Удалить токен?')">
            <?= csrf_field() ?>
            <input type="hidden" name="action" value="delete">
            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
            <button class="btn-sm btn-danger" type="submit">del</button>
          </form>
        </td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$rows): ?><tr><td colspan="7" class="muted">Токенов нет</td></tr><?php endif; ?>
    </tbody>
  </table>
</div>

<section class="panel" style="margin-top:16px">
  <h2 style="margin-top:0;font-size:1.05rem">Эндпоинты для worker</h2>
  <p class="mono">GET  <?= e(($config['app']['base_url'] ?? '') . '/api/autoview/urls') ?></p>
  <p class="mono">POST <?= e(($config['app']['base_url'] ?? '') . '/api/autoview/status') ?></p>
  <p class="muted">Header: <code>Authorization: Bearer &lt;token&gt;</code></p>
</section>
<?php render_footer(); ?>
