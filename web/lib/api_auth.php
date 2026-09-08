<?php
declare(strict_types=1);

/**
 * Shared auth for worker API endpoints.
 */
function api_require_token(PDO $pdo): array
{
    $token = extract_bearer_token();
    if ($token === '') {
        json_response([
            'error' => 'Authorization token required. Send via: Authorization header, ?token= param, or X-Api-Token header',
        ], 401);
    }

    $stmt = $pdo->prepare('SELECT id, is_active FROM api_tokens WHERE token = ? LIMIT 1');
    $stmt->execute([$token]);
    $row = $stmt->fetch();
    if (!$row || !(int) $row['is_active']) {
        json_response(['error' => 'Invalid or expired token'], 401);
    }

    $pdo->prepare('UPDATE api_tokens SET last_used_at = NOW() WHERE id = ?')->execute([(int) $row['id']]);
    return $row;
}
