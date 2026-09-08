-- ============================================================================
-- YouPub View — MySQL 5.7 schema
-- Database: youpubview
-- ============================================================================

CREATE DATABASE IF NOT EXISTS youpubview
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE youpubview;

CREATE TABLE IF NOT EXISTS api_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT '',
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_token (token),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS urls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    url VARCHAR(500) NOT NULL,
    status ENUM('pending', 'processing', 'done', 'error') DEFAULT 'pending',
    target_watch_time INT DEFAULT 0,
    watch_time INT DEFAULT 0,
    priority INT DEFAULT 0,
    worker_id VARCHAR(100) DEFAULT NULL,
    error_message TEXT,
    note VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_at TIMESTAMP NULL DEFAULT NULL,
    viewed_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_status (status),
    INDEX idx_priority_created (priority DESC, created_at ASC),
    INDEX idx_worker (worker_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS view_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    worker_id VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    details JSON DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_worker_action (worker_id, action),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS settings (
    `key` VARCHAR(100) PRIMARY KEY,
    `value` TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS admin_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Default admin: admin / ChangeMeNow!
INSERT INTO admin_users (username, password_hash)
VALUES ('admin', '$2y$10$sqvsoUt/qfQhc/NDkIkKj.ecgZ6hBx4qV/aJ80Dspx23CbDSVCNy.')
ON DUPLICATE KEY UPDATE username = username;

INSERT INTO settings (`key`, `value`) VALUES
    ('site_name', 'YouPub View'),
    ('default_watch_time', '30'),
    ('default_priority', '0'),
    ('stuck_processing_minutes', '30')
ON DUPLICATE KEY UPDATE `key` = `key`;
