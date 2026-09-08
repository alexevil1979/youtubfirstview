import { loadConfig } from './config/index.js';
import { createLogger } from './logging/index.js';
import { Worker } from './worker.js';

async function main(): Promise<void> {
  process.env.ALLOW_EMPTY_TOKEN = process.env.ALLOW_EMPTY_TOKEN ?? '0';
  const config = loadConfig();
  if (!config.workerToken) {
    throw new Error('WORKER_TOKEN is required');
  }

  const logger = createLogger(config);
  const worker = new Worker(config, logger);

  const shutdown = async (signal: string) => {
    logger.info({ event: 'signal', signal });
    try {
      await worker.stop();
      process.exit(0);
    } catch (err) {
      logger.error({ event: 'shutdown_error', err: err instanceof Error ? err.message : String(err) });
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));

  await worker.start();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
