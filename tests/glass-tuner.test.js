import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { createGlassTuner, normalizeGlass } from '../src/glass-tuner.js';

function setup(t, storage) {
  const dom = new JSDOM('<div id="app"><svg><filter id="timer-glass-lens"><feDisplacementMap scale="30"/></filter></svg></div>');
  const root = dom.window.document.querySelector('#app');
  let closes = 0;
  const tuner = createGlassTuner(root, { storage, onClose: () => closes++ });
  const $ = selector => root.querySelector(selector);
  t.after(() => { tuner.destroy(); dom.window.close(); });
  return { tuner, root, $, dom, closes: () => closes };
}

test('sliders apply live, export exact values, and restore the saved draft', t => {
  let saved;
  const storage = { setItem: (_, value) => { saved = value; }, getItem: () => saved };
  const { tuner, root, $, dom } = setup(t, storage);
  assert.equal(root.dataset.glassTuned, undefined);
  tuner.open();
  const input = $('[data-param=blurPx]');
  input.value = '10.5'; input.dispatchEvent(new dom.window.Event('input', { bubbles: true }));
  assert.equal(root.style.getPropertyValue('--glass-blur'), '10.5px');
  assert.equal(JSON.parse($('textarea').value).blurPx, 10.5);
  assert.equal(JSON.parse(saved).blurPx, 10.5);
  const restored = setup(t, storage);
  assert.equal(restored.root.style.getPropertyValue('--glass-blur'), '10.5px');
  assert.equal(restored.$('aside').hidden, true);
  $('[data-reset]').click();
  assert.equal(root.style.getPropertyValue('--glass-blur'), '6px');
});

test('JSON copies to the clipboard and remains manually selectable when clipboard access fails', async t => {
  const { tuner, $, dom } = setup(t);
  tuner.open();
  let copied;
  Object.defineProperty(dom.window.navigator, 'clipboard', { configurable: true, value: { writeText: async text => { copied = text; } } });
  $('[data-copy]').click(); await Promise.resolve();
  assert.deepEqual(JSON.parse(copied), { version: 1, ...normalizeGlass() });
  dom.window.navigator.clipboard.writeText = async () => { throw new Error('Denied'); };
  $('[data-copy]').click(); await Promise.resolve();
  assert.equal($('details').open, true);
  assert.equal($('textarea').selectionEnd, $('textarea').value.length);
});

test('invalid drafts are bounded; Escape closes the panel without changing the preview', t => {
  assert.equal(normalizeGlass({ blurPx: 999, tintPct: -3, sheenPct: NaN }).blurPx, 24);
  assert.equal(normalizeGlass({ tintPct: -3 }).tintPct, 0);
  assert.equal(normalizeGlass(null).blurPx, 6);
  const { tuner, $, dom, closes, root } = setup(t, { getItem: () => '{broken' });
  tuner.open();
  $('aside').dispatchEvent(new dom.window.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
  assert.equal($('aside').hidden, true);
  assert.equal(closes(), 1);
  assert.equal(root.style.getPropertyValue('--glass-blur'), '6px');
});
