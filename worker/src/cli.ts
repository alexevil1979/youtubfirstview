import { loadConfig } from './config/index.js';
import { createLogger } from './logging/index.js';
import { Storage } from './storage/index.js';
import { JobQueue } from './queue/index.js';
import { BrowserManager } from './browser/manager.js';
import { VideoSmokeTest } from './browser/smoke-test.js';

async function main(): Promise<void> {
  process.env.ALLOW_EMPTY_TOKEN = '1';
  const config = loadConfig();
  const cmd = process.argv[2] ?? 'help';

  if (cmd === 'status') {
    const storage = new Storage(config.sqlitePath);
    const queue = new JobQueue(storage);
    console.log(
      JSON.stringify(
        {
          worker_id: config.workerId,
          queue_size: queue.size(),
          pending: storage.countByStatus('pending'),
          running: storage.countByStatus('running'),
          retry: storage.countByStatus('retry'),
          success: storage.countByStatus('success'),
          failed: storage.countByStatus('failed'),
          metrics: storage.getMetrics(),
        },
        null,
        2,
      ),
    );
    storage.close();
    return;
  }

  if (cmd === 'jobs') {
    const storage = new Storage(config.sqlitePath);
    const queue = new JobQueue(storage);
    console.log(JSON.stringify(queue.list(100), null, 2));
    storage.close();
    return;
  }

  if (cmd === 'health') {
    const url = `http://${config.healthHost}:${config.healthPort}/health`;
    const res = await fetch(url);
    const body = await res.text();
    console.log(body);
    if (!res.ok) process.exit(1);
    return;
  }

  if (cmd === 'test') {
    const url = process.argv[3];
    if (!url) {
      console.error('Usage: npm run worker:test -- <youtube-url>');
      process.exit(1);
    }
    const logger = createLogger(config);
    const browserManager = new BrowserManager();
    const smoke = new VideoSmokeTest(
      browserManager,
      {
        browserTimeout: config.browserTimeout,
        playbackTestSeconds: config.playbackTestSeconds,
      },
      logger,
    );
    try {
      const result = await smoke.test(url);
      console.log(JSON.stringify(result, null, 2));
      process.exit(result.status === 'success' ? 0 : 1);
    } finally {
      await browserManager.closeBrowser();
    }
  }

  console.log(`Commands: status | jobs | health | test <url>`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
