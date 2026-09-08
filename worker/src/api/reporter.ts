import type { ApiClient } from '../api/client.js';
import type { Logger } from '../logging/index.js';
import type { SmokeTestResult } from '../types.js';

export class ResultReporter {
  constructor(
    private readonly api: ApiClient,
    private readonly logger: Logger,
  ) {}

  async report(jobId: string, videoId: string, result: SmokeTestResult): Promise<void> {
    try {
      await this.api.reportResult(jobId, result);
      this.logger.info({
        event: 'job_completed',
        job_id: jobId,
        video_id: videoId,
        status: result.status,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error({
        event: 'job_failed',
        job_id: jobId,
        video_id: videoId,
        error: message,
        phase: 'report',
      });
      throw err;
    }
  }
}
