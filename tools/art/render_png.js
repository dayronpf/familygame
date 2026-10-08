// Renderiza un SVG a PNG con Chromium (Playwright). Uso:
//   NODE_PATH=<ruta a node_modules con playwright> node tools/art/render_png.js in.svg out.png [escala]
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [svgPath, pngPath, scale = '1'] = process.argv.slice(2);
  const svg = fs.readFileSync(svgPath, 'utf8');
  const m = svg.match(/viewBox="0 0 (\d+) (\d+)"/);
  const b = await chromium.launch({ args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: +m[1], height: +m[2] }, deviceScaleFactor: +scale });
  await p.setContent(`<body style="margin:0">${svg}</body>`);
  await p.screenshot({ path: pngPath });
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
