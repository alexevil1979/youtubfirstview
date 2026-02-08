<?php
/**
 * get_urls.php — Выдача URL'ов для просмотра
 * 
 * GET параметры:
 *   limit — количество URL'ов (по умолчанию 5)
 * 
 * Формат ответа (JSON):
 * [
 *   {"id": "1", "url": "https://youtube.com/shorts/xxxxx"},
 *   {"id": "2", "url": "https://youtube.com/shorts/yyyyy"}
 * ]
 */

header('Content-Type: application/json; charset=utf-8');

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

// Получаем лимит из параметра (по умолчанию 5, максимум 20)
$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 5;
$limit = min(max($limit, 1), 20);

// Выбираем URL'ы, которые ещё не были просмотрены (status = 'pending')
$stmt = $pdo->prepare("
    SELECT id, url 
    FROM urls 
    WHERE status = 'pending' 
    ORDER BY created_at ASC 
    LIMIT :limit
");
$stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
$stmt->execute();

$urls = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Помечаем выданные URL как "в процессе"
if (!empty($urls)) {
    $ids = array_column($urls, 'id');
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $updateStmt = $pdo->prepare("UPDATE urls SET status = 'processing' WHERE id IN ($placeholders)");
    $updateStmt->execute($ids);
}

echo json_encode($urls, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
