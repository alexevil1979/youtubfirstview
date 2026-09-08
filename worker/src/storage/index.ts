import Database from 'better-sqlite3';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import type { JobStatus, MetricsSnapshot, StoredJob } from '../types.js';

export class Storage {
  private readonly db: Database.Database;

  constructor(sqlitePath: string) {
    mkdirSync(dirname(sqlitePath), { recursive: true });
    this.db = new Database(sqlitePath);
    this.db.pragma('journal_mode = WAL');
    this.db.pragma('busy_timeout = 5000');
    this.migrate();
  }

  private migrate(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS jobs (
        id TEXT PRIMARY KEY,
        video_id TEXT NOT NULL,
        url TEXT NOT NULL,
        status TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER,
        last_error TEXT,
        last_error_code TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        started_at INTEGER,
        finished_at INTEGER,
        result_json TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
      CREATE INDEX IF NOT EXISTS idx_jobs_retry ON jobs(status, next_retry_at);

      CREATE TABLE IF NOT EXISTS metrics (
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL DEFAULT 0
      );

      INSERT OR IGNORE INTO metrics(key, value) VALUES
        ('jobs_total', 0),
        ('jobs_success', 0),
        ('jobs_failed', 0),
        ('jobs_retry', 0),
        ('browser_crashes', 0),
        ('network_errors', 0);
    `);
  }

  recoverRunningToPending(): number {
    const now = Date.now();
    const info = this.db
      .prepare(
        `UPDATE jobs SET status = 'pending', updated_at = ?, started_at = NULL
         WHERE status = 'running'`,
      )
      .run(now);
    return info.changes;
  }

  upsertPending(job: {
    id: string;
    video_id: string;
    url: string;
    priority?: number;
  }): boolean {
    const existing = this.getJob(job.id);
    if (existing) {
      // Idempotency: do not re-queue success/failed/running
      if (existing.status === 'success' || existing.status === 'failed' || existing.status === 'running') {
        return false;
      }
      return false;
    }
    const now = Date.now();
    this.db
      .prepare(
        `INSERT INTO jobs (id, video_id, url, status, priority, attempts, created_at, updated_at)
         VALUES (?, ?, ?, 'pending', ?, 0, ?, ?)`,
      )
      .run(job.id, job.video_id, job.url, job.priority ?? 0, now, now);
    return true;
  }

  getJob(id: string): StoredJob | null {
    const row = this.db.prepare(`SELECT * FROM jobs WHERE id = ?`).get(id) as StoredJob | undefined;
    return row ?? null;
  }

  listJobs(limit = 50): StoredJob[] {
    return this.db
      .prepare(`SELECT * FROM jobs ORDER BY updated_at DESC LIMIT ?`)
      .all(limit) as StoredJob[];
  }

  countByStatus(status: JobStatus): number {
    const row = this.db.prepare(`SELECT COUNT(*) AS c FROM jobs WHERE status = ?`).get(status) as {
      c: number;
    };
    return row.c;
  }

  queueSize(): number {
    const row = this.db
      .prepare(
        `SELECT COUNT(*) AS c FROM jobs WHERE status IN ('pending', 'retry', 'running')`,
      )
      .get() as { c: number };
    return row.c;
  }

  /**
   * Atomically claim next runnable job (pending or due retry).
   */
  claimNextJob(): StoredJob | null {
    const now = Date.now();
    const tx = this.db.transaction(() => {
      const job = this.db
        .prepare(
          `SELECT * FROM jobs
           WHERE status = 'pending'
              OR (status = 'retry' AND (next_retry_at IS NULL OR next_retry_at <= ?))
           ORDER BY priority DESC, created_at ASC
           LIMIT 1`,
        )
        .get(now) as StoredJob | undefined;
      if (!job) return null;

      this.db
        .prepare(
          `UPDATE jobs SET status = 'running', started_at = ?, updated_at = ?, attempts = attempts + 1
           WHERE id = ? AND status IN ('pending', 'retry')`,
        )
        .run(now, now, job.id);

      return this.getJob(job.id);
    });
    return tx();
  }

  markSuccess(id: string, resultJson: string): void {
    const now = Date.now();
    this.db
      .prepare(
        `UPDATE jobs SET status = 'success', finished_at = ?, updated_at = ?, result_json = ?,
         last_error = NULL, last_error_code = NULL, next_retry_at = NULL
         WHERE id = ?`,
      )
      .run(now, now, resultJson, id);
    this.incMetric('jobs_total');
    this.incMetric('jobs_success');
  }

  markFailed(id: string, error: string, errorCode: string, resultJson?: string): void {
    const now = Date.now();
    this.db
      .prepare(
        `UPDATE jobs SET status = 'failed', finished_at = ?, updated_at = ?,
         last_error = ?, last_error_code = ?, result_json = ?, next_retry_at = NULL
         WHERE id = ?`,
      )
      .run(now, now, error, errorCode, resultJson ?? null, id);
    this.incMetric('jobs_total');
    this.incMetric('jobs_failed');
  }

  markRetry(id: string, nextRetryAt: number, error: string, errorCode: string): void {
    const now = Date.now();
    this.db
      .prepare(
        `UPDATE jobs SET status = 'retry', updated_at = ?, next_retry_at = ?,
         last_error = ?, last_error_code = ?, started_at = NULL
         WHERE id = ?`,
      )
      .run(now, nextRetryAt, error, errorCode, id);
    this.incMetric('jobs_retry');
  }

  incMetric(key: keyof MetricsSnapshot | string): void {
    this.db.prepare(`UPDATE metrics SET value = value + 1 WHERE key = ?`).run(key);
  }

  getMetrics(): MetricsSnapshot {
    const rows = this.db.prepare(`SELECT key, value FROM metrics`).all() as Array<{
      key: string;
      value: number;
    }>;
    const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
    return {
      jobs_total: map.jobs_total ?? 0,
      jobs_success: map.jobs_success ?? 0,
      jobs_failed: map.jobs_failed ?? 0,
      jobs_retry: map.jobs_retry ?? 0,
      browser_crashes: map.browser_crashes ?? 0,
      network_errors: map.network_errors ?? 0,
    };
  }

  close(): void {
    this.db.close();
  }
}
