import { chromium, type Browser, type BrowserContext, type Page } from 'playwright';

export class BrowserManager {
  private browser: Browser | null = null;

  async createBrowser(): Promise<Browser> {
    if (this.browser?.isConnected()) return this.browser;
    this.browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--mute-audio',
      ],
    });
    return this.browser;
  }

  async createContext(): Promise<BrowserContext> {
    const browser = await this.createBrowser();
    return browser.newContext({
      viewport: { width: 1280, height: 720 },
      userAgent:
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 YouTubeQAWorker/1.0',
      // Keep media allowed for technical playback check; no engagement actions.
      permissions: [],
    });
  }

  async createPage(context: BrowserContext): Promise<Page> {
    return context.newPage();
  }

  async closePage(page: Page | null): Promise<void> {
    if (!page) return;
    try {
      await page.close();
    } catch {
      // ignore
    }
  }

  async closeContext(context: BrowserContext | null): Promise<void> {
    if (!context) return;
    try {
      await context.close();
    } catch {
      // ignore
    }
  }

  async closeBrowser(): Promise<void> {
    if (!this.browser) return;
    try {
      await this.browser.close();
    } catch {
      // ignore
    } finally {
      this.browser = null;
    }
  }
}
