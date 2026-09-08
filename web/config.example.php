<?php
/**
 * Copy to config.php on the server and fill secrets.
 * NEVER commit config.php.
 */
return [
    'db' => [
        'host' => '127.0.0.1',
        'name' => 'youpubview',
        'user' => 'youpubview',
        'pass' => 'CHANGE_ME_DB_PASSWORD',
        'charset' => 'utf8mb4',
    ],

    'admin' => [
        'username' => 'admin',
        // Default password: ChangeMeNow!
        'password_hash' => '$2y$10$sqvsoUt/qfQhc/NDkIkKj.ecgZ6hBx4qV/aJ80Dspx23CbDSVCNy.',
        'session_name' => 'youpubview_sess',
    ],

    'app' => [
        'name' => 'YouPub View',
        'base_url' => 'https://youtubview.1tlt.ru',
        'timezone' => 'Europe/Moscow',
        'default_watch_time' => 30,
        'default_priority' => 0,
        'urls_per_page' => 50,
        'logs_per_page' => 100,
    ],
];
