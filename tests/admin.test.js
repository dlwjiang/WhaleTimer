import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { createAssetPanel } from '../src/admin.js';
import voiceLines from '../design/voice/lines.json' with { type: 'json' };

function setup(t) {
  const dom = new JSDOM('<div id="app"><button id="launch">Studio</button><p id="existing">Existing timer</p></div>', { url: 'https://tide.test/' });
  const document = dom.window.document;
  const states = new WeakMap();
  Object.defineProperty(dom.window.HTMLMediaElement.prototype, 'paused', { get() { return !states.get(this); } });
  dom.window.HTMLMediaElement.prototype.play = function () { states.set(this, true); this.dispatchEvent(new dom.window.Event('play')); return Promise.resolve(); };
  dom.window.HTMLMediaElement.prototype.pause = function () {
    const wasPlaying = states.get(this);
    states.set(this, false);
    if (wasPlaying) this.dispatchEvent(new dom.window.Event('pause'));
  };
  dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
  dom.window.HTMLDialogElement.prototype.close = function () { this.open = false; this.dispatchEvent(new dom.window.Event('close')); };
  const calls = [];
  const panel = createAssetPanel(document.querySelector('#app'), { onOpen: () => calls.push('open'), onClose: () => calls.push('close') });
  t.after(() => { panel.destroy(); dom.window.close(); });
  const $ = selector => document.querySelector(selector);
  return { panel, $, document, dom, calls };
}

test('appends studio without replacing timer, listing every manifest voice and all character images', t => {
  const { $, document, panel, calls } = setup(t);
  assert.equal($('#existing').textContent, 'Existing timer');
  assert.equal(document.querySelectorAll('audio').length, voiceLines.clips.length);
  assert.equal(document.querySelectorAll('.asset-image-grid button').length, 18);
  $('#launch').focus(); panel.open(); panel.open();
  assert.equal($('dialog').open, true);
  assert.equal(document.activeElement, $('.asset-studio-close'));
  assert.deepEqual(calls, ['open']);
  panel.close();
  assert.equal(document.activeElement, $('#launch'));
  assert.deepEqual(calls, ['open', 'close']);
});

test('only one voice plays, stop-all resets it, and Escape stops playback', async t => {
  const { panel, document, $, dom, calls } = setup(t);
  panel.open();
  const [first, second] = document.querySelectorAll('audio');
  await first.play(); first.currentTime = 2;
  await second.play();
  assert.equal(first.paused, true);
  assert.equal(first.currentTime, 0);
  assert.equal(second.paused, false);
  assert.equal(document.querySelectorAll('.is-playing').length, 1);
  assert.match($('.asset-playback-status').textContent, new RegExp(voiceLines.clips[1].text));
  $('.asset-stop-all').click();
  assert.equal(second.paused, true);
  assert.equal($('.asset-playback-status').textContent, '暂无播放');
  await second.play();
  $('dialog').dispatchEvent(new dom.window.Event('cancel', { cancelable: true }));
  assert.equal($('dialog').open, false);
  assert.equal(second.paused, true);
  assert.deepEqual(calls, ['open', 'close']);
});

test('search matches Chinese or ID and stops playback when its row is filtered out', async t => {
  const { panel, $, dom, document } = setup(t);
  panel.open();
  await $('audio').play();
  const input = $('.asset-search input');
  input.value = '尾巴'; input.dispatchEvent(new dom.window.Event('input'));
  assert.equal($('audio').paused, true);
  assert.equal(document.querySelectorAll('.asset-voice-row:not([hidden])').length, 1);
  assert.equal($('.asset-voice-row:not([hidden])').dataset.voiceId, 'reminder-tail');
  input.value = 'main-complete'; input.dispatchEvent(new dom.window.Event('input'));
  assert.equal($('.asset-voice-row:not([hidden])').dataset.voiceId, 'main-complete');
  input.value = 'no-such-voice'; input.dispatchEvent(new dom.window.Event('input'));
  assert.equal($('.asset-no-results').hidden, false);
});

test('voice selector stops playback and switches every clip and download link to the selected character', async t => {
  const { panel, $, dom, document } = setup(t);
  panel.open();
  await $('audio').play();
  const selector = $('.asset-voice-selector select');
  for (const character of ['claude', 'chatgpt']) {
    selector.value = character;
    selector.dispatchEvent(new dom.window.Event('change'));
    assert.equal($('audio').paused, true);
    for (const row of document.querySelectorAll('.asset-voice-row')) {
      assert.ok(row.querySelector('audio').src.includes(`/voice/${character}/`));
      assert.equal(row.querySelector('.asset-load-error a').href, row.querySelector('audio').src);
    }
  }
  selector.value = 'whale'; selector.dispatchEvent(new dom.window.Event('change'));
  assert.match($('audio').src, /\/voice\/ready.m4a$/);
});

test('image selection updates preview, motion, background, and load fallback link', t => {
  const { panel, $, dom } = setup(t);
  panel.open();
  $('[data-asset-tab="images"]').click();
  assert.equal($('[data-asset-section="voices"]').hidden, true);
  assert.equal($('[data-asset-section="images"]').hidden, false);
  $('[data-expression="angry"]').click();
  const preview = $('.asset-image-preview');
  assert.match(preview.querySelector('img').src, /avatars\/angry.webp$/);
  assert.equal(preview.dataset.motion, 'stomp');
  assert.equal($('[data-expression="angry"]').getAttribute('aria-pressed'), 'true');
  $('.asset-background-options [data-background="dark"]').click();
  assert.equal(preview.dataset.background, 'dark');
  const motion = $('.asset-motion-toggle input'); motion.checked = true; motion.dispatchEvent(new dom.window.Event('change'));
  assert.equal(preview.dataset.animate, 'true');
  preview.querySelector('img').dispatchEvent(new dom.window.Event('error'));
  assert.equal($('.asset-image-error').hidden, false);
  assert.match($('.asset-image-error a').href, /angry.webp$/);
  panel.close();
  assert.equal(preview.dataset.animate, 'false');
  assert.equal(motion.checked, false);
});

test('audio failures expose a direct fallback, and destroy releases active playback', async t => {
  const { panel, $, dom } = setup(t);
  panel.open();
  const player = $('audio');
  player.dispatchEvent(new dom.window.Event('error'));
  assert.equal($('.asset-voice-row .asset-load-error').hidden, false);
  assert.equal($('.asset-voice-row .asset-load-error a').href, player.src);
  await player.play(); panel.destroy();
  assert.equal(player.paused, true);
  assert.equal($('dialog'), null);
  assert.ok($('#existing'));
  panel.open();
  assert.equal($('dialog'), null);
});

test('studio previews both new companions with their own accessible labels and file links', t => {
  const { panel, $ } = setup(t);
  panel.open();
  $('[data-asset-tab="images"]').click();
  for (const character of ['claude', 'chatgpt']) for (const state of ['idle', 'happy', 'cute', 'angry', 'frustrated', 'bell']) {
    $(`[data-expression="${character}-${state}"]`).click();
    const img = $('.asset-image-preview img');
    assert.ok(img.src.endsWith(`/avatars/${character}/${state}.webp`));
    assert.equal($('.asset-image-error a').href, img.src);
    assert.doesNotMatch(img.alt, /whale maid/);
    assert.equal($(`[data-expression="${character}-${state}"]`).getAttribute('aria-pressed'), 'true');
  }
});
