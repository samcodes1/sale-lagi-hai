#!/usr/bin/env node
/*
 * Visual QA for the Flutter WEB build using Playwright's pre-installed Chromium.
 * Never run `playwright install`; `require('playwright')` and `chromium.launch()` work as-is.
 *
 * Usage:
 *   flutter build web --release --no-web-resources-cdn --dart-define-from-file=env/dev.json
 *   node .claude/skills/qa-testing/scripts/web_visual_qa.js \
 *     --dir build/web --out docs/qa/screens/1.6 \
 *     --routes "/,/gallery" --sizes 360x800,412x915 \
 *     --themes light,dark --locales en-PK,ur-PK [--text-scale 1,2] [--semantics] [--wasm]
 *
 *   --url http://host:port   test an already-running server instead of --dir
 *   --wait-ms 2500           extra settle time after the Flutter view appears
 *   --hash                   use #/route URLs (the default is the path URL strategy)
 *   --allow-host a.com,b.com external hosts that are expected (anything else is reported)
 *
 * What it checks or produces, per route × size × theme × locale × text scale:
 *   - a full-page PNG at <out>/<route>_<w>x<h>_<theme>_<locale>[_ts<scale>].png
 *   - console errors, uncaught page errors and failed requests (any → exit code 1)
 *   - external hosts contacted (for example fonts.gstatic.com means a runtime font fetch, which is a bug for us)
 *   - with --semantics: enables Flutter's semantics tree, dumps every node's role, name and size
 *     to <out>/<shot>.semantics.json, and flags unlabeled interactive nodes and targets under 48px (hints)
 *   - report.json and report.md summaries in <out>
 *
 * How the modes are emulated: Playwright sets prefers-color-scheme (ThemeMode.system follows it),
 * navigator.language (Flutter picks the locale from supportedLocales), prefers-reduced-motion,
 * and the root font-size for text scale (Flutter web derives its text scale from it). It also
 * appends ?qa_locale=..&qa_theme=..&qa_text_scale=.. so a dev-flavor QA hook can force them if
 * the app stores a user-chosen locale or theme.
 */
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

function parseArgs(argv) {
  const a = { routes: '/', sizes: '360x800,412x915', themes: 'light,dark', locales: 'en-PK,ur-PK',
    'text-scale': '1', 'wait-ms': '2500', out: 'qa-screens', 'allow-host': '' };
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i].replace(/^--/, '');
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) a[k] = true; else { a[k] = next; i++; }
  }
  return a;
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2', '.webp': 'image/webp' };

function serve(dir, { crossOriginIsolated }) {
  const root = path.resolve(dir);
  const server = http.createServer((req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let file = path.join(root, urlPath);
    if (!file.startsWith(root)) { res.writeHead(403); return res.end(); }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      const idx = path.join(file, 'index.html');
      file = fs.existsSync(idx) ? idx : path.join(root, 'index.html'); // SPA fallback for path URLs
    }
    const headers = { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' };
    if (crossOriginIsolated) { // needed for multi-threaded skwasm (--wasm)
      headers['Cross-Origin-Opener-Policy'] = 'same-origin';
      headers['Cross-Origin-Embedder-Policy'] = 'require-corp';
    }
    res.writeHead(200, headers);
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

const slug = (s) => (s === '/' ? 'home' : s.replace(/^[#/]+/, '').replace(/[^a-zA-Z0-9]+/g, '-')) || 'home';

async function enableSemantics(page) {
  // Flutter web builds the DOM semantics tree only after the hidden placeholder is activated.
  const ph = page.locator('flt-semantics-placeholder');
  if (await ph.count()) await ph.first().dispatchEvent('click');
  await page.waitForTimeout(800);
}

async function dumpSemantics(page) {
  // Only nodes that carry a role or an accessible name. Rect sizes are hints: the authoritative
  // tap-target and label checks are flutter_test's meetsGuideline() matchers in widget tests.
  return page.evaluate(() => {
    const interactive = new Set(['button', 'link', 'checkbox', 'switch', 'tab', 'slider', 'textbox', 'menuitem', 'radio']);
    const nodes = [];
    for (const el of document.querySelectorAll('[role], [aria-label]')) {
      const role = el.getAttribute('role') || '';
      const name = (el.getAttribute('aria-label') || (el.childElementCount === 0 ? el.textContent : '') || '').trim();
      const r = el.getBoundingClientRect();
      nodes.push({ role, name: name.slice(0, 160), w: Math.round(r.width), h: Math.round(r.height),
        unlabeledInteractive: interactive.has(role) && !name,
        smallTarget: interactive.has(role) && r.width > 0 && (r.width < 48 || r.height < 48) });
    }
    return nodes;
  });
}

(async () => {
  const args = parseArgs(process.argv);
  const routes = String(args.routes).split(',').map((s) => s.trim()).filter(Boolean);
  const sizes = String(args.sizes).split(',').map((s) => s.split('x').map(Number));
  const themes = String(args.themes).split(',');
  const locales = String(args.locales).split(',');
  const scales = String(args['text-scale']).split(',').map(Number);
  const allowHosts = new Set(String(args['allow-host']).split(',').filter(Boolean));
  fs.mkdirSync(args.out, { recursive: true });

  let server; let base = args.url;
  if (!base) {
    if (!args.dir) throw new Error('pass --dir build/web or --url');
    server = await serve(args.dir, { crossOriginIsolated: !!args.wasm });
    base = `http://127.0.0.1:${server.address().port}`;
  }
  const baseHost = new URL(base).host;
  const browser = await chromium.launch();
  const results = [];

  for (const route of routes) for (const [w, h] of sizes) for (const theme of themes)
  for (const locale of locales) for (const scale of scales) {
    const name = `${slug(route)}_${w}x${h}_${theme}_${locale}${scale !== 1 ? `_ts${scale}` : ''}`;
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2,
      isMobile: true, hasTouch: true, colorScheme: theme, locale, reducedMotion: 'reduce' });
    if (scale !== 1) {
      await ctx.addInitScript((px) => {
        document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = px; });
      }, `${16 * scale}px`);
    }
    const page = await ctx.newPage();
    const issues = { consoleErrors: [], pageErrors: [], failedRequests: [], externalHosts: new Set() };
    page.on('console', (m) => { if (m.type() === 'error') issues.consoleErrors.push(m.text().slice(0, 300)); });
    page.on('pageerror', (e) => issues.pageErrors.push(String(e).slice(0, 300)));
    page.on('requestfailed', (r) => issues.failedRequests.push(`${r.url()} ${r.failure()?.errorText}`));
    page.on('request', (r) => { const host = new URL(r.url()).host; if (host && host !== baseHost) issues.externalHosts.add(host); });

    const q = `qa_locale=${encodeURIComponent(locale)}&qa_theme=${theme}&qa_text_scale=${scale}`;
    const target = args.hash ? `${base}/?${q}#${route}` : `${base}${route}${route.includes('?') ? '&' : '?'}${q}`;
    const t0 = Date.now();
    let loadError = null;
    try {
      await page.goto(target, { waitUntil: 'load', timeout: 60000 });
      await page.waitForSelector('flutter-view, flt-glass-pane', { state: 'attached', timeout: 60000 });
      await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
      await page.waitForTimeout(Number(args['wait-ms']));
    } catch (e) { loadError = String(e).slice(0, 300); }
    const loadMs = Date.now() - t0;
    const shot = path.join(args.out, `${name}.png`);
    await page.screenshot({ path: shot, fullPage: false });

    let semantics = null;
    if (args.semantics && !loadError) {
      await enableSemantics(page);
      const nodes = await dumpSemantics(page);
      fs.writeFileSync(path.join(args.out, `${name}.semantics.json`), JSON.stringify(nodes, null, 2));
      semantics = { nodes: nodes.length,
        unlabeledInteractive: nodes.filter((n) => n.unlabeledInteractive).length,
        smallTargets: nodes.filter((n) => n.smallTarget).length };
    }
    const unexpectedHosts = [...issues.externalHosts].filter((x) => !allowHosts.has(x));
    results.push({ name, route, size: `${w}x${h}`, theme, locale, scale, screenshot: shot, loadMs, loadError,
      consoleErrors: issues.consoleErrors, pageErrors: issues.pageErrors, failedRequests: issues.failedRequests,
      unexpectedHosts, semantics });
    await ctx.close();
    console.log(`${loadError || issues.pageErrors.length ? 'FAIL' : 'ok  '} ${name} (${loadMs} ms)` +
      (unexpectedHosts.length ? ` external: ${unexpectedHosts.join(',')}` : ''));
  }

  await browser.close();
  if (server) server.close();
  fs.writeFileSync(path.join(args.out, 'report.json'), JSON.stringify(results, null, 2));
  const md = ['| Shot | Load ms | Console errors | Page errors | Unexpected hosts | Semantics (unlabeled/small) |', '|---|---|---|---|---|---|',
    ...results.map((r) => `| ${r.name} | ${r.loadMs}${r.loadError ? ' ⚠' : ''} | ${r.consoleErrors.length} | ${r.pageErrors.length} | ${r.unexpectedHosts.join(', ') || '-'} | ${r.semantics ? `${r.semantics.unlabeledInteractive}/${r.semantics.smallTargets}` : '-'} |`)];
  fs.writeFileSync(path.join(args.out, 'report.md'), md.join('\n') + '\n');
  const failed = results.filter((r) => r.loadError || r.pageErrors.length || r.consoleErrors.length);
  console.log(`\n${results.length} screenshots, ${failed.length} with errors → ${path.join(args.out, 'report.md')}`);
  process.exit(failed.length ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(2); });
