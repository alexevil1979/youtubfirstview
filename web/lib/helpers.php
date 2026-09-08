<?php
declare(strict_types=1);

function e(?string $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function redirect(string $path): never
{
    header('Location: ' . $path);
    exit;
}

function flash_set(string $type, string $message): void
{
    $_SESSION['_flash'][] = ['type' => $type, 'message' => $message];
}

function flash_get(): array
{
    $messages = $_SESSION['_flash'] ?? [];
    unset($_SESSION['_flash']);
    return $messages;
}

function csrf_token(): string
{
    if (empty($_SESSION['_csrf'])) {
        $_SESSION['_csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['_csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="_csrf" value="' . e(csrf_token()) . '">';
}

function csrf_verify(): void
{
    $token = $_POST['_csrf'] ?? '';
    if (!is_string($token) || !hash_equals(csrf_token(), $token)) {
        http_response_code(400);
        echo 'Invalid CSRF token';
        exit;
    }
}

function request_method(): string
{
    return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
}

function is_post(): bool
{
    return request_method() === 'POST';
}

function status_badge(string $status): string
{
    $map = [
        'pending' => 'badge-pending',
        'processing' => 'badge-processing',
        'done' => 'badge-done',
        'error' => 'badge-error',
    ];
    $class = $map[$status] ?? 'badge-pending';
    return '<span class="badge ' . $class . '">' . e($status) . '</span>';
}

function extract_bearer_token(): string
{
    $authHeader = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';

    if ($authHeader !== '' && preg_match('/^Bearer\s+(.+)$/i', $authHeader, $m)) {
        return trim($m[1]);
    }

    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strtolower((string) $name) === 'authorization' && preg_match('/^Bearer\s+(.+)$/i', (string) $value, $m)) {
                return trim($m[1]);
            }
        }
    }

    if (function_exists('apache_request_headers')) {
        foreach (apache_request_headers() as $name => $value) {
            if (strtolower((string) $name) === 'authorization' && preg_match('/^Bearer\s+(.+)$/i', (string) $value, $m)) {
                return trim($m[1]);
            }
        }
    }

    if (!empty($_SERVER['HTTP_X_API_TOKEN'])) {
        return trim((string) $_SERVER['HTTP_X_API_TOKEN']);
    }

    if (!empty($_GET['token'])) {
        return trim((string) $_GET['token']);
    }

    if (!empty($_POST['token'])) {
        return trim((string) $_POST['token']);
    }

    return '';
}

function json_response(mixed $data, int $code = 200): never
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function generate_api_token(): string
{
    return bin2hex(random_bytes(24));
}
