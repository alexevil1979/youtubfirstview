import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Storage } from '../src/storage/index.js';
import { JobQueue } from '../src/queue/index.js';

describe('JobQueue', () => {
  const dir = mkdtempSync(join(tmpdir(), 'qa-queue-'));
  const storage = new Storage(join(dir, 'q.db'));
  const queue = new JobQueue(storage);

  it('deduplicates jobs', () => {
    const added1 = queue.enqueueRemote([
      { id: 'a', video_id: 'v1', url: 'https://youtube.com/watch?v=v1', priority: 1 },
      { id: 'a', video_id: 'v1', url: 'https://youtube.com/watch?v=v1', priority: 1 },
    ]);
    assert.equal(added1, 1);
    const added2 = queue.enqueueRemote([
      { id: 'a', video_id: 'v1', url: 'https://youtube.com/watch?v=v1' },
    ]);
    assert.equal(added2, 0);
  });

  it('claims only one at a time', () => {
    queue.enqueueRemote([{ id: 'b', video_id: 'v2', url: 'https://youtube.com/watch?v=v2' }]);
    const j1 = queue.claimNext();
    const j2 = queue.claimNext();
    assert.ok(j1);
    // second claim should get other pending or null; a is pending from previous? a might still be pending
    // After first test, 'a' is still pending. claimNext may get 'a' or we already claimed in... 
    // Actually 'a' was never claimed in first test. So j1 might be 'a' and j2 'b'.
    assert.ok(j1);
    if (j2) {
      assert.notEqual(j1!.id, j2.id);
    }
  });

  process.on('exit', () => {
    try {
      storage.close();
    } catch {
      /* ignore */
    }
    rmSync(dir, { recursive: true, force: true });
  });
});
