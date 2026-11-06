import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { carouselFrame, createCharacterCarousel } from '../src/character-carousel.js';

function setup(t, reduced = false) {
  const dom = new JSDOM('<button id="avatar"></button>');
  const view = dom.window;
  const avatar = view.document.querySelector('button');
  let clock = 0;
  let id = 0;
  const frames = new Map();
  view.performance.now = () => clock;
  view.requestAnimationFrame = callback => { frames.set(++id, callback); return id; };
  view.cancelAnimationFrame = key => frames.delete(key);
  view.matchMedia = () => ({ matches: reduced, addEventListener() {}, removeEventListener() {} });
  const carousel = createCharacterCarousel(avatar);
  function advance(ms = 300) {
    clock += ms;
    const pending = [...frames.values()];
    frames.clear();
    pending.forEach(callback => callback(clock));
  }
  const face = index => avatar.querySelectorAll('.character-face')[index];
  const background = index => avatar.querySelectorAll('.scene-backdrop')[index];
  t.after(() => { carousel.destroy(); dom.window.close(); });
  return { carousel, avatar, face, background, advance, frames };
}

test('cylinder wraps seamlessly in both directions and each stop has exactly one front face', () => {
  for (const position of [-1, -.5, 0, .5, 1, 2, 2.5, 3]) {
    const a = carouselFrame(position);
    const b = carouselFrame(position + 3);
    assert.deepEqual(a, b);
    assert.ok(a.some(face => face.backgroundOpacity === 1));
    if (Number.isInteger(position)) {
      assert.equal(a.filter(face => face.opacity > 0).length, 1);
      assert.equal(a.filter(face => face.backgroundOpacity > 0).length, 1);
      assert.ok(a.some(face => face.x === 0 && face.z === 0 && face.opacity === 1));
    }
  }
});

test('drag rotates two characters and crossfades scenes, then cancellation snaps fully back', t => {
  const { carousel, avatar, face, background, advance, frames } = setup(t);
  carousel.begin(); carousel.drag(.5);
  assert.ok(Number(face(0).style.opacity) > 0);
  assert.ok(Number(face(1).style.opacity) > 0);
  assert.match(face(0).style.transform, /rotateY\(-27deg\)/);
  assert.match(face(1).style.transform, /rotateY\(27deg\)/);
  assert.equal(background(0).style.opacity, '1');
  assert.equal(background(1).style.opacity, '0.5');
  carousel.snap(); advance(80);
  assert.equal(avatar.dataset.rotating, 'true');
  advance();
  assert.equal(face(0).style.opacity, '1');
  assert.equal(face(1).style.visibility, 'hidden');
  assert.equal(background(1).style.opacity, '0');
  assert.equal(avatar.dataset.rotating, undefined);
  assert.equal(frames.size, 0);
});

test('selection persists visually through rapid interruption and preserves expressions on every face', t => {
  const { carousel, avatar, face, background, advance, frames } = setup(t);
  carousel.begin(); carousel.drag(.35); carousel.select(1); advance(60);
  carousel.updateExpression('bell');
  assert.equal(avatar.querySelectorAll('.character-face .is-visible').length, 3);
  assert.ok([...avatar.querySelectorAll('.is-visible')].every(img => img.dataset.expression === 'bell'));
  assert.equal(avatar.querySelectorAll('.avatar-image.is-visible[aria-hidden="false"]').length, 1);
  carousel.begin(); carousel.drag(.4); carousel.select(2); advance();
  assert.equal(face(2).style.opacity, '1');
  assert.equal(background(2).style.opacity, '1');
  assert.equal(face(0).style.visibility, 'hidden');
  carousel.select(0); advance();
  assert.equal(face(0).style.opacity, '1');
  assert.equal(frames.size, 0);
});

test('reduced motion blends scenery during drag and resolves immediately on release', t => {
  const { carousel, avatar, face, background, frames } = setup(t, true);
  const transform = face(0).style.transform;
  carousel.begin(); carousel.drag(.5);
  assert.equal(face(0).style.transform, transform);
  assert.equal(background(1).style.opacity, '0.5');
  carousel.select(1);
  assert.equal(face(1).style.opacity, '1');
  assert.equal(background(0).style.opacity, '0');
  assert.equal(avatar.dataset.rotating, undefined);
  assert.equal(frames.size, 0);
});

test('destroy cancels a pending snap and removes generated layers', t => {
  const { carousel, avatar, frames, advance } = setup(t);
  carousel.select(1);
  assert.equal(frames.size, 1);
  carousel.destroy(); advance();
  assert.equal(frames.size, 0);
  assert.equal(avatar.children.length, 0);
});
