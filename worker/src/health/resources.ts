import { freemem, loadavg } from 'node:os';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

export interface ResourceSnapshot {
  freeRamMb: number;
  loadAverage1m: number;
  chromiumProcesses: number;
}

export class ResourceMonitor {
  constructor(private readonly minFreeRamMb: number) {}

  snapshot(): ResourceSnapshot {
    return {
      freeRamMb: this.readFreeRamMb(),
      loadAverage1m: loadavg()[0] ?? 0,
      chromiumProcesses: this.countChromium(),
    };
  }

  canStartBrowser(): { ok: boolean; reason?: string; snapshot: ResourceSnapshot } {
    const snapshot = this.snapshot();
    if (snapshot.freeRamMb < this.minFreeRamMb) {
      return {
        ok: false,
        reason: `insufficient_ram free=${snapshot.freeRamMb}MB min=${this.minFreeRamMb}MB`,
        snapshot,
      };
    }
    return { ok: true, snapshot };
  }

  private readFreeRamMb(): number {
    try {
      const meminfo = readFileSync('/proc/meminfo', 'utf8');
      const avail = meminfo.match(/^MemAvailable:\s+(\d+)/m);
      if (avail) return Math.floor(Number(avail[1]) / 1024);
      const free = meminfo.match(/^MemFree:\s+(\d+)/m);
      if (free) return Math.floor(Number(free[1]) / 1024);
    } catch {
      return Math.floor(freemem() / (1024 * 1024));
    }
    return Math.floor(freemem() / (1024 * 1024));
  }

  private countChromium(): number {
    try {
      const out = execFileSync(
        'bash',
        ['-lc', `ps -eo comm= | grep -E 'chrom(ium|e)' | grep -v grep | wc -l`],
        { encoding: 'utf8' },
      );
      return Number(out.trim()) || 0;
    } catch {
      return 0;
    }
  }

  killOrphanChromium(): void {
    try {
      execFileSync('bash', ['-lc', `pkill -f 'chromium.*--headless' || true`], {
        encoding: 'utf8',
      });
    } catch {
      // ignore on non-Linux / no pkill
    }
  }
}
