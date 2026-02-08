<?php
/**
 * /api/autoview/status — Приём статуса просмотра URL (YouPub API v2.0)
 *
 * POST параметры:
 *   url_id     — ID просмотренного URL
 *   status     — статус: done | error
 *   watch_time — время просмотра в секундах
 *   worker_id  — идентификатор бота
 *   error      — (опционально) описание ошибки
 *
 * Заголовки:
 *   Authorization: Bearer <token>
 *
 * Формат ответа (JSON):
 * {"success": true, "message": "Status updated"}
 */

header('Content-Type: application/json; charset=utf-8');

// Принимаем только POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// === Авторизация по Bearer-токену ===
$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$token = '';

if (preg_match('/^Bearer\s+(.+)$/i', $authHeader, $matches)) {
    $token = $matches[1];
}

if (empty($token)) {
    http_response_code(401);
    echo json_encode(['error' => 'Authorization token required']);
    exit;
}

// Подключение к БД
$db_host = 'localhost';
$db_name = 'youtube_views';
$db_user = 'root';
$db_pass = '';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name;charset=utf8mb4", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit;
}

// Проверяем токен
$stmtToken = $pdo->prepare("SELECT id, is_active FROM api_tokens WHERE token = :token LIMIT 1");
$stmtToken->execute([':token' => $token]);
$tokenRow = $stmtToken->fetch(PDO::FETCH_ASSOC);

if (!$tokenRow || !$tokenRow['is_active']) {
    http_response_code(401);
    echo json_encode(['error' => 'Invalid or expired token']);
    exit;
}

// Получаем данные
$url_id = isset($_POST['url_id']) ? intval($_POST['url_id']) : 0;
$status = isset($_POST['status']) ? $_POST['status'] : '';
$watch_time = isset($_POST['watch_time']) ? intval($_POST['watch_time']) : 0;
$worker_id = isset($_POST['worker_id']) ? $_POST['worker_id'] : 'unknown';
$error_msg = isset($_POST['error']) ? $_POST['error'] : '';

// Валидация
if ($url_id <= 0) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid url_id']);
    exit;
}

if (!in_array($status, ['done', 'error'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid status. Must be "done" or "error"']);
    exit;
}

// Обновляем статус URL в БД
$stmt = $pdo->prepare("
    UPDATE urls
    SET status = :status,
        watch_time = :watch_time,
        worker_id = :worker_id,
        error_message = :error_msg,
        viewed_at = NOW()
    WHERE id = :url_id
");

$stmt->execute([
    ':status' => $status,
    ':watch_time' => $watch_time,
    ':worker_id' => $worker_id,
    ':error_msg' => $error_msg,
    ':url_id' => $url_id
]);

// Логируем действие
$logStmt = $pdo->prepare("
    INSERT INTO view_log (worker_id, action, details, created_at)
    VALUES (:worker_id, :action, :details, NOW())
");
$logStmt->execute([
    ':worker_id' => $worker_id,
    ':action' => 'status_' . $status,
    ':details' => json_encode([
        'url_id' => $url_id,
        'watch_time' => $watch_time,
        'error' => $error_msg
    ])
]);

if ($stmt->rowCount() > 0) {
    echo json_encode(['success' => true, 'message' => 'Status updated']);
} else {
    http_response_code(404);
    echo json_encode(['error' => 'URL not found or already processed']);
}
