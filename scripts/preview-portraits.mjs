// Standalone SVG contact sheets for artwork QA. Does not start a server.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { JSDOM } from 'jsdom';
import { createPortrait } from '../src/portrait.js';

const expressions = ['idle', 'happy', 'cute', 'angry', 'frustrated', 'bell'];
const output = process.argv[2] ?? path.join(os.tmpdir(), 'banke-portrait-previews');
fs.mkdirSync(output, { recursive: true });
for (const character of ['whale', 'claude', 'chatgpt']) {
  const dom = new JSDOM('<span></span>');
  const art = dom.window.document.querySelector('span');
  const portrait = createPortrait(art, character);
  art.querySelectorAll('image').forEach(image => image.dispatchEvent(new dom.window.Event('load')));
  let cells = '';
  expressions.forEach((expression, row) => {
    portrait.expression(expression);
    const path = `public/avatars/${character === 'whale' ? '' : `${character}/`}${expression}.webp`;
    const original = `<image width="512" height="512" href="data:image/webp;base64,${fs.readFileSync(path).toString('base64')}"/>`;
    for (let column = 0; column < 5; column++) {
      portrait.mouth(column === 4 ? 0 : Math.max(0, column - 1));
      portrait.blink(column === 4);
      const overlay = art.querySelector('svg').innerHTML
        .replace(/href="\/avatars\/([^"]+)"/g, (_, name) => `href="data:image/${name.endsWith('.webp') ? 'webp' : 'png'};base64,${fs.readFileSync(`public/avatars/${name}`).toString('base64')}"`)
        .replace(/portrait-\d+/g, `portrait-${character}-${row}-${column}`);
      cells += `<svg x="${column * 200}" y="${row * 156}" width="200" height="156" viewBox="165 105 160 125">${original}${column ? overlay : ''}</svg>`;
    }
  });
  fs.writeFileSync(path.join(output, `${character}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="936"><rect width="1000" height="936" fill="#eee"/>${cells}</svg>`);
  portrait.destroy(); dom.window.close();
}
console.log(output);
