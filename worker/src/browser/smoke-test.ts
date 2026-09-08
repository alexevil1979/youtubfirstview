import type { Logger } from '../logging/index.js';
import { BrowserManager } from '../browser/manager.js';
import { extractVideoId } from '../api/client.js';
import { JobErrorCode, type SmokeTestResult } from '../types.js';

export interface SmokeTestOptions {
  browserTimeout: number;
  playbackTestSeconds: number;
}

export class VideoSmokeTest {
  constructor(
    private readonly browserManager: BrowserManager,
    private readonly options: SmokeTestOptions,
    private readonly logger: Logger,
  ) {}

  async test(videoUrl: string): Promise<SmokeTestResult> {
    const startedAt = new Date();
    const videoId = extractVideoId(videoUrl);
    const base: SmokeTestResult = {
      status: 'failed',
      video_id: videoId,
      started_at: startedAt.toISOString(),
      finished_at: startedAt.toISOString(),
      page_loaded: false,
      player_loaded: false,
      playback_started: false,
      duration_checked: 0,
      http_status: null,
      response_time_ms: null,
      error: null,
      error_code: null,
    };

    const preflight = await this.httpPreflight(videoUrl);
    base.http_status = preflight.status;
    base.response_time_ms = preflight.responseTimeMs;

    if (!preflight.ok) {
      base.finished_at = new Date().toISOString();
      base.error = preflight.error;
      base.error_code = preflight.errorCode;
      if (preflight.errorCode === JobErrorCode.VIDEO_NOT_READY) {
        base.status = 'waiting';
      }
      this.logger.warn({
        event: 'network_error',
        video_id: videoId,
        error_code: preflight.errorCode,
      });
      return base;
    }

    let context = null;
    let page = null;
    try {
      this.logger.info({ event: 'browser_started', video_id: videoId });
      context = await this.browserManager.createContext();
      page = await this.browserManager.createPage(context);
      page.setDefaultTimeout(this.options.browserTimeout);

      await page.goto(videoUrl, {
        waitUntil: 'domcontentloaded',
        timeout: this.options.browserTimeout,
      });
      base.page_loaded = true;
      this.logger.info({ event: 'page_loaded', video_id: videoId, url: page.url() });

      const currentUrl = page.url();
      if (/\/oops|unavailable|error/i.test(currentUrl)) {
        return this.finish(base, 'failed', JobErrorCode.VIDEO_NOT_FOUND, 'URL looks unavailable');
      }

      const bodyText = ((await page.locator('body').innerText().catch(() => '')) || '').slice(0, 2000);
      if (/video unavailable|this video isn't available|private video|has been removed/i.test(bodyText)) {
        return this.finish(base, 'failed', JobErrorCode.VIDEO_NOT_FOUND, 'Video unavailable text detected');
      }
      if (/sign in to confirm|confirm you.?re not a bot/i.test(bodyText)) {
        // Do not bypass; report as not ready / player error for ops visibility
        return this.finish(
          base,
          'waiting',
          JobErrorCode.VIDEO_NOT_READY,
          'Consent/bot gate page — cannot complete smoke test',
        );
      }

      const player = page.locator('#movie_player, .html5-video-player, ytd-player, video');
      await player.first().waitFor({ state: 'attached', timeout: this.options.browserTimeout });
      base.player_loaded = true;
      this.logger.info({ event: 'player_detected', video_id: videoId });

      const video = page.locator('video').first();
      await video.waitFor({ state: 'attached', timeout: this.options.browserTimeout });

      // Technical playback check only — click play if paused, no engagement.
      await page.evaluate(async () => {
        const el = document.querySelector('video') as HTMLVideoElement | null;
        if (!el) return;
        try {
          el.muted = true;
          await el.play();
        } catch {
          const btn = document.querySelector(
            '.ytp-large-play-button, button[aria-label*="Play"], .ytp-play-button',
          ) as HTMLElement | null;
          btn?.click();
        }
      });

      const checkMs = this.options.playbackTestSeconds * 1000;
      await new Promise((r) => setTimeout(r, checkMs));

      const playback = await page.evaluate(() => {
        const el = document.querySelector('video') as HTMLVideoElement | null;
        if (!el) return { ok: false, currentTime: 0, readyState: 0 };
        return {
          ok: el.readyState >= 2 && (el.currentTime > 0 || !el.paused),
          currentTime: el.currentTime,
          readyState: el.readyState,
          paused: el.paused,
        };
      });

      this.logger.info({
        event: 'playback_test',
        video_id: videoId,
        ...playback,
        duration_checked: this.options.playbackTestSeconds,
      });

      base.duration_checked = this.options.playbackTestSeconds;
      if (!playback.ok) {
        return this.finish(base, 'failed', JobErrorCode.PLAYER_ERROR, 'Playback did not start');
      }

      base.playback_started = true;
      return this.finish(base, 'success', null, null);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const code = /timeout/i.test(message) ? JobErrorCode.TIMEOUT : JobErrorCode.BROWSER_ERROR;
      this.logger.error({ event: 'browser_error', video_id: videoId, err: message });
      return this.finish(base, 'failed', code, message);
    } finally {
      await this.browserManager.closePage(page);
      await this.browserManager.closeContext(context);
    }
  }

  private finish(
    base: SmokeTestResult,
    status: SmokeTestResult['status'],
    errorCode: JobErrorCode | null,
    error: string | null,
  ): SmokeTestResult {
    return {
      ...base,
      status,
      error_code: errorCode,
      error,
      finished_at: new Date().toISOString(),
    };
  }

  private async httpPreflight(videoUrl: string): Promise<{
    ok: boolean;
    status: number | null;
    responseTimeMs: number | null;
    error: string | null;
    errorCode: JobErrorCode;
  }> {
    const started = Date.now();
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.options.browserTimeout);
      let res: Response;
      try {
        res = await fetch(videoUrl, {
          method: 'GET',
          redirect: 'follow',
          signal: controller.signal,
          headers: { 'User-Agent': 'YouTubeQAWorker/1.0' },
        });
      } finally {
        clearTimeout(timer);
      }
      const responseTimeMs = Date.now() - started;
      if (res.status === 404) {
        return {
          ok: false,
          status: res.status,
          responseTimeMs,
          error: 'HTTP 404',
          errorCode: JobErrorCode.VIDEO_NOT_FOUND,
        };
      }
      if (res.status >= 500) {
        return {
          ok: false,
          status: res.status,
          responseTimeMs,
          error: `HTTP ${res.status}`,
          errorCode: JobErrorCode.SERVER_ERROR,
        };
      }
      if (res.status === 429 || res.status === 403) {
        return {
          ok: false,
          status: res.status,
          responseTimeMs,
          error: `HTTP ${res.status}`,
          errorCode: JobErrorCode.VIDEO_NOT_READY,
        };
      }
      if (!res.ok && res.status !== 200) {
        // YouTube often returns 200 for HTML; treat other 4xx as network/not ready
        return {
          ok: false,
          status: res.status,
          responseTimeMs,
          error: `HTTP ${res.status}`,
          errorCode: JobErrorCode.NETWORK_ERROR,
        };
      }
      return {
        ok: true,
        status: res.status,
        responseTimeMs,
        error: null,
        errorCode: JobErrorCode.NETWORK_ERROR,
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return {
        ok: false,
        status: null,
        responseTimeMs: Date.now() - started,
        error: message,
        errorCode: /abort/i.test(message) ? JobErrorCode.TIMEOUT : JobErrorCode.NETWORK_ERROR,
      };
    }
  }
}
