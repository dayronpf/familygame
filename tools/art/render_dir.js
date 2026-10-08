// Convierte todos los .svg de un directorio a .png con Chromium (Playwright). Uso:
//   NODE_PATH=<node_modules con playwright> node tools/art/render_dir.js dir_svgs dir_pngs
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [src, dst] = process.argv.slice(2);
  fs.mkdirSync(dst, { recursive: true });
  const b = await chromium.launch({ args: ['--no-sandbox'] });
  let p = null;
  for (const f of fs.readdirSync(src).filter(f => f.endsWith('.svg')).sort()) {
    const svg = fs.readFileSync(`${src}/${f}`, 'utf8');
    const m = svg.match(/viewBox="0 0 (\d+) (\d+)"/);
    if (!p) p = await b.newPage({ viewport: { width: +m[1], height: +m[2] } });
    await p.setContent(`<body style="margin:0">${svg}</body>`);
    await p.screenshot({ path: `${dst}/${f.replace('.svg', '.png')}` });
  }
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
