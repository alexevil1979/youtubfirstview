-- ============================================================================
-- Создание базы данных и таблицы для YouTube AutoView
-- ============================================================================

CREATE DATABASE IF NOT EXISTS youtube_views 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE youtube_views;

-- Таблица URL'ов для просмотра
CREATE TABLE IF NOT EXISTS urls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    url VARCHAR(500) NOT NULL COMMENT 'URL для просмотра',
    status ENUM('pending', 'processing', 'done', 'error') DEFAULT 'pending' COMMENT 'Статус просмотра',
    watch_time INT DEFAULT 0 COMMENT 'Время просмотра в секундах',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Дата добавления',
    viewed_at TIMESTAMP NULL COMMENT 'Дата просмотра',
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Пример данных для тестирования
INSERT INTO urls (url) VALUES 
    ('https://youtube.com/shorts/dQw4w9WgXcQ'),
    ('https://youtube.com/shorts/abcdef12345'),
    ('https://youtube.com/shorts/test123video'),
    ('https://youtube.com/shorts/sample456url'),
    ('https://youtube.com/shorts/demo789clip');
