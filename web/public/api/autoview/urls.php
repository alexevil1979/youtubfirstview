<?php
declare(strict_types=1);

/**
 * GET /api/autoview/urls
 */
require_once dirname(__DIR__, 3) . '/lib/bootstrap.php';
require_once dirname(__DIR__, 3) . '/lib/api_auth.php';

api_require_token($pdo);

$limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 5;
$limit = min(max($limit, 1), 20);
$workerId = isset($_GET['worker_id']) ? (string) $_GET['worker_id'] : 'unknown';

$stmt = $pdo->prepare(
    "SELECT id, url, target_watch_time
     FROM urls
     WHERE status = 'pending'
     ORDER BY priority DESC, created_at ASC
     LIMIT ?"
);
$stmt->bindValue(1, $limit, PDO::PARAM_INT);
$stmt->execute();
$urls = $stmt->fetchAll();

foreach ($urls as &$row) {
    $row['id'] = (int) $row['id'];
    $row['target_watch_time'] = (int) ($row['target_watch_time'] ?? 0);
}
unset($row);

if ($urls) {
    $ids = array_column($urls, 'id');
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $params = array_merge([$workerId], $ids);
    $update = $pdo->prepare(
        "UPDATE urls SET status = 'processing', worker_id = ?, processing_at = NOW()
         WHERE id IN ($placeholders)"
    );
    $update->execute($params);

    $log = $pdo->prepare(
        'INSERT INTO view_log (worker_id, action, details, created_at) VALUES (?, ?, ?, NOW())'
    );
    $log->execute([
        $workerId,
        'urls_assigned',
        json_encode(['count' => count($ids), 'ids' => $ids], JSON_UNESCAPED_UNICODE),
    ]);
}

json_response($urls);
