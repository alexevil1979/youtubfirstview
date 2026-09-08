import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { extractVideoId } from '../src/api/client.js';
import { JobErrorCode } from '../src/types.js';
import { Semaphore } from '../src/queue/semaphore.js';

describe('VideoSmokeTest helpers', () => {
  it('extracts video ids', () => {
    assert.equal(extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    assert.equal(extractVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    assert.equal(extractVideoId('https://youtube.com/shorts/abc123'), 'abc123');
  });

  it('exposes structured error codes', () => {
    assert.equal(JobErrorCode.NETWORK_ERROR, 'NETWORK_ERROR');
    assert.equal(JobErrorCode.TIMEOUT, 'TIMEOUT');
  });
});

describe('Semaphore concurrency', () => {
  it('limits concurrent slots', async () => {
    const s = new Semaphore(2);
    assert.equal(s.tryAcquire(), true);
    assert.equal(s.tryAcquire(), true);
    assert.equal(s.tryAcquire(), false);
    assert.equal(s.availableSlots, 0);
    s.release();
    assert.equal(s.availableSlots, 1);
    assert.equal(s.tryAcquire(), true);
  });
});
