/** Exponential backoff schedule (ms) by attempt number (1-based). */
const DEFAULT_BACKOFF_MS = [
  30_000, // 1 → 30s
  60_000, // 2 → 60s
  5 * 60_000, // 3 → 5m
  15 * 60_000, // 4 → 15m
];

export class RetryManager {
  constructor(
    private readonly maxRetries: number,
    private readonly backoffMs: number[] = DEFAULT_BACKOFF_MS,
  ) {}

  shouldRetry(attempts: number): boolean {
    return attempts < this.maxRetries;
  }

  nextDelayMs(attempts: number): number {
    const idx = Math.min(Math.max(attempts, 1), this.backoffMs.length) - 1;
    return this.backoffMs[idx] ?? this.backoffMs[this.backoffMs.length - 1]!;
  }

  nextRetryAt(attempts: number, now = Date.now()): number {
    return now + this.nextDelayMs(attempts);
  }
}
