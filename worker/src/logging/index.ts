import pino, { type Logger } from 'pino';
import type { AppConfig } from '../config/index.js';

export function createLogger(config: AppConfig): Logger {
  return pino({
    level: config.logLevel,
    base: {
      worker_id: config.workerId,
    },
    timestamp: pino.stdTimeFunctions.isoTime,
    redact: {
      paths: ['worker_token', 'token', 'authorization', 'headers.authorization'],
      censor: '[REDACTED]',
    },
  });
}

export type { Logger };
