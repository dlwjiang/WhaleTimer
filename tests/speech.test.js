import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { createSpeechCaption } from '../src/speech.js';

function setup(t) {
  const dom = new JSDOM('<section><button></button><div aria-hidden="true"></div></section>');
  const document = dom.window.document;
  const container = document.querySelector('section');
  const avatar = document.querySelector('button');
  const element = document.querySelector('div');
  let time = 0;
  let character = 'whale';
  Object.defineProperty(document.documentElement, 'clientWidth', { value: 390 });
  container.getBoundingClientRect = () => ({ left: 0, top: 0, right: 390, width: 390, height: 740 });
  avatar.getBoundingClientRect = () => ({ left: -73.5, top: 84, width: 537, height: 537 });
  const caption = createSpeechCaption({ element, avatar, container, now: () => time, character: () => character });
  t.after(() => { caption.destroy(); dom.window.close(); });
  return { caption, element, avatar, setTime(value) { time = value; }, setCharacter(value) { character = value; } };
}

test('captions track character mouths and stay inside narrow mobile edges', t => {
  const { caption, element, setCharacter } = setup(t);
  caption.show('超时了，这是第一次警告！');
  assert.equal(element.dataset.kind, 'warning');
  const firstTop = parseFloat(element.style.top);
  assert.ok(parseFloat(element.style.left) > 150);
  assert.ok(parseFloat(element.style.left) + parseFloat(element.style.width) <= 374);
  setCharacter('claude'); caption.position();
  assert.ok(parseFloat(element.style.top) < firstTop);
  setCharacter('chatgpt'); caption.position();
  assert.ok(parseFloat(element.style.top) > 260);
  assert.equal(element.getAttribute('aria-hidden'), 'true');
});

test('each countdown replaces the animation and a newer line owns its expiry', t => {
  const { caption, element, setTime } = setup(t);
  caption.show('五');
  const firstGlyph = element.firstChild.firstChild;
  assert.equal(element.dataset.kind, 'countdown');
  assert.equal(element.textContent, '五');
  setTime(900); caption.show('四');
  assert.notEqual(element.firstChild.firstChild, firstGlyph);
  setTime(1000); caption.update();
  assert.equal(element.classList.contains('is-visible'), true);
  assert.equal(element.textContent, '四');
  setTime(1850); caption.update();
  assert.equal(element.classList.contains('is-visible'), false);
  caption.show('好，继续加油！');
  assert.equal(element.dataset.kind, 'speech');
  assert.equal(element.classList.contains('is-visible'), true);
  caption.destroy();
  assert.equal(element.textContent, '');
});

test('opening countdown follows recording beats with the same style, skipping missed beats', t => {
  const { caption, element, setTime } = setup(t);
  let audioTime = 0;
  caption.startIntro(() => audioTime);
  assert.equal(element.textContent, '三');
  assert.equal(element.dataset.kind, 'countdown');
  const firstGlyph = element.firstChild.firstChild;
  setTime(1200); caption.update(); // Wall time can move while audio is suspended.
  assert.equal(element.textContent, '三');
  assert.equal(element.classList.contains('is-visible'), true);
  audioTime = 800; caption.update();
  assert.equal(element.textContent, '二');
  assert.notEqual(element.firstChild.firstChild, firstGlyph);
  audioTime = 1600; caption.update();
  assert.equal(element.textContent, '一');
  audioTime = 2400; caption.update();
  assert.equal(element.textContent, '开始！');
  assert.equal(element.dataset.kind, 'countdown');
  assert.equal(element.dataset.finish, 'true');
  audioTime = 3400; caption.update();
  assert.equal(element.classList.contains('is-visible'), false);
  caption.startIntro(() => audioTime);
  audioTime = 9000; caption.update();
  assert.equal(element.classList.contains('is-visible'), false);
});

test('new speech or cancellation prevents old intro beats from returning', t => {
  const { caption, element, setTime } = setup(t);
  caption.startIntro();
  setTime(500); caption.show('休息一下，我等你。');
  setTime(1800); caption.update();
  assert.equal(element.textContent, '休息一下，我等你。');
  caption.startIntro(); caption.clear();
  setTime(3000); caption.update();
  assert.equal(element.classList.contains('is-visible'), false);
});
