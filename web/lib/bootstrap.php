<?php
declare(strict_types=1);

$configPath = dirname(__DIR__) . '/config.php';
if (!is_file($configPath)) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo "Missing config.php. Copy config.example.php to config.php and configure DB/admin.\n";
    exit;
}

/** @var array $config */
$config = require $configPath;

date_default_timezone_set($config['app']['timezone'] ?? 'UTC');

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/settings.php';

$pdo = db_connect($config);
$GLOBALS['pdo'] = $pdo;
$GLOBALS['config'] = $config;

// Ensure default admin exists (first install)
auth_ensure_default_admin($pdo, $config);
