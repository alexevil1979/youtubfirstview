<?php
/**
 * status.php — Приём статуса просмотра URL
 * 
 * POST параметры:
 *   url_id     — ID просмотренного URL
 *   status     — статус (done, error)
 *   watch_time — время просмотра в секундах
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

// Получаем данные
$url_id = isset($_POST['url_id']) ? intval($_POST['url_id']) : 0;
$status = isset($_POST['status']) ? $_POST['status'] : '';
$watch_time = isset($_POST['watch_time']) ? intval($_POST['watch_time']) : 0;

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

// Обновляем статус в БД
$stmt = $pdo->prepare("
    UPDATE urls 
    SET status = :status, 
        watch_time = :watch_time, 
        viewed_at = NOW() 
    WHERE id = :url_id
");

$stmt->execute([
    ':status' => $status,
    ':watch_time' => $watch_time,
    ':url_id' => $url_id
]);

if ($stmt->rowCount() > 0) {
    echo json_encode(['success' => true, 'message' => 'Status updated']);
} else {
    http_response_code(404);
    echo json_encode(['error' => 'URL not found']);
}
