<?php
declare(strict_types=1);

function auth_start(array $config): void
{
    $name = $config['admin']['session_name'] ?? 'youpubview_sess';
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_name($name);
        session_start([
            'cookie_httponly' => true,
            'cookie_samesite' => 'Lax',
            'cookie_secure' => (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'),
            'use_strict_mode' => true,
        ]);
    }
}

function auth_ensure_default_admin(PDO $pdo, array $config): void
{
    $count = (int) $pdo->query('SELECT COUNT(*) FROM admin_users')->fetchColumn();
    if ($count > 0) {
        return;
    }

    $username = $config['admin']['username'] ?? 'admin';
    $hash = $config['admin']['password_hash']
        ?? password_hash('ChangeMeNow!', PASSWORD_DEFAULT);

    $stmt = $pdo->prepare('INSERT INTO admin_users (username, password_hash) VALUES (?, ?)');
    $stmt->execute([$username, $hash]);
}

function auth_user(): ?array
{
    return $_SESSION['admin_user'] ?? null;
}

function auth_check(): bool
{
    return auth_user() !== null;
}

function auth_require(): void
{
    if (!auth_check()) {
        redirect('/login.php');
    }
}

function auth_login(PDO $pdo, string $username, string $password): bool
{
    $stmt = $pdo->prepare('SELECT id, username, password_hash FROM admin_users WHERE username = ? LIMIT 1');
    $stmt->execute([$username]);
    $user = $stmt->fetch();
    if (!$user || !password_verify($password, $user['password_hash'])) {
        return false;
    }

    session_regenerate_id(true);
    $_SESSION['admin_user'] = [
        'id' => (int) $user['id'],
        'username' => $user['username'],
    ];

    $pdo->prepare('UPDATE admin_users SET last_login_at = NOW() WHERE id = ?')->execute([(int) $user['id']]);
    return true;
}

function auth_logout(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }
    session_destroy();
}

function auth_change_password(PDO $pdo, int $userId, string $current, string $newPassword): bool
{
    $stmt = $pdo->prepare('SELECT password_hash FROM admin_users WHERE id = ?');
    $stmt->execute([$userId]);
    $hash = $stmt->fetchColumn();
    if (!$hash || !password_verify($current, (string) $hash)) {
        return false;
    }
    if (strlen($newPassword) < 8) {
        return false;
    }
    $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
    $pdo->prepare('UPDATE admin_users SET password_hash = ? WHERE id = ?')->execute([$newHash, $userId]);
    return true;
}
