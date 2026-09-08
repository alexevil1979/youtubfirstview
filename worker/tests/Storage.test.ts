import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Storage } from '../src/storage/index.js';

describe('Storage', () => {
  const dir = mkdtempSync(join(tmpdir(), 'qa-worker-'));
  const dbPath = join(dir, 't.db');
  const storage = new Storage(dbPath);

  it('recovers running to pending', () => {
    assert.equal(storage.upsertPending({ id: '1', video_id: 'v', url: 'https://youtu.be/v' }), true);
    const job = storage.claimNextJob();
    assert.ok(job);
    assert.equal(job!.status, 'running');
    const n = storage.recoverRunningToPending();
    assert.equal(n, 1);
    assert.equal(storage.getJob('1')!.status, 'pending');
  });

  it('prevents duplicate enqueue after success', () => {
    storage.markSuccess('1', '{}');
    assert.equal(storage.upsertPending({ id: '1', video_id: 'v', url: 'https://youtu.be/v' }), false);
  });

  it('tracks metrics', () => {
    const m = storage.getMetrics();
    assert.ok(m.jobs_success >= 1);
  });

  // cleanup after suite
  process.on('exit', () => {
    try {
      storage.close();
    } catch {
      /* ignore */
    }
    rmSync(dir, { recursive: true, force: true });
  });
});
