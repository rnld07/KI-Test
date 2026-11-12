const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const D = __dirname;
(async () => {
  const mode = process.argv[2] || 'test';
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.setDefaultTimeout(0);
  p.on('console', m => console.log('[page]', m.text()));
  p.on('pageerror', e => console.log('[pageerror]', e.message));
  await p.goto('file://' + path.join(D, 'render.html'));
  await p.evaluate(async () => { await document.fonts.load('700 40px Inter'); await document.fonts.load('400 40px Inter'); await document.fonts.load('600 40px Inter'); await document.fonts.load('500 40px Inter'); });
  const r = await p.evaluate(([a, bb, cc]) => window.initGL(a, bb, cc), [fs.readFileSync(path.join(D, 'macro.glsl'), 'utf8'), fs.readFileSync(path.join(D, 'phone.glsl'), 'utf8'), fs.readFileSync(path.join(D, 'dof.glsl'), 'utf8')]);
  console.log('init', r);
  if (mode === 'test') {
    const times = process.argv.slice(3).map(Number);
    fs.mkdirSync(path.join(D, 'test'), { recursive: true });
    for (const t of times) {
      const t0 = Date.now();
      await p.evaluate(t => window.renderFrame(t), t);
      await p.screenshot({ path: path.join(D, 'test', `t${t.toFixed(2)}.jpg`), type: 'jpeg', quality: 90 });
      console.log('t', t, Date.now() - t0, 'ms');
    }
  } else if (mode === 'dbg') {
    fs.mkdirSync(path.join(D, 'test'), { recursive: true });
    const list = JSON.parse(process.argv[3]);
    for (const [i, st] of list.entries()) {
      await p.evaluate(st => { window.DBG = st; window.renderFrame(30); }, st);
      await p.screenshot({ path: path.join(D, 'test', `dbg${i}.jpg`), type: 'jpeg', quality: 90 });
    }
  } else if (mode === 'events') {
    fs.writeFileSync(path.join(D, 'events.json'), JSON.stringify(await p.evaluate(() => window.events())));
  } else {
    // full render: args start end out
    const fps = 30, start = +process.argv[3], end = +process.argv[4], out = process.argv[5];
    const ff = spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '14', '-pix_fmt', 'yuv420p', '-r', String(fps), out], { stdio: ['pipe', 'inherit', 'inherit'] });
    const t0 = Date.now();
    for (let f = start; f < end; f++) {
      const t = f / fps;
      await p.evaluate(t => window.renderFrame(t), t);
      const buf = await p.screenshot({ type: 'jpeg', quality: 95 });
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      if (f % 60 === 0) console.log(out, 'frame', f, ((Date.now() - t0) / 1000).toFixed(0) + 's');
    }
    ff.stdin.end();
    await new Promise(r => ff.on('close', r));
  }
  await b.close();
})();
