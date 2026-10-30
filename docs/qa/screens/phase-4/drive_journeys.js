// QA Phase 4 gate: drives the cross-sub-phase journeys in the release web
// build and screenshots each step.
// node drive_journeys.js <build/web> <outdir>
// J1 first launch → onboarding → Home → deal → Save → Saved;
// J4 offline (browser offline) → Home, Saved, a deal → back online;
// J5 language switch on Profile → RTL across tabs; J6 search.
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const [root, out] = [path.resolve(process.argv[2]), process.argv[3]];
fs.mkdirSync(out, { recursive: true });
const MIME = { '.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.wasm':'application/wasm','.css':'text/css','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.ico':'image/x-icon','.woff2':'font/woff2','.svg':'image/svg+xml','.txt':'text/plain' };
const server = http.createServer((req, res) => {
  let f = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!f.startsWith(root)) { res.writeHead(403); return res.end(); }
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': MIME[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});
const deal = (n) => `00000000-0000-4000-0006-${String(n).padStart(12, '0')}`;
const report = [];
server.listen(0, '127.0.0.1', async () => {
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  const modes = [
    [360, 800, 'light', 'en', 1], [360, 800, 'dark', 'ur', 1],
    [360, 800, 'light', 'ur', 2], [412, 915, 'dark', 'en', 1],
  ];
  for (const [w, h, theme, lang, scale] of modes) {
    const tag = `${w}x${h}_${theme}_${lang}${scale !== 1 ? '_ts2' : ''}`;
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2, isMobile: true,
      hasTouch: true, colorScheme: theme, locale: lang === 'ur' ? 'ur-PK' : 'en-PK', reducedMotion: 'reduce' });
    await ctx.addInitScript((px) => {
      if (px) document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = px; });
    }, scale !== 1 ? `${16 * scale}px` : null);
    const page = await ctx.newPage();
    const issues = [], hosts = new Set(), steps = [];
    let step = 'start';
    page.on('console', (m) => { if (m.type() === 'error') issues.push(`console at ${step}: ` + m.text().slice(0, 200)); });
    page.on('pageerror', (e) => issues.push(`pageerror at ${step}: ` + String(e && (e.stack || e.message) || e).slice(0, 300)));
    page.on('request', (r) => { const host = new URL(r.url()).host; if (host && !host.startsWith('127.0.0.1')) hosts.add(host); });
    const shot = async (name) => {
      step = name;
      await page.waitForTimeout(800);
      await page.screenshot({ path: path.join(out, `${name}_${tag}.png`) });
      steps.push(name);
    };
    const names = async () => page.evaluate(() => [...document.querySelectorAll('[role],[aria-label],flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean));
    const click = async (re, role = 'button') => {
      const all = await page.$$(role === 'any' ? '[role]' : `[role="${role}"]`);
      for (const n of all) {
        const name = ((await n.getAttribute('aria-label')) || (await n.textContent()) || '').trim();
        if (re.test(name)) { await n.scrollIntoViewIfNeeded().catch(() => {}); await n.click(); await page.waitForTimeout(1000); return name; }
      }
      throw new Error(`no ${role} matching ${re} at ${step}`);
    };
    const go = async (route) => {
      await page.evaluate((r) => { location.hash = '#' + r; }, route);
      await page.waitForTimeout(1500);
      step = 'after go ' + route;
    };
    const has = async (re) => (await names()).some((n) => re.test(n));
    const checks = {};
    try {
      await page.goto(base + '/', { waitUntil: 'load' });
      await page.waitForSelector('flutter-view', { state: 'attached' });
      await page.waitForTimeout(3000);
      await page.locator('flt-semantics-placeholder').first().dispatchEvent('click').catch(() => {});
      await page.waitForTimeout(800);
      // J1: onboarding.
      await shot('j1-language');
      await click(/^(Continue|آگے چلیں)$/);
      await click(/^(Karachi|کراچی)/, 'any');
      await shot('j1-city');
      await click(/^(Continue|آگے چلیں)$/);
      await click(/^(Skip|چھوڑیں)$/);
      await click(/^(Skip|چھوڑیں)$/);
      await click(/^(Not now|ابھی نہیں)$/);
      await shot('j1-home');
      checks.home = await has(/Karachi|کراچی/);
      await go(`/deal/${deal(4)}`);
      await shot('j1-deal');
      await click(/^(Save|محفوظ کریں)$/, 'any');
      await shot('j1-deal-saved');
      await go('/saved');
      await shot('j1-saved');
      checks.savedListed = await has(/Winter collection sale|ونٹر/);
      // J4: offline, then back.
      await ctx.setOffline(true);
      await page.waitForTimeout(1500);
      await go('/');
      await shot('j4-home-offline');
      checks.offlineBanner = await has(/No internet|انٹرنیٹ نہیں/);
      await go('/saved');
      await shot('j4-saved-offline');
      await go(`/deal/${deal(4)}`);
      await shot('j4-saved-deal-offline');
      checks.savedDealOffline = await has(/Winter collection sale|ونٹر/);
      await ctx.setOffline(false);
      await page.waitForTimeout(2000);
      await go('/');
      await shot('j4-home-online');
      checks.bannerGone = !(await has(/No internet|انٹرنیٹ نہیں/));
      // J5: language switch on Profile.
      await go('/profile');
      await click(lang === 'ur' ? /^English$/ : /^اردو$/, 'any');
      await shot('j5-profile-switched');
      for (const r of ['/', '/explore', '/alerts', '/saved']) { await go(r); await shot(`j5-tab${r.replace(/\//g, '-') || '-home'}`); }
      checks.dir = await page.evaluate(() => [...document.querySelectorAll('[dir]')].map((e) => e.getAttribute('dir')).slice(0, 3));
      // J6: search.
      await go('/search?q=burger');
      await shot('j6-search');
    } catch (e) {
      issues.push(`flow error at ${step}: ${String(e.message || e).slice(0, 300)}`);
      await page.screenshot({ path: path.join(out, `error_${tag}.png`) }).catch(() => {});
    }
    report.push({ tag, steps, checks, issues, hosts: [...hosts] });
    await ctx.close();
  }
  await browser.close();
  server.close();
  fs.writeFileSync(path.join(out, 'journeys-report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.some((r) => r.issues.length) ? 1 : 0);
});
