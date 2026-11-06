import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { createFlipClock } from '../src/flip-clock.js';

function setup(t, reducedMotion = false) {
  const dom = new JSDOM('<div id="clock" role="timer"></div>');
  dom.window.matchMedia = () => ({ matches: reducedMotion });
  const element = dom.window.document.querySelector('#clock');
  const clock = createFlipClock(element);
  t.after(() => { clock.destroy(); dom.window.close(); });
  return { clock, element, dom };
}

test('only changed digits flip and repeated ticks do not restart an in-flight flip', t => {
  const { clock, element, dom } = setup(t);
  clock.update('03:00');
  assert.equal(element.querySelectorAll('.flip-digit').length, 4);
  assert.equal(element.querySelectorAll('.is-flipping').length, 0);
  clock.update('02:59');
  assert.equal(element.textContent, '02:59');
  assert.equal(element.querySelectorAll('.is-flipping').length, 3);
  const moving = element.querySelector('.flip-land');
  assert.equal(element.querySelector('.is-flipping .flip-leave').dataset.value, '3');
  assert.equal(element.querySelector('.is-flipping > .flip-bottom').dataset.value, '3');
  clock.update('02:59');
  assert.equal(element.querySelector('.flip-land'), moving);
  moving.dispatchEvent(new dom.window.Event('animationend', { bubbles: true }));
  const card = element.querySelectorAll('.flip-digit')[1];
  assert.equal(card.classList.contains('is-flipping'), false);
  assert.equal(card.querySelector('.flip-bottom').dataset.value, '2');
  assert.equal(element.querySelector('.flip-clock-face').getAttribute('aria-hidden'), 'true');
});

test('pause, reset and reduced motion display current digits without stale overlays', t => {
  const { clock, element } = setup(t);
  clock.update('00:10'); clock.update('00:09');
  clock.update('00:09', { animate: false });
  assert.equal(element.querySelectorAll('.flip-moving').length, 0);
  assert.equal(element.querySelector('.flip-digit:last-child .flip-bottom').dataset.value, '9');
  clock.update('03:00', { animate: false });
  assert.equal(element.textContent, '03:00');
  assert.equal(element.querySelectorAll('.is-flipping').length, 0);
});

test('reduced motion never creates animated halves', t => {
  const { clock, element } = setup(t, true);
  clock.update('03:00'); clock.update('02:59');
  assert.equal(element.textContent, '02:59');
  assert.equal(element.querySelectorAll('.flip-moving').length, 0);
});

test('long durations, overtime and skipped ticks display the latest full value', t => {
  const { clock, element } = setup(t);
  for (const value of ['180:00', '99:59', '00:01', '+00:00', '+100:00', '+125:41']) {
    clock.update(value);
    assert.equal(element.textContent, value);
    assert.equal([...element.querySelectorAll('.flip-clock-face > span')].map(slot => slot.dataset.value).join(''), value);
  }
  clock.destroy();
  assert.equal(element.querySelectorAll('.flip-moving').length, 0);
});
