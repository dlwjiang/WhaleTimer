import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { home } from '../src/content.mjs';
import { mountTimer, STORAGE_KEY } from '../src/web-timer.js';

function setup(t, options = {}) {
  const dom = new JSDOM(`<title>Tick & Kin</title>${home()}`, { url: 'https://tick-and-kin.theory-a.com/' });
  dom.window.matchMedia = () => ({ matches: true });
  let time = 100_000;
  const root = dom.window.document.querySelector('[data-web-timer]');
  const app = mountTimer(root, { now: () => time, ...options });
  t.after(() => { app.destroy(); dom.window.close(); });
  const get = selector => root.querySelector(selector);
  return { dom, root, app, get, advance(ms) { time += ms; app.refresh(); } };
}

test('actual homepage controls configure, start, pause, resume, complete, break, and reset', t => {
  const { get, dom, advance } = setup(t);
  assert.equal(get('[data-timer-display]').textContent, '25:00');
  assert.equal(get('[data-timer-settings]').hidden, false);
  const preset = get('[name=preset]');
  preset.value = 'quick';
  preset.dispatchEvent(new dom.window.Event('change'));
  get('form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  assert.equal(get('[data-timer-display]').textContent, '01:00');
  const button = get('[data-timer-toggle]');
  button.click();
  assert.equal(button.textContent, 'Pause');
  assert.equal(get('fieldset').disabled, true);
  advance(10_000);
  assert.equal(get('[data-timer-display]').textContent, '00:50');
  assert.match(dom.window.document.title, /00:50/);
  button.click(); advance(100_000);
  assert.equal(button.textContent, 'Resume');
  assert.equal(get('[data-timer-display]').textContent, '00:50');
  button.click(); advance(50_000);
  assert.equal(button.textContent, 'Start break');
  assert.match(get('[data-timer-announcement]').textContent, /Focus complete/);
  button.click();
  assert.equal(get('[data-timer-phase]').textContent, 'Break');
  assert.equal(get('[data-timer-display]').textContent, '01:00');
  advance(60_000);
  assert.equal(button.textContent, 'Start focusing');
  button.click();
  get('[data-timer-reset]').click();
  assert.equal(get('[data-timer-display]').textContent, '01:00');
  assert.equal(get('fieldset').disabled, false);
  assert.equal(dom.window.document.title, 'Tick & Kin');
  assert.equal(JSON.parse(dom.window.localStorage.getItem(STORAGE_KEY)).engine.status, 'idle');
});

test('screen reader announcements stay quiet during ticks; reduced motion skips flips', t => {
  const { get, advance } = setup(t);
  get('[data-timer-toggle]').click();
  const announcement = get('[data-timer-announcement]').textContent;
  advance(12_000);
  assert.equal(get('[data-timer-announcement]').textContent, announcement);
  assert.equal(get('.is-flipping'), null);
  assert.equal(get('[data-timer-display]').getAttribute('aria-live'), 'off');
});

test('blocked browser storage does not prevent using the timer', t => {
  const { get, advance } = setup(t, { storage: {
    getItem() { throw new Error('Blocked'); }, setItem() { throw new Error('Quota exceeded'); },
  } });
  get('[data-timer-toggle]').click(); advance(30_000);
  assert.equal(get('[data-timer-display]').textContent, '24:30');
});

test('custom durations survive a fresh mount and five-digit times render correctly', t => {
  const { get, dom } = setup(t);
  get('[name=focus]').value = '120';
  get('[name=break]').value = '12';
  get('[name=focus]').dispatchEvent(new dom.window.Event('input'));
  get('form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  assert.equal(get('[data-timer-display]').textContent, '120:00');
  assert.equal(get('[data-timer-display]').querySelectorAll('.flip-digit').length, 5);
  const persisted = dom.window.localStorage.getItem(STORAGE_KEY);
  const other = setup(t, { storage: { getItem: () => persisted, setItem() {} } });
  assert.equal(other.get('[name=focus]').value, '120');
  assert.equal(other.get('[name=break]').value, '12');
  assert.equal(other.get('[name=preset]').value, 'custom');
});
