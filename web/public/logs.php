<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_once dirname(__DIR__) . '/lib/layout.php';
auth_start($config);
auth_require();

$perPage = (int) ($config['app']['logs_per_page'] ?? 100);
$worker = trim((string) ($_GET['worker_id'] ?? ''));
$action = trim((string) ($_GET['action'] ?? ''));
$page = max(1, (int) ($_GET['page'] ?? 1));

$where = [];
$params = [];
if ($worker !== '') {
    $where[] = 'worker_id LIKE ?';
    $params[] = '%' . $worker . '%';
}
if ($action !== '') {
    $where[] = 'action = ?';
    $params[] = $action;
}
$sqlWhere = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

$countStmt = $pdo->prepare("SELECT COUNT(*) FROM view_log {$sqlWhere}");
$countStmt->execute($params);
$total = (int) $countStmt->fetchColumn();
$pages = max(1, (int) ceil($total / $perPage));
$offset = ($page - 1) * $perPage;

$listStmt = $pdo->prepare(
    "SELECT * FROM view_log {$sqlWhere} ORDER BY id DESC LIMIT {$perPage} OFFSET {$offset}"
);
$listStmt->execute($params);
$rows = $listStmt->fetchAll();

$actions = $pdo->query('SELECT DISTINCT action FROM view_log ORDER BY action')->fetchAll(PDO::FETCH_COLUMN);

render_header('Логи', 'logs');
?>
<form class="filters" method="get">
  <div class="field" style="min-width:200px">
    <label>worker_id</label>
    <input type="text" name="worker_id" value="<?= e($worker) ?>">
  </div>
  <div class="field">
    <label>action</label>
    <select name="action">
      <option value="">все</option>
      <?php foreach ($actions as $a): ?>
        <option value="<?= e((string) $a) ?>" <?= $action === $a ? 'selected' : '' ?>><?= e((string) $a) ?></option>
      <?php endforeach; ?>
    </select>
  </div>
  <button type="submit">Фильтр</button>
</form>

<div class="muted" style="margin-bottom:8px">Найдено: <?= $total ?></div>
<div class="table-wrap">
  <table>
    <thead><tr><th>ID</th><th>Время</th><th>Worker</th><th>Action</th><th>Details</th></tr></thead>
    <tbody>
    <?php foreach ($rows as $row): ?>
      <tr>
        <td><?= (int) $row['id'] ?></td>
        <td><?= e($row['created_at']) ?></td>
        <td class="mono"><?= e($row['worker_id']) ?></td>
        <td class="mono"><?= e($row['action']) ?></td>
        <td class="mono" style="max-width:520px;word-break:break-word"><?= e((string) $row['details']) ?></td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$rows): ?><tr><td colspan="5" class="muted">Логов нет</td></tr><?php endif; ?>
    </tbody>
  </table>
</div>

<div class="pager">
  <?php if ($page > 1): ?>
    <a class="btn" href="?<?= e(http_build_query(['worker_id'=>$worker,'action'=>$action,'page'=>$page-1])) ?>">← prev</a>
  <?php endif; ?>
  <span class="muted">стр. <?= $page ?> / <?= $pages ?></span>
  <?php if ($page < $pages): ?>
    <a class="btn" href="?<?= e(http_build_query(['worker_id'=>$worker,'action'=>$action,'page'=>$page+1])) ?>">next →</a>
  <?php endif; ?>
</div>
<?php render_footer(); ?>
