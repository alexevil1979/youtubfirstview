-- Выполнить на VPS в MySQL (БД youpub).
-- После этого в token.txt должен быть plaintext ниже.

INSERT INTO youpub.api_tokens
  (name, token, plain_prefix, permissions, user_id, is_active, created_at)
VALUES
  (
    'Win10 AutoIt',
    'ee4723221a385e38c8f4f90bd14c0a0b6734f9e0873d093d2841402d4539b3af',
    'a7c3e91f',
    'autoview',
    NULL,
    1,
    NOW()
  );

-- Plaintext для C:\bots\viewer\token.txt:
-- a7c3e91f2b4d6800c1e5f9a2d3b4768e0f1a2b3c4d5e6f708192a3b4c5d6e7f8
