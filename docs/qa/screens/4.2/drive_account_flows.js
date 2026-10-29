// Drives the account flows in the web build and screenshots each state.
// node drive.js <build/web> <outdir> [filter]
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const [root, out, only] = [path.resolve(process.argv[2]), process.argv[3], process.argv[4] || ''];
fs.mkdirSync(out, { recursive: true });
const MIME = { '.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.wasm':'application/wasm','.css':'text/css','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.ico':'image/x-icon','.woff2':'font/woff2','.svg':'image/svg+xml' };
const server = http.createServer((req, res) => {
  let f = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!f.startsWith(root)) { res.writeHead(403); return res.end(); }
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': MIME[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});
const L = {
  en: { profile: 'Profile', signIn: 'Sign in', send: 'Send code', del: 'Delete account', delMine: 'Delete my account' },
  ur: { profile: null, signIn: null, send: null, del: null, delMine: null },
};
const report = [];
server.listen(0, '127.0.0.1', async () => {
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  for (const [w, h] of [[360, 800], [412, 915]]) for (const theme of ['light', 'dark'])
  for (const lang of ['en', 'ur']) for (const scale of [1, 2]) {
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
    page.on('console', (m) => { if (m.type() === 'error') issues.push('console: ' + m.text().slice(0, 200)); });
    page.on('pageerror', (e) => issues.push('pageerror: ' + String(e).slice(0, 200)));
    page.on('request', (r) => { const host = new URL(r.url()).host; if (host && !host.startsWith('127.0.0.1')) hosts.add(host); });
    const shot = async (name) => {
      await page.waitForTimeout(700);
      await page.screenshot({ path: path.join(out, `${name}_${tag}.png`) });
    };
    const sem = async () => page.evaluate(() => [...document.querySelectorAll('[role],[aria-label]')]
      .map((e) => ({ role: e.getAttribute('role'), name: (e.getAttribute('aria-label') || e.textContent || '').trim(),
        r: e.getBoundingClientRect().toJSON() })));
    // Click the n-th node with this role (and optional name test).
    const click = async (role, test) => {
      const nodes = await page.$$(`[role="${role}"]`);
      for (const n of nodes) {
        const name = ((await n.getAttribute('aria-label')) || (await n.textContent()) || '').trim();
        if (!test || test(name)) { await n.click(); await page.waitForTimeout(900); return name; }
      }
      throw new Error(`no ${role} matching`);
    };
    const type = async (text) => {
      const box = page.locator('input, textarea').first();
      await box.click({ timeout: 3000 }).catch(async () => {
        await box.click({ force: true, timeout: 3000 }).catch(() => box.focus());
      });
      await page.waitForTimeout(300);
      await page.keyboard.press('End');
      for (let i = 0; i < 20; i++) await page.keyboard.press('Backspace');
      await page.keyboard.type(text, { delay: 30 });
    };
    try {
      await page.goto(base + '/', { waitUntil: 'load' });
      await page.waitForSelector('flutter-view', { state: 'attached' });
      await page.waitForTimeout(3000);
      await page.locator('flt-semantics-placeholder').first().dispatchEvent('click').catch(() => {});
      await page.waitForTimeout(800);
      // Profile is the last tab.
      const tabs = await page.$$('[role="tab"]');
      await tabs[tabs.length - 1].click();
      await page.waitForTimeout(1200);
      await shot('profile-guest');
      // The first button on the guest profile is "Sign in".
      await click('button');
      await page.waitForTimeout(800);
      await shot('sign-in-phone');
      await type('021 3456789');
      await click('button', (n) => /Send code|کوڈ/.test(n));
      await shot('sign-in-phone-error');
      await type('0300 1234567');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(1200);
      await shot('sign-in-code');
      await type('000000');
      await page.waitForTimeout(1200);
      await shot('sign-in-code-error');
      await type('123456');
      await page.waitForTimeout(2000);
      await shot('profile-signed-in');
      report.push({ tag, semanticsProfile: (await sem()).filter((n) => ['button', 'link', 'textbox', 'tab'].includes(n.role))
        .map((n) => `${n.role}:${n.name.slice(0, 40)}:${Math.round(n.r.width)}x${Math.round(n.r.height)}`) });
      // Delete account: the last button on the profile list that mentions delete.
      await click('button', (n) => /^(Delete account|اکاؤنٹ ڈیلیٹ کریں)$/.test(n));
      await shot('delete');
      await page.mouse.wheel(0, 2000);
      await page.waitForTimeout(500);
      await shot('delete-bottom');
      await click('button', (n) => /Delete my account|میرا اکاؤنٹ/.test(n));
      await shot('delete-dialog');
      // Confirm (the dialog's second button).
      const dlg = await page.$$('[role="button"]');
      await dlg[dlg.length - 1].click();
      await page.waitForTimeout(2500);
      await shot('after-delete');
    } catch (e) {
      issues.push('driver: ' + String(e).slice(0, 200));
      await page.screenshot({ path: path.join(out, `FAILED_${tag}.png`) });
    }
    report.push({ tag, issues, hosts: [...hosts] });
    await ctx.close();
  }
  fs.writeFileSync(path.join(out, 'drive-report.json'), JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.filter((r) => r.issues), null, 1));
  await browser.close(); server.close();
});
