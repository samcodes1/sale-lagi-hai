// QA 4.9: drives the Settings pages in the web build and screenshots each.
// node drive_settings.js <build/web> <outdir> [filter]
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const [root, out, only] = [path.resolve(process.argv[2]), process.argv[3], process.argv[4] || ''];
fs.mkdirSync(out, { recursive: true });
const MIME = { '.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.wasm':'application/wasm','.css':'text/css','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.ico':'image/x-icon','.woff2':'font/woff2','.svg':'image/svg+xml','.txt':'text/plain' };
const server = http.createServer((req, res) => {
  let f = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!f.startsWith(root)) { res.writeHead(403); return res.end(); }
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': MIME[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});
const report = [];
server.listen(0, '127.0.0.1', async () => {
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  const modes = [];
  for (const theme of ['light', 'dark']) for (const lang of ['en', 'ur']) for (const scale of [1, 2]) modes.push([360, 800, theme, lang, scale]);
  for (const theme of ['light', 'dark']) for (const lang of ['en', 'ur']) modes.push([412, 915, theme, lang, 1]);
  for (const [w, h, theme, lang, scale] of modes) {
    const tag = `${w}x${h}_${theme}_${lang}${scale !== 1 ? '_ts2' : ''}`;
    if (only && !tag.includes(only)) continue;
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2, isMobile: true,
      hasTouch: true, colorScheme: theme, locale: lang === 'ur' ? 'ur-PK' : 'en-PK', reducedMotion: 'reduce' });
    await ctx.addInitScript(([lang, px]) => {
      if (!sessionStorage.getItem('seeded')) {
        sessionStorage.setItem('seeded', '1');
        localStorage.setItem('slh.preferences.v1', JSON.stringify(JSON.stringify({ onboarded: true,
          city_id: '00000000-0000-4000-a000-000000000001', interest_ids: [], brand_ids: [], alerts_asked_at: null })));
        localStorage.setItem('slh.settings.locale', JSON.stringify(lang));
      }
      if (px) document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = px; });
    }, [lang, scale !== 1 ? `${16 * scale}px` : null]);
    const page = await ctx.newPage();
    const issues = [];
    const hosts = new Set();
    const shots = [];
    page.on('console', (m) => { if (m.type() === 'error') issues.push('console: ' + m.text().slice(0, 200)); });
    let step = 'start';
    page.on('pageerror', (e) => issues.push(`pageerror at ${step}: ` + String(e && (e.stack || e.message) || e).slice(0, 300)));
    page.on('request', (r) => { const host = new URL(r.url()).host; if (host && !host.startsWith('127.0.0.1')) hosts.add(host); });
    const shot = async (name) => {
      step = name;
      await page.waitForTimeout(700);
      const file = `${name}_${tag}.png`;
      await page.screenshot({ path: path.join(out, file) });
      shots.push(file);
    };
    const nodes = async () => page.evaluate(() => [...document.querySelectorAll('[role],[aria-label]')]
      .map((e) => ({ role: e.getAttribute('role'), name: (e.getAttribute('aria-label') || e.textContent || '').trim(),
        r: e.getBoundingClientRect().toJSON() })));
    const click = async (role, test) => {
      const all = await page.$$(`[role="${role}"]`);
      for (const n of all) {
        const name = ((await n.getAttribute('aria-label')) || (await n.textContent()) || '').trim();
        if (!test || test(name)) { await n.scrollIntoViewIfNeeded().catch(() => {}); await n.click(); await page.waitForTimeout(900); return name; }
      }
      throw new Error(`no ${role} matching ${test}`);
    };
    const type = async (text) => {
      const box = page.locator('input, textarea').first();
      await box.click({ timeout: 3000 }).catch(async () => { await box.click({ force: true, timeout: 3000 }).catch(() => box.focus()); });
      await page.waitForTimeout(300);
      await page.keyboard.press('End');
      for (let i = 0; i < 20; i++) await page.keyboard.press('Backspace');
      await page.keyboard.type(text, { delay: 30 });
    };
    // In-app navigation without a reload (hash URLs; the demo sign-in lives in memory).
    const go = async (route) => {
      await page.evaluate((r) => { location.hash = '#' + r; }, route);
      await page.waitForTimeout(1500);
      step = 'after go ' + route;
    };
    const bottom = async () => { await page.mouse.move(w / 2, h / 2); for (let i = 0; i < 6; i++) { await page.mouse.wheel(0, 600); await page.waitForTimeout(150); } await page.waitForTimeout(500); };
    const mid = async () => { await page.mouse.move(w / 2, h / 2); await page.mouse.wheel(0, Math.round(h * 0.6)); await page.waitForTimeout(600); };
    try {
      await page.goto(base + '/', { waitUntil: 'load' });
      await page.waitForSelector('flutter-view', { state: 'attached' });
      await page.waitForTimeout(3000);
      await page.locator('flt-semantics-placeholder').first().dispatchEvent('click').catch(() => {});
      await page.waitForTimeout(800);
      await go('/settings');
      await shot('settings');
      report.push({ tag, page: 'settings', nodes: (await nodes()).filter((n) => ['button', 'radio', 'heading', 'switch', 'checkbox'].includes(n.role))
        .map((n) => `${n.role}:${n.name.slice(0, 40)}:${Math.round(n.r.width)}x${Math.round(n.r.height)}`) });
      await bottom();
      await shot('settings-bottom');
      await go('/settings/notifications');
      await shot('notif-guest');
      await go('/settings/legal/cookies');
      await shot('legal-redirect');
      await go('/settings/legal/terms');
      await shot('terms');
      await go('/settings/legal/privacy');
      await shot('privacy-policy');
      await bottom();
      await shot('privacy-policy-bottom');
      await go('/settings/about');
      await shot('about');
      // Sign in (demo OTP), then the signed-in pages.
      await go('/profile');
      await click('button');
      step = 'sign-in';
      await type('0300 1234567');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(1500);
      await type('123456');
      await page.waitForTimeout(2500);
      await go('/settings/notifications');
      await shot('notif');
      report.push({ tag, page: 'notifications', nodes: (await nodes()).filter((n) => ['button', 'radio', 'heading', 'switch', 'checkbox'].includes(n.role))
        .map((n) => `${n.role}:${n.name.slice(0, 40)}:${Math.round(n.r.width)}x${Math.round(n.r.height)}`) });
      await mid();
      await shot('notif-mid');
      await bottom();
      await shot('notif-bottom');
      // Quiet hours: open the start picker.
      await click('button', (n) => /^(From|سے)|سے$|From /.test(n) || /^\d.*سے/.test(n)).catch(async () => {
        // Fallback: the second-to-last tappable in the list.
        const all = await page.$$('[role="button"]'); await all[all.length - 2].click(); await page.waitForTimeout(900);
      });
      await shot('quiet-picker');
      await page.keyboard.press('Escape');
      await page.waitForTimeout(800);
      await go('/settings/privacy');
      await shot('privacy');
      await bottom();
      await shot('privacy-bottom');
      await click('button', (n) => /Clear everything|سب کچھ/.test(n)).catch((e) => issues.push('driver: clear phone ' + e));
      await shot('clear-dialog');
    } catch (e) {
      issues.push('driver: ' + String(e).slice(0, 200));
      await page.screenshot({ path: path.join(out, `FAILED_${tag}.png`) });
    }
    report.push({ tag, issues, hosts: [...hosts], shots: shots.length });
    await ctx.close();
  }
  fs.writeFileSync(path.join(out, 'drive-report.json'), JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.filter((r) => r.issues), null, 1));
  await browser.close(); server.close();
});
