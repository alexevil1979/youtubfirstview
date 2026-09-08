<?php
declare(strict_types=1);

/**
 * POST /api/autoview/status
 */
require_once dirname(__DIR__, 3) . '/lib/bootstrap.php';
require_once dirname(__DIR__, 3) . '/lib/api_auth.php';

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    json_response(['error' => 'Method not allowed'], 405);
}

api_require_token($pdo);

$urlId = isset($_POST['url_id']) ? (int) $_POST['url_id'] : 0;
$status = isset($_POST['status']) ? (string) $_POST['status'] : '';
$watchTime = isset($_POST['watch_time']) ? (int) $_POST['watch_time'] : 0;
$workerId = isset($_POST['worker_id']) ? (string) $_POST['worker_id'] : 'unknown';
$errorMsg = isset($_POST['error']) ? (string) $_POST['error'] : '';

if ($urlId <= 0) {
    json_response(['error' => 'Invalid url_id'], 400);
}
if (!in_array($status, ['done', 'error'], true)) {
    json_response(['error' => 'Invalid status. Must be "done" or "error"'], 400);
}

$stmt = $pdo->prepare(
    "UPDATE urls
     SET status = ?, watch_time = ?, worker_id = ?, error_message = ?, viewed_at = NOW()
     WHERE id = ?"
);
$stmt->execute([$status, $watchTime, $workerId, $errorMsg, $urlId]);

$log = $pdo->prepare(
    'INSERT INTO view_log (worker_id, action, details, created_at) VALUES (?, ?, ?, NOW())'
);
$log->execute([
    $workerId,
    'status_' . $status,
    json_encode([
        'url_id' => $urlId,
        'watch_time' => $watchTime,
        'error' => $errorMsg,
    ], JSON_UNESCAPED_UNICODE),
]);

if ($stmt->rowCount() > 0) {
    json_response(['success' => true, 'message' => 'Status updated']);
}

json_response(['error' => 'URL not found or already processed'], 404);
