import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { RetryManager } from '../src/queue/retry.js';

describe('RetryManager', () => {
  const retry = new RetryManager(4);

  it('uses exponential-ish backoff', () => {
    assert.equal(retry.nextDelayMs(1), 30_000);
    assert.equal(retry.nextDelayMs(2), 60_000);
    assert.equal(retry.nextDelayMs(3), 5 * 60_000);
    assert.equal(retry.nextDelayMs(4), 15 * 60_000);
  });

  it('stops after max retries', () => {
    assert.equal(retry.shouldRetry(1), true);
    assert.equal(retry.shouldRetry(3), true);
    assert.equal(retry.shouldRetry(4), false);
  });

  it('computes next_retry_at', () => {
    const now = 1_000_000;
    assert.equal(retry.nextRetryAt(1, now), now + 30_000);
  });
});
