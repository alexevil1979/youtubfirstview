import { config as loadDotenv } from 'dotenv';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

export type ApiMode = 'youpub' | 'video-tests';

export interface AppConfig {
  nodeEnv: string;
  serverApiUrl: string;
  workerToken: string;
  workerId: string;
  apiMode: ApiMode;
  pollInterval: number;
  maxConcurrentJobs: number;
  maxRetries: number;
  fetchLimit: number;
  browserTimeout: number;
  playbackTestSeconds: number;
  minFreeRamMb: number;
  healthHost: string;
  healthPort: number;
  logLevel: string;
  sqlitePath: string;
  claimTtlSeconds: number;
}

function env(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`Missing required env: ${name}`);
  }
  return value;
}

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number(raw);
  if (!Number.isFinite(n)) throw new Error(`Invalid number for ${name}`);
  return n;
}

export function loadConfig(envPath?: string): AppConfig {
  const candidates = [
    envPath,
    resolve(process.cwd(), '.env'),
    resolve(process.cwd(), 'worker/.env'),
  ].filter(Boolean) as string[];

  for (const p of candidates) {
    if (existsSync(p)) {
      loadDotenv({ path: p });
      break;
    }
  }

  const apiMode = (process.env.API_MODE ?? 'youpub') as ApiMode;
  if (apiMode !== 'youpub' && apiMode !== 'video-tests') {
    throw new Error('API_MODE must be youpub or video-tests');
  }

  const serverApiUrl = env('SERVER_API_URL', 'https://example.com').replace(/\/$/, '');
  const workerToken = process.env.WORKER_TOKEN ?? '';
  const workerId = env('WORKER_ID', 'worker-local-01');

  return {
    nodeEnv: process.env.NODE_ENV ?? 'production',
    serverApiUrl,
    workerToken,
    workerId,
    apiMode,
    pollInterval: envInt('POLL_INTERVAL', 10_000),
    maxConcurrentJobs: envInt('MAX_CONCURRENT_JOBS', 2),
    maxRetries: envInt('MAX_RETRIES', 4),
    fetchLimit: envInt('FETCH_LIMIT', 5),
    browserTimeout: envInt('BROWSER_TIMEOUT', 30_000),
    playbackTestSeconds: envInt('PLAYBACK_TEST_SECONDS', 5),
    minFreeRamMb: envInt('MIN_FREE_RAM_MB', 512),
    healthHost: process.env.HEALTH_HOST ?? '127.0.0.1',
    healthPort: envInt('HEALTH_PORT', 8080),
    logLevel: process.env.LOG_LEVEL ?? 'info',
    sqlitePath: process.env.SQLITE_PATH ?? './data/worker.db',
    claimTtlSeconds: envInt('CLAIM_TTL_SECONDS', 300),
  };
}
