import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { createCharacterSwipe } from '../src/character-swipe.js';

function setup(t) {
  const dom = new JSDOM('<main><button id="avatar">Hello</button><button id="control">Reset</button></main>');
  const surface = dom.window.document.querySelector('main');
  const avatar = surface.querySelector('#avatar');
  const control = surface.querySelector('#control');
  const changes = [];
  const captures = [];
  const feedback = [];
  surface.setPointerCapture = id => captures.push(id);
  surface.releasePointerCapture = () => {};
  const swipe = createCharacterSwipe(surface, {
    onSwipe: direction => changes.push(direction), canStart: target => target !== control,
    onStart: () => feedback.push('start'), onDrag: offset => feedback.push(offset),
    onRelease: direction => feedback.push(['release', direction]),
  });
  t.after(() => { swipe.destroy(); dom.window.close(); });
  function pointer(type, x, y = 100, { target = avatar, id = 1, primary = true, button = 0, time } = {}) {
    const event = new dom.window.Event(type, { bubbles: true, cancelable: true });
    Object.assign(event, { pointerId: id, clientX: x, clientY: y, isPrimary: primary, button });
    if (time !== undefined) Object.defineProperty(event, 'timeStamp', { value: time });
    target.dispatchEvent(event);
    return event;
  }
  function click(target = avatar, detail = 1) {
    const event = new dom.window.MouseEvent('click', { bubbles: true, cancelable: true, detail });
    target.dispatchEvent(event);
    return event;
  }
  return { surface, avatar, control, swipe, changes, captures, pointer, click, feedback };
}

test('horizontal drags switch once on release and consume the following pointer click', t => {
  const { pointer, click, changes, surface, captures } = setup(t);
  pointer('pointerdown', 200);
  assert.equal(pointer('pointermove', 100).defaultPrevented, true);
  assert.equal(surface.dataset.swiping, 'true');
  assert.deepEqual(changes, []);
  pointer('pointerup', 100);
  assert.deepEqual(changes, [1]);
  assert.deepEqual(captures, [1]);
  assert.equal(surface.dataset.swiping, undefined);
  assert.equal(surface.style.getPropertyValue('--character-drag-x'), '');
  assert.equal(click().defaultPrevented, true);
  pointer('pointerdown', 100); pointer('pointermove', 200); pointer('pointerup', 200);
  assert.deepEqual(changes, [1, -1]);
});

test('taps, short drags, vertical scrolls and diagonal scrolls never switch characters', t => {
  const { pointer, click, changes } = setup(t);
  pointer('pointerdown', 100); pointer('pointerup', 104);
  assert.equal(click().defaultPrevented, false);
  pointer('pointerdown', 100); pointer('pointermove', 125); pointer('pointerup', 125);
  assert.equal(click().defaultPrevented, true);
  for (const [x, y] of [[103, 220], [200, 230]]) {
    pointer('pointerdown', 100);
    assert.equal(pointer('pointermove', x, y).defaultPrevented, false);
    pointer('pointerup', x, y);
  }
  assert.deepEqual(changes, []);
});

test('pointer cancellation, lost capture and a second finger cancel a drag', t => {
  const { pointer, surface, changes } = setup(t);
  for (const type of ['pointercancel', 'lostpointercapture']) {
    pointer('pointerdown', 200); pointer('pointermove', 80); pointer(type, 80); pointer('pointerup', 80);
    assert.equal(surface.dataset.swiping, undefined);
  }
  pointer('pointerdown', 200); pointer('pointermove', 80);
  pointer('pointerdown', 150, 100, { id: 2, primary: false });
  pointer('pointerup', 80);
  assert.equal(surface.dataset.swiping, undefined);
  assert.deepEqual(changes, []);
});

test('controls and non-primary buttons are ignored; new taps and keyboard clicks still work after swiping', t => {
  const { pointer, click, changes, control } = setup(t);
  for (const options of [{ target: control }, { primary: false }, { button: 2 }]) {
    pointer('pointerdown', 200, 100, options); pointer('pointermove', 80, 100, options); pointer('pointerup', 80, 100, options);
  }
  assert.deepEqual(changes, []);
  pointer('pointerdown', 200); pointer('pointermove', 80); pointer('pointerup', 80);
  assert.equal(click(undefined, 0).defaultPrevented, false);
  pointer('pointerdown', 200); pointer('pointermove', 80); pointer('pointercancel', 80);
  pointer('pointerdown', 100); pointer('pointerup', 100);
  assert.equal(click().defaultPrevented, false);
});

test('destroy removes handlers and clears drag feedback', t => {
  const { pointer, swipe, surface, changes } = setup(t);
  pointer('pointerdown', 200); pointer('pointermove', 80);
  swipe.destroy(); pointer('pointerup', 80);
  assert.equal(surface.dataset.swiping, undefined);
  assert.deepEqual(changes, []);
});

test('drag previews are capped at one turn and every cancellation requests a complete snap back', t => {
  const { pointer, feedback, surface } = setup(t);
  pointer('pointerdown', 200); pointer('pointermove', -800);
  assert.deepEqual(feedback, ['start', 1]);
  pointer('pointercancel', -800);
  assert.deepEqual(feedback.at(-1), ['release', 0]);
  pointer('pointerdown', 200); pointer('pointermove', 280);
  surface.ownerDocument.defaultView.dispatchEvent(new surface.ownerDocument.defaultView.Event('blur'));
  assert.deepEqual(feedback.at(-1), ['release', 0]);
  assert.equal(surface.dataset.swiping, undefined);
});

test('a deliberate short flick advances, but a short drag held still returns to its stop', t => {
  const { pointer, changes, feedback } = setup(t);
  pointer('pointerdown', 200, 100, { time: 0 });
  pointer('pointermove', 160, 100, { time: 40 });
  pointer('pointerup', 160, 100, { time: 50 });
  assert.deepEqual(changes, [1]);
  assert.deepEqual(feedback.at(-1), ['release', 1]);
  pointer('pointerdown', 200, 100, { time: 100 });
  pointer('pointermove', 160, 100, { time: 140 });
  pointer('pointerup', 160, 100, { time: 500 });
  assert.deepEqual(changes, [1]);
  assert.deepEqual(feedback.at(-1), ['release', 0]);
});
