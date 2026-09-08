<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_once dirname(__DIR__) . '/lib/layout.php';
auth_start($config);
auth_require();

$defaultWatch = (int) (setting_get($pdo, 'default_watch_time', (string) ($config['app']['default_watch_time'] ?? 30)) ?: 30);
$defaultPriority = (int) (setting_get($pdo, 'default_priority', (string) ($config['app']['default_priority'] ?? 0)) ?: 0);
$perPage = (int) ($config['app']['urls_per_page'] ?? 50);

if (is_post()) {
    csrf_verify();
    $action = (string) ($_POST['action'] ?? '');

    if ($action === 'add_one') {
        $url = trim((string) ($_POST['url'] ?? ''));
        $watch = (int) ($_POST['target_watch_time'] ?? $defaultWatch);
        $priority = (int) ($_POST['priority'] ?? $defaultPriority);
        $note = trim((string) ($_POST['note'] ?? ''));
        if ($url === '' || !filter_var($url, FILTER_VALIDATE_URL)) {
            flash_set('err', 'Некорректный URL');
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO urls (url, target_watch_time, priority, note, status) VALUES (?, ?, ?, ?, \'pending\')'
            );
            $stmt->execute([$url, max(0, $watch), $priority, $note !== '' ? $note : null]);
            flash_set('ok', 'URL добавлен #' . $pdo->lastInsertId());
        }
        redirect('/urls.php');
    }

    if ($action === 'add_bulk') {
        $raw = (string) ($_POST['bulk'] ?? '');
        $watch = (int) ($_POST['target_watch_time'] ?? $defaultWatch);
        $priority = (int) ($_POST['priority'] ?? $defaultPriority);
        $lines = preg_split('/\r\n|\r|\n/', $raw) ?: [];
        $stmt = $pdo->prepare(
            'INSERT INTO urls (url, target_watch_time, priority, status) VALUES (?, ?, ?, \'pending\')'
        );
        $added = 0;
        foreach ($lines as $line) {
            $url = trim($line);
            if ($url === '' || str_starts_with($url, '#')) {
                continue;
            }
            if (!filter_var($url, FILTER_VALIDATE_URL)) {
                continue;
            }
            $stmt->execute([$url, max(0, $watch), $priority]);
            $added++;
        }
        flash_set('ok', "Добавлено URL: {$added}");
        redirect('/urls.php');
    }

    if ($action === 'requeue') {
        $id = (int) ($_POST['id'] ?? 0);
        $pdo->prepare(
            "UPDATE urls SET status='pending', worker_id=NULL, error_message=NULL,
             processing_at=NULL, viewed_at=NULL, watch_time=0 WHERE id=?"
        )->execute([$id]);
        flash_set('ok', "URL #{$id} возвращён в pending");
        redirect('/urls.php?' . http_build_query(array_filter([
            'status' => $_GET['status'] ?? null,
            'q' => $_GET['q'] ?? null,
        ])));
    }

    if ($action === 'delete') {
        $id = (int) ($_POST['id'] ?? 0);
        $pdo->prepare('DELETE FROM urls WHERE id=?')->execute([$id]);
        flash_set('ok', "URL #{$id} удалён");
        redirect('/urls.php');
    }

    if ($action === 'reset_stuck') {
        $minutes = (int) (setting_get($pdo, 'stuck_processing_minutes', '30') ?: 30);
        $stmt = $pdo->prepare(
            "UPDATE urls SET status='pending', worker_id=NULL, processing_at=NULL
             WHERE status='processing' AND processing_at IS NOT NULL
             AND processing_at < (NOW() - INTERVAL ? MINUTE)"
        );
        $stmt->execute([$minutes]);
        flash_set('ok', 'Сброшено застрявших: ' . $stmt->rowCount());
        redirect('/urls.php');
    }
}

$status = (string) ($_GET['status'] ?? '');
$q = trim((string) ($_GET['q'] ?? ''));
$page = max(1, (int) ($_GET['page'] ?? 1));
$where = [];
$params = [];
if (in_array($status, ['pending', 'processing', 'done', 'error'], true)) {
    $where[] = 'status = ?';
    $params[] = $status;
}
if ($q !== '') {
    $where[] = '(url LIKE ? OR worker_id LIKE ? OR CAST(id AS CHAR) = ?)';
    $params[] = '%' . $q . '%';
    $params[] = '%' . $q . '%';
    $params[] = $q;
}
$sqlWhere = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

$countStmt = $pdo->prepare("SELECT COUNT(*) FROM urls {$sqlWhere}");
$countStmt->execute($params);
$total = (int) $countStmt->fetchColumn();
$pages = max(1, (int) ceil($total / $perPage));
$offset = ($page - 1) * $perPage;

$listStmt = $pdo->prepare(
    "SELECT * FROM urls {$sqlWhere} ORDER BY id DESC LIMIT {$perPage} OFFSET {$offset}"
);
$listStmt->execute($params);
$rows = $listStmt->fetchAll();

render_header('URL / очередь', 'urls');
?>
<section class="panel">
  <h2 style="margin-top:0;font-size:1.05rem">Добавить URL</h2>
  <form method="post" class="grid grid-2">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="add_one">
    <div class="field" style="grid-column:1 / -1">
      <label>YouTube URL</label>
      <input type="text" name="url" placeholder="https://www.youtube.com/watch?v=... или /shorts/..." required>
    </div>
    <div class="field">
      <label>target_watch_time (сек, 0 = worker решает)</label>
      <input type="number" name="target_watch_time" value="<?= $defaultWatch ?>" min="0">
    </div>
    <div class="field">
      <label>priority</label>
      <input type="number" name="priority" value="<?= $defaultPriority ?>">
    </div>
    <div class="field" style="grid-column:1 / -1">
      <label>Заметка (опционально)</label>
      <input type="text" name="note" maxlength="255">
    </div>
    <div><button class="primary" type="submit">Добавить</button></div>
  </form>
</section>

<section class="panel" style="margin-top:16px">
  <h2 style="margin-top:0;font-size:1.05rem">Массовое добавление</h2>
  <form method="post">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="add_bulk">
    <div class="field">
      <label>По одному URL на строку</label>
      <textarea name="bulk" placeholder="https://youtube.com/shorts/..."></textarea>
    </div>
    <div class="grid grid-2">
      <div class="field">
        <label>target_watch_time</label>
        <input type="number" name="target_watch_time" value="<?= $defaultWatch ?>" min="0">
      </div>
      <div class="field">
        <label>priority</label>
        <input type="number" name="priority" value="<?= $defaultPriority ?>">
      </div>
    </div>
    <button class="primary" type="submit">Импортировать</button>
  </form>
</section>

<div class="row-actions" style="margin-top:18px">
  <form method="post" class="inline">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="reset_stuck">
    <button type="submit">Сбросить застрявшие processing</button>
  </form>
</div>

<form class="filters" method="get">
  <div class="field">
    <label>Статус</label>
    <select name="status">
      <option value="">все</option>
      <?php foreach (['pending','processing','done','error'] as $s): ?>
        <option value="<?= $s ?>" <?= $status === $s ? 'selected' : '' ?>><?= $s ?></option>
      <?php endforeach; ?>
    </select>
  </div>
  <div class="field" style="min-width:220px">
    <label>Поиск</label>
    <input type="text" name="q" value="<?= e($q) ?>" placeholder="url / worker / id">
  </div>
  <button type="submit">Фильтр</button>
</form>

<div class="muted" style="margin-bottom:8px">Найдено: <?= $total ?></div>
<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>ID</th><th>URL</th><th>Статус</th><th>Watch</th><th>Priority</th><th>Worker</th><th>Ошибка</th><th></th>
      </tr>
    </thead>
    <tbody>
    <?php foreach ($rows as $row): ?>
      <tr>
        <td><?= (int) $row['id'] ?></td>
        <td class="mono truncate" title="<?= e($row['url']) ?>"><?= e($row['url']) ?></td>
        <td><?= status_badge($row['status']) ?></td>
        <td><?= (int) $row['watch_time'] ?> / <?= (int) $row['target_watch_time'] ?></td>
        <td><?= (int) $row['priority'] ?></td>
        <td class="mono"><?= e((string) $row['worker_id']) ?></td>
        <td class="truncate" title="<?= e((string) $row['error_message']) ?>"><?= e((string) $row['error_message']) ?></td>
        <td class="actions">
          <form method="post" class="inline">
            <?= csrf_field() ?>
            <input type="hidden" name="action" value="requeue">
            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
            <button class="btn-sm" type="submit">requeue</button>
          </form>
          <form method="post" class="inline" onsubmit="return confirm('Удалить #<?= (int) $row['id'] ?>?')">
            <?= csrf_field() ?>
            <input type="hidden" name="action" value="delete">
            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
            <button class="btn-sm btn-danger" type="submit">del</button>
          </form>
        </td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$rows): ?><tr><td colspan="8" class="muted">Нет записей</td></tr><?php endif; ?>
    </tbody>
  </table>
</div>

<div class="pager">
  <?php if ($page > 1): ?>
    <a class="btn" href="?<?= e(http_build_query(['status'=>$status,'q'=>$q,'page'=>$page-1])) ?>">← prev</a>
  <?php endif; ?>
  <span class="muted">стр. <?= $page ?> / <?= $pages ?></span>
  <?php if ($page < $pages): ?>
    <a class="btn" href="?<?= e(http_build_query(['status'=>$status,'q'=>$q,'page'=>$page+1])) ?>">next →</a>
  <?php endif; ?>
</div>
<?php render_footer(); ?>
