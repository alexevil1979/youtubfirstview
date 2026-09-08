export enum JobErrorCode {
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT = 'TIMEOUT',
  VIDEO_NOT_FOUND = 'VIDEO_NOT_FOUND',
  VIDEO_NOT_READY = 'VIDEO_NOT_READY',
  PLAYER_ERROR = 'PLAYER_ERROR',
  BROWSER_ERROR = 'BROWSER_ERROR',
  SERVER_ERROR = 'SERVER_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
}

export type JobStatus = 'pending' | 'running' | 'success' | 'failed' | 'retry';

export type JobResultStatus = 'success' | 'failed' | 'waiting';

export interface RemoteJob {
  id: string;
  video_id: string;
  url: string;
  created_at?: string;
  priority?: number;
  target_watch_time?: number;
}

export interface StoredJob {
  id: string;
  video_id: string;
  url: string;
  status: JobStatus;
  priority: number;
  attempts: number;
  next_retry_at: number | null;
  last_error: string | null;
  last_error_code: string | null;
  created_at: number;
  updated_at: number;
  started_at: number | null;
  finished_at: number | null;
  result_json: string | null;
}

export interface SmokeTestResult {
  status: JobResultStatus;
  video_id: string;
  started_at: string;
  finished_at: string;
  page_loaded: boolean;
  player_loaded: boolean;
  playback_started: boolean;
  duration_checked: number;
  http_status: number | null;
  response_time_ms: number | null;
  error: string | null;
  error_code: JobErrorCode | null;
}

export interface HealthSnapshot {
  status: 'ok' | 'degraded';
  worker_id: string;
  uptime: number;
  queue_size: number;
  active_jobs: number;
}

export interface MetricsSnapshot {
  jobs_total: number;
  jobs_success: number;
  jobs_failed: number;
  jobs_retry: number;
  browser_crashes: number;
  network_errors: number;
}
