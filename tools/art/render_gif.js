// Captura fotogramas de un SVG animado (SMIL) a PNGs. Uso:
//   NODE_PATH=... node tools/art/render_gif.js in.svg out_dir fps segundos
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [svgPath, dir, fps = '12', secs = '3'] = process.argv.slice(2);
  const svg = fs.readFileSync(svgPath, 'utf8');
  const m = svg.match(/viewBox="0 0 (\d+) (\d+)"/);
  fs.mkdirSync(dir, { recursive: true });
  const b = await chromium.launch({ args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: +m[1], height: +m[2] } });
  await p.setContent(`<body style="margin:0">${svg}</body>`);
  const total = Math.round(+fps * +secs);
  for (let i = 0; i < total; i++) {
    await p.evaluate(t => { const s = document.querySelector('svg'); s.pauseAnimations(); s.setCurrentTime(t); }, i / +fps);
    await p.screenshot({ path: `${dir}/f${String(i).padStart(3, '0')}.png` });
  }
  await b.close();
  console.log(total + ' fotogramas');
})().catch(e => { console.error(e); process.exit(1); });
