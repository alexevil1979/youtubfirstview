import { describe, it, mock } from 'node:test';
import assert from 'node:assert/strict';
import { ResultReporter } from '../src/api/reporter.js';
import type { SmokeTestResult } from '../src/types.js';
import { JobErrorCode } from '../src/types.js';

describe('ResultReporter', () => {
  it('forwards success to API', async () => {
    const reportResult = mock.fn(async () => {});
    const logger = {
      info: mock.fn(),
      error: mock.fn(),
      warn: mock.fn(),
    } as any;
    const reporter = new ResultReporter({ reportResult } as any, logger);
    const result: SmokeTestResult = {
      status: 'success',
      video_id: 'abc',
      started_at: new Date().toISOString(),
      finished_at: new Date().toISOString(),
      page_loaded: true,
      player_loaded: true,
      playback_started: true,
      duration_checked: 5,
      http_status: 200,
      response_time_ms: 100,
      error: null,
      error_code: null,
    };
    await reporter.report('1', 'abc', result);
    assert.equal(reportResult.mock.callCount(), 1);
  });

  it('propagates API failure', async () => {
    const reportResult = mock.fn(async () => {
      throw new Error('API down');
    });
    const logger = { info: mock.fn(), error: mock.fn(), warn: mock.fn() } as any;
    const reporter = new ResultReporter({ reportResult } as any, logger);
    const result: SmokeTestResult = {
      status: 'failed',
      video_id: 'abc',
      started_at: new Date().toISOString(),
      finished_at: new Date().toISOString(),
      page_loaded: false,
      player_loaded: false,
      playback_started: false,
      duration_checked: 0,
      http_status: null,
      response_time_ms: null,
      error: 'x',
      error_code: JobErrorCode.NETWORK_ERROR,
    };
    await assert.rejects(() => reporter.report('1', 'abc', result), /API down/);
  });
});
