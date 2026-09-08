import type { Storage } from '../storage/index.js';
import type { RemoteJob, StoredJob } from '../types.js';

export class JobQueue {
  constructor(private readonly storage: Storage) {}

  recover(): number {
    return this.storage.recoverRunningToPending();
  }

  enqueueRemote(jobs: RemoteJob[]): number {
    let added = 0;
    for (const job of jobs) {
      if (
        this.storage.upsertPending({
          id: job.id,
          video_id: job.video_id,
          url: job.url,
          priority: job.priority ?? 0,
        })
      ) {
        added += 1;
      }
    }
    return added;
  }

  claimNext(): StoredJob | null {
    return this.storage.claimNextJob();
  }

  size(): number {
    return this.storage.queueSize();
  }

  activeCount(): number {
    return this.storage.countByStatus('running');
  }

  list(limit = 50): StoredJob[] {
    return this.storage.listJobs(limit);
  }
}
