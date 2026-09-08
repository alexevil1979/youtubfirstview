# TODO — YouTube QA Worker

## Phase 1 — Docs & scaffold
- [x] ARCHITECTURE.md
- [x] README.md
- [x] TODO.md
- [x] MIGRATION.md
- [x] package.json / tsconfig / .env.example

## Phase 2 — Core
- [x] config
- [x] logging (pino)
- [x] storage (SQLite)
- [x] queue
- [x] retry
- [x] resource monitor / semaphore

## Phase 3 — Browser & test
- [x] API client (youpub + video-tests)
- [x] BrowserManager
- [x] VideoSmokeTest (HTTP + Playwright)
- [x] ResultReporter

## Phase 4 — Runtime
- [x] Worker main loop
- [x] Health / metrics HTTP
- [x] Graceful shutdown
- [x] CLI (status/jobs/test/health)
- [x] systemd unit
- [x] install.sh
- [x] Dockerfile + docker-compose

## Phase 5 — Quality
- [x] Unit tests
- [x] typecheck / test / build

## Follow-ups (optional)
- [ ] Prometheus scrape format for /metrics
- [ ] Optional Redis for multi-process lock on one host
- [ ] PHP endpoints for `/api/video-tests/*` на сервере YouPub
