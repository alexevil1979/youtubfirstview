import { createServer, type Server } from 'node:http';
import type { AppConfig } from '../config/index.js';
import type { JobQueue } from '../queue/index.js';
import type { Storage } from '../storage/index.js';
import type { HealthSnapshot, MetricsSnapshot } from '../types.js';

export class HealthMonitor {
  private server: Server | null = null;
  private readonly startedAt = Date.now();

  constructor(
    private readonly config: AppConfig,
    private readonly queue: JobQueue,
    private readonly storage: Storage,
    private readonly getActiveJobs: () => number,
  ) {}

  snapshot(): HealthSnapshot {
    return {
      status: 'ok',
      worker_id: this.config.workerId,
      uptime: Math.floor((Date.now() - this.startedAt) / 1000),
      queue_size: this.queue.size(),
      active_jobs: this.getActiveJobs(),
    };
  }

  metrics(): MetricsSnapshot {
    return this.storage.getMetrics();
  }

  async start(): Promise<void> {
    this.server = createServer((req, res) => {
      if (req.url === '/health' && req.method === 'GET') {
        const body = JSON.stringify(this.snapshot());
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(body);
        return;
      }
      if (req.url === '/metrics' && req.method === 'GET') {
        const body = JSON.stringify(this.metrics());
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(body);
        return;
      }
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'not_found' }));
    });

    await new Promise<void>((resolve, reject) => {
      this.server!.once('error', reject);
      this.server!.listen(this.config.healthPort, this.config.healthHost, () => resolve());
    });
  }

  async stop(): Promise<void> {
    if (!this.server) return;
    await new Promise<void>((resolve) => {
      this.server!.close(() => resolve());
    });
    this.server = null;
  }
}
