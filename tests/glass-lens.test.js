import test from 'node:test';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';
import { JSDOM } from 'jsdom';
import { createGlassLens } from '../src/glass-lens.js';
import { GLASS_DISPLACEMENT_MAP } from '../src/glass-map.js';

test('lens map follows the actual dock size and disconnects on unmount', t => {
  const dom = new JSDOM('<div id="app"><svg><filter id="timer-glass-lens"><feImage width="440" height="224"/></filter></svg><section class="timer-panel"></section></div>');
  t.after(() => dom.window.close());
  const root = dom.window.document.querySelector('#app');
  let size = { width: 390, height: 278 };
  root.querySelector('section').getBoundingClientRect = () => size;
  let resize, disconnected = false;
  dom.window.ResizeObserver = class {
    constructor(fn) { resize = fn; }
    observe(element) { assert.equal(element, root.querySelector('section')); }
    disconnect() { disconnected = true; }
  };
  const lens = createGlassLens(root);
  const map = root.querySelector('feImage');
  assert.equal(map.getAttribute('width'), '390');
  assert.equal(map.getAttribute('height'), '278');
  size = { width: 560, height: 300 }; resize();
  assert.equal(map.getAttribute('width'), '560');
  assert.equal(map.getAttribute('height'), '300');
  size = { width: 0, height: 0 }; resize();
  assert.equal(map.getAttribute('width'), '560');
  lens.destroy();
  assert.equal(disconnected, true);
  size = { width: 800, height: 400 };
  dom.window.dispatchEvent(new dom.window.Event('resize'));
  assert.equal(map.getAttribute('width'), '560');
});

test('embedded map is opaque, bends the top outward, and leaves the lower pane neutral', () => {
  const png = Buffer.from(GLASS_DISPLACEMENT_MAP.split(',')[1], 'base64');
  let width, height; const compressed = [];
  for (let offset = 8; offset < png.length;) {
    const length = png.readUInt32BE(offset);
    const type = png.toString('ascii', offset + 4, offset + 8);
    const data = png.subarray(offset + 8, offset + 8 + length);
    if (type === 'IHDR') { width = data.readUInt32BE(0); height = data.readUInt32BE(4); }
    if (type === 'IDAT') compressed.push(data);
    offset += length + 12;
  }
  const rows = inflateSync(Buffer.concat(compressed));
  const pixel = (x, y) => [...rows.subarray(y * (width * 4 + 1) + 1 + x * 4, y * (width * 4 + 1) + 5 + x * 4)];
  assert.ok(pixel(width / 2, 0)[1] < 128, 'top samples outside the pane rather than inward');
  for (let y = 0; y < height; y++) {
    assert.equal(rows[y * (width * 4 + 1)], 0);
    for (let x = 0; x < width; x++) {
      const rgba = pixel(x, y);
      assert.equal(rgba[3], 255, 'map must not introduce transparent gaps');
      if (y >= 42) assert.deepEqual(rgba, [128, 128, 128, 255], 'no displacement on sides or bottom');
    }
  }
});
