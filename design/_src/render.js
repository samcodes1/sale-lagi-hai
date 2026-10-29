// Batch SVG/HTML -> PNG renderer. Usage: node render.js jobs.json
// job: {svg|html: path, out: path, w, h, transparent?: bool, scale?: number}
const {chromium} = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const b = await chromium.launch();
  for (const j of jobs) {
    const p = await b.newPage({viewport: {width: j.w, height: j.h}, deviceScaleFactor: j.scale || 1});
    if (j.svg) {
      const svg = fs.readFileSync(j.svg, 'utf8');
      await p.setContent(`<html><head><style>html,body{margin:0;padding:0;background:transparent}svg{display:block;width:${j.w}px;height:${j.h}px}</style></head><body>${svg}</body></html>`);
    } else {
      await p.goto('file://' + path.resolve(j.html));
    }
    await p.waitForTimeout(j.wait || 150);
    await p.screenshot({path: j.out, omitBackground: !!j.transparent, fullPage: !!j.full, clip: j.full ? undefined : {x: 0, y: 0, width: j.w, height: j.h}});
    await p.close();
  }
  await b.close();
})();
