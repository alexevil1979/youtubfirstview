import type { AppConfig } from '../config/index.js';
import type { Logger } from '../logging/index.js';
import type { RemoteJob, SmokeTestResult } from '../types.js';

function extractVideoId(url: string): string {
  try {
    const u = new URL(url);
    if (u.hostname.includes('youtu.be')) {
      return u.pathname.replace(/^\//, '').split('/')[0] || 'unknown';
    }
    const v = u.searchParams.get('v');
    if (v) return v;
    const shorts = u.pathname.match(/\/shorts\/([^/?]+)/);
    if (shorts?.[1]) return shorts[1];
    const embed = u.pathname.match(/\/embed\/([^/?]+)/);
    if (embed?.[1]) return embed[1];
  } catch {
    // fallthrough
  }
  return 'unknown';
}

export class ApiClient {
  constructor(
    private readonly config: AppConfig,
    private readonly logger: Logger,
  ) {}

  private authHeaders(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.config.workerToken}`,
      'X-Api-Token': this.config.workerToken,
      Accept: 'application/json',
    };
  }

  async fetchJobs(): Promise<RemoteJob[]> {
    if (this.config.apiMode === 'video-tests') {
      return this.fetchVideoTestJobs();
    }
    return this.fetchYoupubJobs();
  }

  private async fetchYoupubJobs(): Promise<RemoteJob[]> {
    const url = new URL(`${this.config.serverApiUrl}/api/autoview/urls`);
    url.searchParams.set('limit', String(this.config.fetchLimit));
    url.searchParams.set('worker_id', this.config.workerId);

    const res = await fetch(url, {
      method: 'GET',
      headers: this.authHeaders(),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`youpub fetch failed HTTP ${res.status}: ${body.slice(0, 200)}`);
    }

    const data = (await res.json()) as Array<{
      id: number | string;
      url: string;
      target_watch_time?: number;
    }>;

    if (!Array.isArray(data)) {
      throw new Error('youpub fetch: expected JSON array');
    }

    return data.map((item) => ({
      id: String(item.id),
      video_id: extractVideoId(item.url),
      url: item.url,
      priority: 0,
      target_watch_time: item.target_watch_time,
      created_at: new Date().toISOString(),
    }));
  }

  private async fetchVideoTestJobs(): Promise<RemoteJob[]> {
    const res = await fetch(`${this.config.serverApiUrl}/api/video-tests/jobs`, {
      method: 'GET',
      headers: {
        ...this.authHeaders(),
        'X-Worker-Id': this.config.workerId,
      },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`video-tests fetch failed HTTP ${res.status}: ${body.slice(0, 200)}`);
    }
    const data = (await res.json()) as { jobs?: RemoteJob[] };
    return Array.isArray(data.jobs) ? data.jobs : [];
  }

  async claimJob(jobId: string): Promise<boolean> {
    if (this.config.apiMode !== 'video-tests') return true;
    const res = await fetch(`${this.config.serverApiUrl}/api/video-tests/jobs/${jobId}/claim`, {
      method: 'POST',
      headers: {
        ...this.authHeaders(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        worker_id: this.config.workerId,
        ttl_seconds: this.config.claimTtlSeconds,
      }),
    });
    if (res.status === 409) return false;
    if (!res.ok) {
      throw new Error(`claim failed HTTP ${res.status}`);
    }
    return true;
  }

  async reportResult(jobId: string, result: SmokeTestResult): Promise<void> {
    if (this.config.apiMode === 'video-tests') {
      await this.reportVideoTestResult(jobId, result);
      return;
    }
    await this.reportYoupubStatus(jobId, result);
  }

  private async reportYoupubStatus(jobId: string, result: SmokeTestResult): Promise<void> {
    const status = result.status === 'success' ? 'done' : 'error';
    const params = new URLSearchParams();
    params.set('url_id', jobId);
    params.set('status', status);
    params.set('watch_time', String(Math.max(0, Math.round(result.duration_checked))));
    params.set('worker_id', this.config.workerId);
    if (result.error) {
      params.set('error', `${result.error_code ?? 'UNKNOWN'}: ${result.error}`);
    }

    const res = await fetch(`${this.config.serverApiUrl}/api/autoview/status`, {
      method: 'POST',
      headers: {
        ...this.authHeaders(),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`youpub status failed HTTP ${res.status}: ${body.slice(0, 200)}`);
    }
    this.logger.info({ event: 'result_reported', job_id: jobId, status }, 'Result reported to YouPub');
  }

  private async reportVideoTestResult(jobId: string, result: SmokeTestResult): Promise<void> {
    const payload = {
      status: result.status === 'waiting' ? 'failed' : result.status,
      video_id: result.video_id,
      started_at: result.started_at,
      finished_at: result.finished_at,
      page_loaded: result.page_loaded,
      player_loaded: result.player_loaded,
      playback_started: result.playback_started,
      duration_checked: result.duration_checked,
      error: result.error,
      error_code: result.error_code,
      worker_id: this.config.workerId,
    };

    const res = await fetch(`${this.config.serverApiUrl}/api/video-tests/jobs/${jobId}/result`, {
      method: 'POST',
      headers: {
        ...this.authHeaders(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      throw new Error(`video-tests result failed HTTP ${res.status}`);
    }

    const complete = await fetch(
      `${this.config.serverApiUrl}/api/video-tests/jobs/${jobId}/complete`,
      {
        method: 'POST',
        headers: {
          ...this.authHeaders(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ worker_id: this.config.workerId }),
      },
    );
    if (!complete.ok) {
      this.logger.warn({ job_id: jobId, event: 'complete_failed' }, 'complete endpoint failed');
    }
  }
}

export { extractVideoId };
