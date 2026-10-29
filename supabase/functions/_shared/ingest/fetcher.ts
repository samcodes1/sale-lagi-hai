// Polite fetching for ingestion: identify ourselves, obey robots.txt, keep
// to a per-host pace, cap response sizes and time, retry only what's worth
// retrying, and never follow a site off HTTPS.
import { ALLOW_ALL, DISALLOW_ALL, isAllowed, parseRobots, type RobotsRules } from './robots.ts';

export const USER_AGENT = 'SaleLagiHaiBot/1.0 (+https://salelagihai.pk/bot)';
const PRODUCT_TOKEN = 'SaleLagiHaiBot';

export type FetchOptions = {
  /** Minimum time between requests to one host (robots Crawl-delay can raise it). */
  minIntervalMs?: number;
  timeoutMs?: number;
  maxBytes?: number;
  maxAttempts?: number;
};

export class FetchRefused extends Error {
  readonly reason: 'robots' | 'not-https' | 'too-large' | 'status' | 'network';
  readonly status: number | null;
  constructor(reason: FetchRefused['reason'], message: string, status: number | null = null) {
    super(message);
    this.name = 'FetchRefused';
    this.reason = reason;
    this.status = status;
  }
}

type Clock = { now(): number; sleep(ms: number): Promise<void> };
const realClock: Clock = {
  now: () => Date.now(),
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};

export class PoliteFetcher {
  private readonly robots = new Map<string, RobotsRules>();
  private readonly nextSlot = new Map<string, number>();
  private readonly http: typeof fetch;
  private readonly clock: Clock;
  private readonly options: Required<FetchOptions>;

  constructor(http: typeof fetch = fetch, clock: Clock = realClock, options: FetchOptions = {}) {
    this.http = http;
    this.clock = clock;
    this.options = {
      minIntervalMs: options.minIntervalMs ?? 2000,
      timeoutMs: options.timeoutMs ?? 20_000,
      maxBytes: options.maxBytes ?? 5 * 1024 * 1024,
      maxAttempts: options.maxAttempts ?? 3,
    };
  }

  /** GETs `url` as text, or throws FetchRefused. */
  async getText(url: string, accept = 'text/html,application/json;q=0.9,*/*;q=0.5'): Promise<string> {
    const target = new URL(url);
    if (target.protocol !== 'https:') throw new FetchRefused('not-https', `refusing ${target.protocol} URL`);
    const rules = await this.rulesFor(target);
    if (!isAllowed(rules, target.pathname + target.search)) {
      throw new FetchRefused('robots', `robots.txt disallows ${target.pathname}`);
    }
    return this.request(target, accept, rules);
  }

  /** Is this deal link still there? 404/410 = broken; anything we can't
   * tell (network, robots, server errors) = unknown, never broken. */
  async check(url: string): Promise<'ok' | 'broken' | 'unknown'> {
    try {
      await this.getText(url);
      return 'ok';
    } catch (error) {
      if (error instanceof FetchRefused && error.reason === 'status' && (error.status === 404 || error.status === 410)) {
        return 'broken';
      }
      return 'unknown';
    }
  }

  async getJson<T>(url: string): Promise<T> {
    return JSON.parse(await this.getText(url, 'application/json')) as T;
  }

  private async rulesFor(target: URL): Promise<RobotsRules> {
    const cached = this.robots.get(target.host);
    if (cached) return cached;
    let rules: RobotsRules;
    try {
      const text = await this.request(new URL('/robots.txt', target), 'text/plain', ALLOW_ALL, 1);
      rules = parseRobots(text, PRODUCT_TOKEN);
    } catch (error) {
      // 4xx (no robots.txt): allowed. Anything else: don't crawl yet.
      const status = error instanceof FetchRefused ? error.status : null;
      rules = status !== null && status >= 400 && status < 500 ? ALLOW_ALL : DISALLOW_ALL;
    }
    this.robots.set(target.host, rules);
    return rules;
  }

  /** Waits for this host's next slot, then reserves the one after it. */
  private async pace(host: string, rules: RobotsRules) {
    const interval = Math.max(this.options.minIntervalMs, (rules.crawlDelaySeconds ?? 0) * 1000);
    const now = this.clock.now();
    const slot = Math.max(now, this.nextSlot.get(host) ?? 0);
    this.nextSlot.set(host, slot + interval);
    if (slot > now) await this.clock.sleep(slot - now);
  }

  private async request(target: URL, accept: string, rules: RobotsRules, attempts = this.options.maxAttempts): Promise<string> {
    let redirects = 0;
    for (let attempt = 1; ; attempt++) {
      await this.pace(target.host, rules);
      let response: Response;
      try {
        response = await this.http(target, {
          headers: { 'user-agent': USER_AGENT, accept },
          redirect: 'manual',
          signal: AbortSignal.timeout(this.options.timeoutMs),
        });
      } catch (error) {
        if (attempt >= attempts) throw new FetchRefused('network', `network error: ${(error as Error).name}`);
        await this.clock.sleep(1000 * 2 ** attempt);
        continue;
      }

      // Follow same-site HTTPS redirects only, up to 5 hops.
      if (response.status >= 300 && response.status < 400 && response.headers.get('location')) {
        const next = new URL(response.headers.get('location')!, target);
        if (next.protocol !== 'https:') throw new FetchRefused('not-https', 'redirect off HTTPS');
        if (next.host !== target.host) throw new FetchRefused('status', `redirect to another host: ${next.host}`, response.status);
        if (++redirects > 5) throw new FetchRefused('status', 'too many redirects', response.status);
        target = next;
        attempt--; // a redirect is not a failed attempt
        continue;
      }

      if (response.status === 429 || response.status >= 500) {
        if (attempt >= attempts) throw new FetchRefused('status', `HTTP ${response.status}`, response.status);
        const retryAfter = Number(response.headers.get('retry-after'));
        const wait = Number.isFinite(retryAfter) && retryAfter > 0
          ? Math.min(retryAfter, 300) * 1000
          : 1000 * 2 ** attempt;
        await this.clock.sleep(wait);
        continue;
      }
      if (!response.ok) throw new FetchRefused('status', `HTTP ${response.status}`, response.status);

      const declared = Number(response.headers.get('content-length'));
      if (Number.isFinite(declared) && declared > this.options.maxBytes) {
        throw new FetchRefused('too-large', `response is ${declared} bytes`);
      }
      return await this.readCapped(response);
    }
  }

  private async readCapped(response: Response): Promise<string> {
    if (!response.body) return '';
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > this.options.maxBytes) {
        await reader.cancel();
        throw new FetchRefused('too-large', `response over ${this.options.maxBytes} bytes`);
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return new TextDecoder().decode(bytes);
  }
}
