import type { AppConfig } from './config/index.js';
import type { Logger } from './logging/index.js';
import { ApiClient } from './api/client.js';
import { ResultReporter } from './api/reporter.js';
import { BrowserManager } from './browser/manager.js';
import { VideoSmokeTest } from './browser/smoke-test.js';
import { JobQueue } from './queue/index.js';
import { RetryManager } from './queue/retry.js';
import { Semaphore } from './queue/semaphore.js';
import { Storage } from './storage/index.js';
import { HealthMonitor } from './health/monitor.js';
import { ResourceMonitor } from './health/resources.js';
import { JobErrorCode } from './types.js';

export class Worker {
  private readonly storage: Storage;
  private readonly queue: JobQueue;
  private readonly api: ApiClient;
  private readonly reporter: ResultReporter;
  private readonly browserManager: BrowserManager;
  private readonly smokeTest: VideoSmokeTest;
  private readonly retry: RetryManager;
  private readonly semaphore: Semaphore;
  private readonly resources: ResourceMonitor;
  private readonly health: HealthMonitor;

  private stopping = false;
  private pollTimer: NodeJS.Timeout | null = null;
  private readonly inFlight = new Set<Promise<void>>();

  constructor(
    private readonly config: AppConfig,
    private readonly logger: Logger,
  ) {
    this.storage = new Storage(config.sqlitePath);
    this.queue = new JobQueue(this.storage);
    this.api = new ApiClient(config, logger);
    this.reporter = new ResultReporter(this.api, logger);
    this.browserManager = new BrowserManager();
    this.smokeTest = new VideoSmokeTest(
      this.browserManager,
      {
        browserTimeout: config.browserTimeout,
        playbackTestSeconds: config.playbackTestSeconds,
      },
      logger,
    );
    this.retry = new RetryManager(config.maxRetries);
    this.semaphore = new Semaphore(config.maxConcurrentJobs);
    this.resources = new ResourceMonitor(config.minFreeRamMb);
    this.health = new HealthMonitor(config, this.queue, this.storage, () => this.semaphore.activeCount);
  }

  async start(): Promise<void> {
    const recovered = this.queue.recover();
    this.logger.info({ event: 'worker_started', recovered_running: recovered });

    await this.health.start();
    this.logger.info({
      event: 'health_started',
      host: this.config.healthHost,
      port: this.config.healthPort,
    });

    await this.pollOnce();
    this.pollTimer = setInterval(() => {
      void this.pollOnce();
    }, this.config.pollInterval);

    // Also try to drain queue periodically
    setInterval(() => {
      void this.drain();
    }, 1000).unref();
  }

  private async pollOnce(): Promise<void> {
    if (this.stopping) return;
    try {
      const jobs = await this.api.fetchJobs();
      const added = this.queue.enqueueRemote(jobs);
      this.logger.info({ event: 'jobs_fetched', count: jobs.length, added });
      await this.drain();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.error({ event: 'server_error', error: message });
      this.storage.incMetric('network_errors');
    }
  }

  private async drain(): Promise<void> {
    while (!this.stopping && this.semaphore.availableSlots > 0) {
      const check = this.resources.canStartBrowser();
      if (!check.ok) {
        this.logger.warn({ event: 'resource_wait', reason: check.reason, ...check.snapshot });
        break;
      }
      if (!this.semaphore.tryAcquire()) break;

      const job = this.queue.claimNext();
      if (!job) {
        this.semaphore.release();
        break;
      }

      const p = this.runJob(job.id)
        .catch((err) => {
          this.logger.error({
            event: 'job_failed',
            job_id: job.id,
            error: err instanceof Error ? err.message : String(err),
          });
        })
        .finally(() => {
          this.semaphore.release();
          this.inFlight.delete(p);
        });
      this.inFlight.add(p);
    }
  }

  private async runJob(jobId: string): Promise<void> {
    const job = this.storage.getJob(jobId);
    if (!job) return;

    this.logger.info({
      event: 'job_started',
      job_id: job.id,
      video_id: job.video_id,
      attempt: job.attempts,
    });

    const claimed = await this.api.claimJob(job.id);
    if (!claimed) {
      this.storage.markRetry(job.id, Date.now() + 30_000, 'claim_conflict', JobErrorCode.SERVER_ERROR);
      return;
    }

    const result = await this.smokeTest.test(job.url);

    if (result.status === 'success') {
      try {
        await this.reporter.report(job.id, job.video_id, result);
        this.storage.markSuccess(job.id, JSON.stringify(result));
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        if (this.retry.shouldRetry(job.attempts)) {
          this.storage.markRetry(
            job.id,
            this.retry.nextRetryAt(job.attempts),
            message,
            JobErrorCode.SERVER_ERROR,
          );
        } else {
          this.storage.markFailed(job.id, message, JobErrorCode.SERVER_ERROR, JSON.stringify(result));
        }
      }
      return;
    }

    if (result.status === 'waiting' || result.error_code === JobErrorCode.NETWORK_ERROR) {
      if (result.error_code === JobErrorCode.NETWORK_ERROR) {
        this.storage.incMetric('network_errors');
      }
      if (this.retry.shouldRetry(job.attempts)) {
        this.storage.markRetry(
          job.id,
          this.retry.nextRetryAt(job.attempts),
          result.error ?? 'retry',
          result.error_code ?? JobErrorCode.UNKNOWN_ERROR,
        );
        this.logger.info({
          event: 'job_retry',
          job_id: job.id,
          attempt: job.attempts,
          next_retry_at: this.retry.nextRetryAt(job.attempts),
        });
        return;
      }
    }

    if (result.error_code === JobErrorCode.BROWSER_ERROR) {
      this.storage.incMetric('browser_crashes');
      this.resources.killOrphanChromium();
    }

    try {
      await this.reporter.report(job.id, job.video_id, result);
    } catch {
      // still mark failed locally
    }
    this.storage.markFailed(
      job.id,
      result.error ?? 'failed',
      result.error_code ?? JobErrorCode.UNKNOWN_ERROR,
      JSON.stringify(result),
    );
    this.logger.info({
      event: 'job_failed',
      job_id: job.id,
      video_id: job.video_id,
      status: result.status,
      error_code: result.error_code,
    });
  }

  async stop(): Promise<void> {
    this.stopping = true;
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
    this.logger.info({ event: 'shutdown_started', in_flight: this.inFlight.size });
    await Promise.allSettled([...this.inFlight]);
    await this.browserManager.closeBrowser();
    await this.health.stop();
    this.storage.close();
    this.logger.info({ event: 'shutdown_complete' });
  }

  /** Exposed for CLI */
  getQueue(): JobQueue {
    return this.queue;
  }

  getStorage(): Storage {
    return this.storage;
  }

  getSmokeTest(): VideoSmokeTest {
    return this.smokeTest;
  }

  getBrowserManager(): BrowserManager {
    return this.browserManager;
  }
}
