import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { createSpeaking } from '../src/speaking.js';
import { createPortrait, FACE_ANCHORS } from '../src/portrait.js';
import fs from 'node:fs';

function setup(t) {
  const dom = new JSDOM('<button></button>', { pretendToBeVisual: true });
  const view = dom.window, avatar = view.document.querySelector('button');
  const frames = new Map(); let next = 0, listener, onMotion, state = { active: false };
  const motion = { matches: false, addEventListener(_, fn) { onMotion = fn; }, removeEventListener() {} };
  view.matchMedia = () => motion;
  view.requestAnimationFrame = fn => { frames.set(++next, fn); return next; };
  view.cancelAnimationFrame = id => frames.delete(id);
  let painted;
  const audio = { getSpeechFrame: () => state, subscribeSpeech(fn) { listener = fn; return () => { listener = null; }; } };
  const carousel = { speak(character, mouth) { painted = { character, mouth }; }, blink() {} };
  const speaking = createSpeaking({ avatar, audio, carousel });
  t.after(() => { speaking.destroy(); view.close(); });
  return { speaking, frames, motion, get painted() { return painted; }, get listener() { return listener; },
    change(value) { state = value; listener?.(); },
    step(time) { const pending = [...frames.values()]; frames.clear(); pending.forEach(fn => fn(time)); },
    reduce() { motion.matches = true; onMotion(); },
  };
}

test('speech schedules frames only while active, follows the recorded character, and cancels immediately', t => {
  const env = setup(t);
  assert.equal(env.frames.size, 0);
  env.change({ active: true, character: 'claude', level: 1 });
  env.step(16); env.step(50);
  assert.deepEqual(env.painted, { character: 'claude', mouth: 2 });
  env.change({ active: false });
  assert.deepEqual(env.painted, { character: null, mouth: 0 });
  assert.equal(env.frames.size, 0);
  env.change({ active: true, character: 'chatgpt', level: 1 }); env.step(100); env.step(140);
  assert.deepEqual(env.painted, { character: 'chatgpt', mouth: 2 });
  env.speaking.destroy();
  assert.equal(env.frames.size, 0);
  assert.equal(env.listener, null);
});

test('reduced motion closes the mouth and removes the animation loop', t => {
  const env = setup(t);
  env.change({ active: true, character: 'whale', level: 1 }); env.step(16);
  env.reduce();
  assert.deepEqual(env.painted, { character: null, mouth: 0 });
  assert.equal(env.frames.size, 0);
  env.change({ active: true, character: 'whale', level: 1 });
  assert.equal(env.frames.size, 0);
});

test('every expression has a registered mouth and preserves the original art until all sprites load', () => {
  const dom = new JSDOM('<span></span>');
  const art = dom.window.document.querySelector('span');
  for (const character of Object.keys(FACE_ANCHORS)) {
    const portrait = createPortrait(art, character);
    const group = art.querySelector('.portrait-mouth');
    assert.equal(group.getAttribute('visibility'), 'hidden');
    art.querySelectorAll('image').forEach(image => {
      assert.ok(fs.existsSync(`public${image.getAttribute('href')}`));
      image.dispatchEvent(new dom.window.Event('load'));
    });
    assert.equal(group.getAttribute('visibility'), 'visible');
    for (const [expression, [x, y]] of Object.entries(FACE_ANCHORS[character])) {
      portrait.expression(expression); portrait.mouth(2);
      assert.equal(group.getAttribute('transform'), `translate(${x} ${y})`);
      assert.equal(group.querySelectorAll('image[visibility="inherit"]').length, 1);
      portrait.blink(true);
      assert.equal(art.querySelector('.portrait-blink').getAttribute('visibility'), ['idle', 'happy'].includes(expression) ? 'visible' : 'hidden');
    }
    portrait.destroy();
  }
  assert.equal(art.children.length, 0);
  dom.window.close();
});
