<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_once dirname(__DIR__) . '/lib/layout.php';
auth_start($config);
auth_require();

$counts = [
    'pending' => (int) $pdo->query("SELECT COUNT(*) FROM urls WHERE status='pending'")->fetchColumn(),
    'processing' => (int) $pdo->query("SELECT COUNT(*) FROM urls WHERE status='processing'")->fetchColumn(),
    'done' => (int) $pdo->query("SELECT COUNT(*) FROM urls WHERE status='done'")->fetchColumn(),
    'error' => (int) $pdo->query("SELECT COUNT(*) FROM urls WHERE status='error'")->fetchColumn(),
];
$tokensActive = (int) $pdo->query('SELECT COUNT(*) FROM api_tokens WHERE is_active=1')->fetchColumn();
$logsToday = (int) $pdo->query('SELECT COUNT(*) FROM view_log WHERE created_at >= CURDATE()')->fetchColumn();

$stuckMinutes = (int) (setting_get($pdo, 'stuck_processing_minutes', '30') ?: 30);
$stuckStmt = $pdo->prepare(
    "SELECT COUNT(*) FROM urls WHERE status='processing' AND processing_at IS NOT NULL
     AND processing_at < (NOW() - INTERVAL ? MINUTE)"
);
$stuckStmt->execute([$stuckMinutes]);
$stuck = (int) $stuckStmt->fetchColumn();

$recent = $pdo->query(
    'SELECT id, url, status, worker_id, watch_time, created_at, viewed_at
     FROM urls ORDER BY id DESC LIMIT 12'
)->fetchAll();

$workers = $pdo->query(
    "SELECT worker_id, MAX(created_at) AS last_seen, COUNT(*) AS events
     FROM view_log
     WHERE created_at > (NOW() - INTERVAL 7 DAY)
     GROUP BY worker_id
     ORDER BY last_seen DESC
     LIMIT 10"
)->fetchAll();

render_header('Дашборд', 'dashboard');
?>
<div class="grid grid-4">
  <div class="stat"><div class="label">Pending</div><div class="value"><?= $counts['pending'] ?></div></div>
  <div class="stat"><div class="label">Processing</div><div class="value"><?= $counts['processing'] ?></div></div>
  <div class="stat"><div class="label">Done</div><div class="value"><?= $counts['done'] ?></div></div>
  <div class="stat"><div class="label">Error</div><div class="value"><?= $counts['error'] ?></div></div>
</div>

<div class="grid grid-2" style="margin-top:16px">
  <div class="stat"><div class="label">Активные API-токены</div><div class="value"><?= $tokensActive ?></div></div>
  <div class="stat"><div class="label">События логов сегодня</div><div class="value"><?= $logsToday ?></div></div>
</div>

<?php if ($stuck > 0): ?>
  <div class="flash flash-warn" style="margin-top:16px">
    Застряло в processing: <?= $stuck ?> (старше <?= (int) $stuckMinutes ?> мин).
    Можно сбросить на странице URL.
  </div>
<?php endif; ?>

<div class="grid grid-2" style="margin-top:20px">
  <section class="panel">
    <h2 style="margin-top:0;font-size:1.05rem">Последние URL</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>ID</th><th>URL</th><th>Статус</th><th>Worker</th></tr></thead>
        <tbody>
        <?php foreach ($recent as $row): ?>
          <tr>
            <td><?= (int) $row['id'] ?></td>
            <td class="mono truncate" title="<?= e($row['url']) ?>"><?= e($row['url']) ?></td>
            <td><?= status_badge($row['status']) ?></td>
            <td class="mono"><?= e((string) $row['worker_id']) ?></td>
          </tr>
        <?php endforeach; ?>
        <?php if (!$recent): ?><tr><td colspan="4" class="muted">Пока пусто</td></tr><?php endif; ?>
        </tbody>
      </table>
    </div>
  </section>

  <section class="panel">
    <h2 style="margin-top:0;font-size:1.05rem">Workers (7 дней)</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Worker</th><th>Последняя активность</th><th>События</th></tr></thead>
        <tbody>
        <?php foreach ($workers as $w): ?>
          <tr>
            <td class="mono"><?= e($w['worker_id']) ?></td>
            <td><?= e($w['last_seen']) ?></td>
            <td><?= (int) $w['events'] ?></td>
          </tr>
        <?php endforeach; ?>
        <?php if (!$workers): ?><tr><td colspan="3" class="muted">Нет активности</td></tr><?php endif; ?>
        </tbody>
      </table>
    </div>
  </section>
</div>
<?php render_footer(); ?>
