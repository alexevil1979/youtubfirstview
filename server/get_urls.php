<?php
/**
 * /api/autoview/urls — Выдача URL'ов для просмотра (YouPub API v2.0)
 *
 * GET параметры:
 *   limit     — количество URL'ов (по умолчанию 5, максимум 20)
 *   worker_id — идентификатор бота (для учёта)
 *
 * Заголовки:
 *   Authorization: Bearer <token>
 *
 * Формат ответа (JSON):
 * [
 *   {"id": 1, "url": "https://youtube.com/shorts/xxx", "target_watch_time": 30},
 *   {"id": 2, "url": "https://youtube.com/shorts/yyy", "target_watch_time": 60}
 * ]
 */

header('Content-Type: application/json; charset=utf-8');

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

// Подключение к БД (настройте под себя)
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

// Проверяем токен в БД
$stmtToken = $pdo->prepare("SELECT id, is_active FROM api_tokens WHERE token = :token LIMIT 1");
$stmtToken->execute([':token' => $token]);
$tokenRow = $stmtToken->fetch(PDO::FETCH_ASSOC);

if (!$tokenRow || !$tokenRow['is_active']) {
    http_response_code(401);
    echo json_encode(['error' => 'Invalid or expired token']);
    exit;
}

// Получаем параметры
$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 5;
$limit = min(max($limit, 1), 20);
$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : 'unknown';

// Выбираем URL'ы со статусом 'pending'
$stmt = $pdo->prepare("
    SELECT id, url, target_watch_time
    FROM urls
    WHERE status = 'pending'
    ORDER BY priority DESC, created_at ASC
    LIMIT :limit
");
$stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
$stmt->execute();

$urls = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Приводим типы к числовым
foreach ($urls as &$row) {
    $row['id'] = (int) $row['id'];
    $row['target_watch_time'] = (int) ($row['target_watch_time'] ?? 0);
}
unset($row);

// Помечаем выданные URL как "processing" и записываем worker_id
if (!empty($urls)) {
    $ids = array_column($urls, 'id');
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $params = $ids;
    $params[] = $worker_id;

    $updateStmt = $pdo->prepare("
        UPDATE urls
        SET status = 'processing', worker_id = ?, processing_at = NOW()
        WHERE id IN ($placeholders)
    ");
    // worker_id первый, потом id'шники
    $updateParams = array_merge([$worker_id], $ids);
    $updateStmt->execute($updateParams);

    // Логируем выдачу
    $logStmt = $pdo->prepare("
        INSERT INTO view_log (worker_id, action, details, created_at)
        VALUES (:worker_id, 'urls_assigned', :details, NOW())
    ");
    $logStmt->execute([
        ':worker_id' => $worker_id,
        ':details' => json_encode(['count' => count($ids), 'ids' => $ids])
    ]);
}

echo json_encode($urls, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
