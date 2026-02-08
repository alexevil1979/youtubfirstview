-- ============================================================================
-- Создание базы данных и таблиц для YouTube AutoView (YouPub API v2.0)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS youtube_views
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE youtube_views;

-- Таблица API-токенов для авторизации ботов
CREATE TABLE IF NOT EXISTS api_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE COMMENT 'Bearer-токен',
    description VARCHAR(255) DEFAULT '' COMMENT 'Описание (для какого бота)',
    is_active TINYINT(1) DEFAULT 1 COMMENT 'Активен ли токен',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_token (token),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица URL'ов для просмотра
CREATE TABLE IF NOT EXISTS urls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    url VARCHAR(500) NOT NULL COMMENT 'URL для просмотра',
    status ENUM('pending', 'processing', 'done', 'error') DEFAULT 'pending' COMMENT 'Статус просмотра',
    target_watch_time INT DEFAULT 0 COMMENT 'Целевое время просмотра (сек), 0 = решает бот',
    watch_time INT DEFAULT 0 COMMENT 'Фактическое время просмотра (сек)',
    priority INT DEFAULT 0 COMMENT 'Приоритет (больше = раньше)',
    worker_id VARCHAR(100) DEFAULT NULL COMMENT 'ID бота, который обрабатывает',
    error_message TEXT DEFAULT NULL COMMENT 'Описание ошибки (если status=error)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Дата добавления',
    processing_at TIMESTAMP NULL COMMENT 'Дата начала обработки',
    viewed_at TIMESTAMP NULL COMMENT 'Дата завершения просмотра',
    INDEX idx_status (status),
    INDEX idx_priority_created (priority DESC, created_at ASC),
    INDEX idx_worker (worker_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица логов действий ботов
CREATE TABLE IF NOT EXISTS view_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    worker_id VARCHAR(100) NOT NULL COMMENT 'ID бота',
    action VARCHAR(50) NOT NULL COMMENT 'Действие (urls_assigned, status_done, status_error)',
    details JSON DEFAULT NULL COMMENT 'Детали в JSON',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_worker_action (worker_id, action),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Пример: создание токена
-- ============================================================================
INSERT INTO api_tokens (token, description) VALUES
    ('your-secret-token-here', 'Основной бот');

-- ============================================================================
-- Пример: тестовые URL'ы
-- ============================================================================
INSERT INTO urls (url, target_watch_time, priority) VALUES
    ('https://youtube.com/shorts/dQw4w9WgXcQ', 30, 10),
    ('https://youtube.com/shorts/abcdef12345', 60, 5),
    ('https://youtube.com/shorts/test123video', 0, 0),
    ('https://youtube.com/shorts/sample456url', 45, 0),
    ('https://youtube.com/shorts/demo789clip', 90, 3);
