import test from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import { mountApp, formatTime } from '../src/ui.js';
import { TimerEngine } from '../src/timer.js';

const flush = async () => { for (let i = 0; i < 8; i++) await Promise.resolve(); };

function setup(t, saved, options = {}) {
  const dom = new JSDOM('<!doctype html><div id="app"></div>', { url: 'https://tide.test' });
  globalThis.window = dom.window;
  globalThis.document = dom.window.document;
  dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
  dom.window.HTMLDialogElement.prototype.close = function () { this.open = false; };
  // Native media behavior is covered by the dedicated asset-panel tests.
  dom.window.HTMLMediaElement.prototype.pause = function () {};
  let clock = 1000;
  const data = new Map(saved ? [['tide-timer-v1', JSON.stringify(saved)]] : []);
  const storage = { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value) };
  const calls = [];
  const pendingSpeech = [];
  const audio = {
    supported: true,
    setCharacter: id => calls.push(['character', id]),
    setEnabled: value => { calls.push(['enabled', value]); if (!value) pendingSpeech.splice(0).forEach(resolve => resolve(false)); }, unlock: () => calls.push(['unlock']),
    bell: () => calls.push(['bell']), speak: (text, playback) => {
      calls.push(['speak', text]);
      playback?.onStart?.();
      if (options.deferSpeech && playback?.waitUntilEnd) return new Promise(resolve => pendingSpeech.push(resolve));
      return Promise.resolve(!options.speechFailure);
    },
    silence: () => { calls.push(['silence']); pendingSpeech.splice(0).forEach(resolve => resolve(false)); }, destroy() {},
  };
  const app = mountApp(document.querySelector('#app'), {
    now: () => clock, storage, audio,
    autoTick: false, ...options,
  });
  t.after(() => { app.destroy(); dom.window.close(); delete globalThis.window; delete globalThis.document; });
  const $ = selector => document.querySelector(selector);
  function configure(main = '0.1', extra = '0.1') {
    $('#settings-open').click();
    $('#main-duration').value = main;
    $('#secondary-duration').value = extra;
    $('#settings-form').dispatchEvent(new dom.window.Event('submit', { bubbles: true, cancelable: true }));
  }
  function pointer(type, x, id = 1) {
    const event = new dom.window.Event(type, { bubbles: true });
    Object.assign(event, { pointerId: id, clientX: x, button: 0 });
    $('#reset-handle').dispatchEvent(event);
  }
  return { app, $, calls, data, dom, configure, pointer, async finishSpeech() { assert.ok(pendingSpeech.length); pendingSpeech.shift()(true); await flush(); }, async time(ms, tick = true) { clock = ms; if (tick) app.tick(); await flush(); } };
}

test('default interface uses proportional progress sections without duration labels', async t => {
  const { $ } = setup(t);
  assert.equal($('#timer-display').textContent, '03:00');
  assert.equal($('.time-details'), null);
  assert.equal($('#duration-label'), null);
  assert.equal($('#extra-label'), null);
  assert.equal($('.progress-sections').style.gridTemplateColumns, 'minmax(0, 180fr) minmax(0, 120fr)');
  assert.equal(document.querySelectorAll('.avatar-image').length, 6);
  assert.equal($('#avatar').dataset.expression, 'idle');
  assert.equal(formatTime(1), '00:01');
  assert.equal(formatTime(3600000), '60:00');
});

test('unequal timer durations size the sections proportionally and fill each phase independently', async t => {
  const { $, configure, time } = setup(t);
  configure('0.1', '0.2');
  assert.equal($('.progress-sections').style.gridTemplateColumns, 'minmax(0, 6fr) minmax(0, 12fr)');
  $('#primary-action').click(); await flush();
  await time(4000);
  assert.equal($('#focus-progress').getAttribute('aria-valuenow'), '50');
  assert.equal($('#extra-progress').getAttribute('aria-valuenow'), '0');
  await time(7000); await time(13000);
  assert.equal($('#focus-progress').getAttribute('aria-valuenow'), '100');
  assert.equal($('#extra-progress').getAttribute('aria-valuenow'), '50');
});

test('disabling repeated alerts preserves the ending alert and overtime clock, and saves the preference', async t => {
  const { $, app, configure, dom, time, calls, data } = setup(t);
  configure();
  $('#settings-open').click();
  assert.equal($('#overtime-alerts').checked, true);
  $('#overtime-alerts').click();
  assert.equal($('#overtime-interval').disabled, true);
  $('#overtime-interval').value = '';
  $('#settings-form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  assert.equal($('#settings-dialog').open, false);
  assert.equal(app.engine.snapshot().overtimeAlerts, false);
  assert.equal(JSON.parse(data.get('tide-timer-v1')).timer.overtimeAlerts, false);
  $('#primary-action').click(); await flush();
  await time(7000); await time(13000);
  assert.ok(calls.some(([type, text]) => type === 'speak' && text === '时间真的到了！我要生气啦！'));
  calls.length = 0;
  await time(43000); await time(73000); await time(133000);
  assert.equal($('#timer-display').textContent, '+02:00');
  assert.equal(calls.filter(([type]) => type === 'speak').length, 0);
  assert.equal($('#anger-emojis').hidden, true);
  $('#settings-open').click();
  assert.equal($('#overtime-alerts').checked, false);
  assert.equal($('#overtime-interval').value, '30');
  $('#overtime-alerts').click(); $('#settings-close').click();
  assert.equal(app.engine.snapshot().overtimeAlerts, false); // Cancel does not save.
  $('#settings-open').click(); $('#overtime-alerts').click();
  assert.equal($('#overtime-interval').disabled, false);
  $('#settings-form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  assert.equal(app.engine.snapshot().overtimeAlerts, true);
});

test('settings restore a disabled recurring-alert preference', t => {
  const timer = new TimerEngine({ overtimeAlerts: false });
  const { $ } = setup(t, { timer: timer.serialize() });
  $('#settings-open').click();
  assert.equal($('#overtime-alerts').checked, false);
  assert.equal($('#overtime-interval').disabled, true);
});

test('switching companions persists immediately and preserves a running timer and its reaction', async t => {
  const { $, app, time, data, calls } = setup(t);
  $('#primary-action').click(); await flush(); await time(4000);
  $('#settings-open').click();
  const before = app.engine.snapshot();
  const spoken = calls.filter(([type]) => type === 'speak').length;
  $('.character-option[data-character="claude"]').click();
  assert.deepEqual(app.engine.snapshot(), before);
  assert.equal($('#avatar').dataset.expression, 'happy');
  assert.equal($('#avatar').dataset.motion, 'bounce');
  assert.deepEqual(calls.filter(([type]) => type === 'character').at(-1), ['character', 'claude']);
  assert.match($('.avatar-image.is-visible').src, /avatars\/claude\/happy.webp$/);
  assert.equal(document.querySelectorAll('.avatar-image.is-visible').length, 1);
  assert.match($('#avatar').getAttribute('aria-label'), /Claude/);
  assert.equal(JSON.parse(data.get('tide-timer-v1')).character, 'claude');
  $('.character-option[data-character="chatgpt"]').click();
  $('#settings-close').click();
  assert.equal(JSON.parse(data.get('tide-timer-v1')).character, 'chatgpt');
  assert.match($('.avatar-image.is-visible').src, /avatars\/chatgpt\/happy.webp$/);
  assert.equal(calls.filter(([type]) => type === 'speak').length, spoken);
  await time(5000);
  assert.equal($('#timer-display').textContent, '02:56');
  $('#settings-open').click(); $('.character-option[data-character="whale"]').click();
  assert.match($('.avatar-image.is-visible').src, /avatars\/happy.webp$/);
  assert.equal(document.querySelectorAll('.avatar-image').length, 6);
});

for (const character of ['claude', 'chatgpt']) {
  test(`${character} shows the bell sprite during the transition and preserves it when swapping`, async t => {
    const { $, app, configure, time, finishSpeech } = setup(t, { character }, { deferSpeech: true });
    configure(); $('#primary-action').click(); await finishSpeech();
    await time(7000);
    assert.equal(app.engine.snapshot().status, 'preparing');
    assert.equal($('#avatar').dataset.motion, 'ring');
    assert.ok($('.avatar-image.is-visible').src.endsWith(`/avatars/${character}/bell.webp`));
    const other = character === 'claude' ? 'chatgpt' : 'claude';
    $('#settings-open').click(); $(`.character-option[data-character="${other}"]`).click(); $('#settings-close').click();
    assert.ok($('.avatar-image.is-visible').src.endsWith(`/avatars/${other}/bell.webp`));
    assert.equal(app.engine.snapshot().status, 'preparing');
    await finishSpeech();
    assert.ok($('.avatar-image.is-visible').src.endsWith(`/avatars/${other}/bell.webp`));
    assert.equal(app.engine.snapshot().status, 'running');
  });

  test(`${character} restores and stays visible through countdown, overtime and reset`, async t => {
    const { $, configure, time, app, data } = setup(t, { character });
    assert.equal($('#app').dataset.character, character);
    assert.equal($(`.character-option[data-character="${character}"]`).getAttribute('aria-pressed'), 'true');
    assert.equal(document.querySelectorAll('.avatar-image').length, 6);
    assert.ok($('.avatar-image.is-visible').src.endsWith(`/avatars/${character}/idle.webp`));
    $('#avatar').click();
    assert.ok($('.avatar-image.is-visible').src.endsWith(`/avatars/${character}/cute.webp`));
    configure(); $('#primary-action').click(); await flush();
    for (const timestamp of [7000, 8000, 13000, 43000, 73000]) {
      await time(timestamp);
      assert.equal(document.querySelectorAll('.avatar-image.is-visible').length, 1);
      assert.ok($('.avatar-image.is-visible').src.endsWith(`/avatars/${character}/${$('#avatar').dataset.expression}.webp`));
      assert.equal($('.avatar-image.is-visible').getAttribute('aria-hidden'), 'false');
    }
    assert.equal($('#app').dataset.phase, 'overdue');
    assert.equal($('#avatar').dataset.motion, 'huff');
    app.reset();
    assert.equal(JSON.parse(data.get('tide-timer-v1')).character, character);
  });
}

test('an unknown stored companion falls back to the whale maid', t => {
  const { $, data } = setup(t, { character: '../missing' });
  assert.equal($('#app').dataset.character, 'whale');
  assert.match($('.avatar-image.is-visible').src, /avatars\/idle.webp$/);
  assert.equal(JSON.parse(data.get('tide-timer-v1')).character, 'whale');
});

test('main-area swipes cycle and persist characters without interrupting the timer or greeting', async t => {
  const { $, app, time, calls, data, dom } = setup(t);
  const gesture = (dx, selector = '#avatar') => {
    const target = $(selector);
    for (const [type, x] of [['pointerdown', 200], ['pointermove', 200 + dx], ['pointerup', 200 + dx]]) {
      const event = new dom.window.Event(type, { bubbles: true, cancelable: true });
      Object.assign(event, { pointerId: 9, clientX: x, clientY: 150, button: 0, isPrimary: true });
      target.dispatchEvent(event);
    }
    target.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true, cancelable: true, detail: 1 }));
  };
  $('#primary-action').click(); await flush(); await time(4000);
  const before = app.engine.snapshot();
  const playbackCalls = () => calls.filter(([type]) => type !== 'character');
  const audioCalls = playbackCalls();
  gesture(-100);
  assert.equal($('#app').dataset.character, 'claude');
  assert.equal(JSON.parse(data.get('tide-timer-v1')).character, 'claude');
  assert.equal($('.character-option[data-character="claude"]').getAttribute('aria-pressed'), 'true');
  assert.equal($('#avatar').dataset.expression, 'happy');
  assert.deepEqual(app.engine.snapshot(), before);
  assert.deepEqual(playbackCalls(), audioCalls);
  assert.deepEqual(calls.at(-1), ['character', 'claude']);
  gesture(-100, '.companion');
  assert.equal($('#app').dataset.character, 'chatgpt');
  gesture(-100);
  assert.equal($('#app').dataset.character, 'whale');
  gesture(100);
  assert.equal($('#app').dataset.character, 'chatgpt');
  assert.deepEqual(app.engine.snapshot(), before);
  await time(5000);
  assert.equal($('#timer-display').textContent, '02:56');
});

test('main character buttons and arrow keys share the saved selection without resetting preparation', t => {
  const { $, app, data, dom } = setup(t, null, { deferSpeech: true });
  $('#primary-action').click();
  $('#character-previous').click();
  assert.equal($('#app').dataset.character, 'chatgpt');
  assert.equal(app.engine.snapshot().status, 'preparing');
  $('#character-next').click();
  assert.equal($('#app').dataset.character, 'whale');
  $('#avatar').dispatchEvent(new dom.window.KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true, cancelable: true }));
  assert.equal($('#app').dataset.character, 'claude');
  assert.equal(JSON.parse(data.get('tide-timer-v1')).character, 'claude');
  assert.equal(app.engine.snapshot().status, 'preparing');
});

test('full session rings at main boundary, switches to angry, and numbers recurring warnings', async t => {
  const { $, app, configure, time, calls } = setup(t);
  configure();
  assert.equal(app.engine.snapshot().mainSeconds, 6);
  assert.equal($('#settings-dialog').open, false);
  $('#primary-action').click(); await flush();
  await time(4000);
  assert.equal($('#timer-display').textContent, '00:03');
  await time(7000);
  assert.equal($('#app').dataset.phase, 'grace');
  assert.equal($('#timer-display').textContent, '00:06');
  assert.equal($('#avatar').dataset.expression, 'bell');
  assert.equal(calls.filter(([type]) => type === 'bell').length, 1);
  assert.match($('#speech-cn').textContent, /时间到了/);
  await time(13000);
  assert.equal($('#app').dataset.phase, 'overdue');
  assert.equal($('#avatar').dataset.expression, 'angry');
  assert.equal($('#timer-display').textContent, '+00:00');
  assert.match($('#speech-cn').textContent, /我要生气/);
  const count = calls.filter(([type]) => type === 'speak').length;
  await time(42999);
  assert.equal(calls.filter(([type]) => type === 'speak').length, count);
  await time(43000);
  const firstReminder = $('#speech-cn').textContent;
  assert.equal(firstReminder, '超时了，这是第一次警告！');
  assert.equal(document.querySelectorAll('.anger-emoji').length, 1);
  const firstAngerEmoji = $('.anger-emoji');
  assert.equal($('#timer-display').textContent, '+00:30');
  await time(73000);
  assert.equal($('#speech-cn').textContent, '超时了，这是第二次警告！');
  assert.equal(document.querySelectorAll('.anger-emoji').length, 2);
  assert.equal($('.anger-emoji'), firstAngerEmoji);
  assert.equal(calls.filter(([type]) => type === 'bell').length, 1);
  await time(313000);
  assert.equal($('#speech-cn').textContent, '超时了，这是第十次警告！');
  await time(343000);
  assert.equal($('#speech-cn').textContent, '超时了，这是第十一次警告！');
  assert.equal(document.querySelectorAll('.anger-emoji').length, 11);
  await time(433000);
  assert.equal(document.querySelectorAll('.anger-emoji:not(.anger-overflow)').length, 12);
  assert.equal($('.anger-overflow').textContent, '+2');
  assert.equal($('#anger-emojis').getAttribute('aria-label'), '已超时警告 14 次');
});

test('restored overtime session continues numbering and reset returns to the first warning', async t => {
  let now = 0;
  const timer = new TimerEngine({ mainSeconds: 1, secondarySeconds: 1, now: () => now });
  timer.start(); timer.completePreparation(); now = 1000; timer.tick(); timer.completePreparation(); now = 62000; timer.tick();
  const saved = timer.serialize();
  // Align the saved wall-clock anchor with this test harness's starting clock.
  saved.savedAt = 1000;
  const { $, time, app } = setup(t, { timer: saved, sound: true });
  assert.equal($('#speech-cn').textContent, '超时了，这是第二次警告！');
  assert.equal(document.querySelectorAll('.anger-emoji').length, 2);
  $('#primary-action').click();
  assert.equal($('#anger-emojis').classList.contains('is-paused'), true);
  $('#character-next').click();
  assert.equal(document.querySelectorAll('.anger-emoji').length, 2);
  $('#primary-action').click();
  await time(31000);
  assert.equal($('#speech-cn').textContent, '超时了，这是第三次警告！');
  app.reset();
  assert.equal($('#anger-emojis').hidden, true);
  assert.equal(document.querySelectorAll('.anger-emoji').length, 0);
  $('#primary-action').click(); await flush();
  await time(32000); await time(33000); await time(63000);
  assert.equal($('#speech-cn').textContent, '超时了，这是第一次警告！');
});

test('pause exactly at a boundary consumes the transition silently and preserves remaining time', async t => {
  const { $, configure, time, calls, app } = setup(t);
  configure(); $('#primary-action').click(); await flush();
  calls.length = 0;
  await time(7000, false);
  $('#primary-action').click(); await flush();
  assert.equal(app.engine.snapshot().status, 'paused');
  assert.equal(app.engine.snapshot().phase, 'grace');
  assert.equal(calls.filter(([type]) => type === 'speak' || type === 'bell').length, 0);
  assert.match($('#speech-cn').textContent, /休息/);
  await time(100000);
  assert.equal($('#timer-display').textContent, '00:06');
  $('#primary-action').click(); await flush();
  await time(103000);
  assert.equal($('#timer-display').textContent, '00:03');
});

test('muted timers retain visible reminders without audio calls', async t => {
  const { $, calls, configure, time, data } = setup(t);
  $('#sound-toggle').click(); configure(); $('#primary-action').click(); await flush();
  await time(4000); await time(10000); await time(13000); await time(19000); await time(49000);
  assert.equal(calls.filter(([type]) => type === 'speak' || type === 'bell').length, 0);
  assert.equal($('#sound-toggle').getAttribute('aria-pressed'), 'false');
  assert.equal(JSON.parse(data.get('tide-timer-v1')).sound, false);
  assert.equal($('#app').dataset.phase, 'overdue');
});

test('settings values select fully on focus and repeated clicks, ready for replacement', t => {
  const { $, dom } = setup(t);
  $('#settings-open').click();
  for (const id of ['main-duration', 'secondary-duration', 'overtime-interval']) {
    const input = $(`#${id}`);
    input.value = id === 'overtime-interval' ? '120' : '10.5';
    input.focus();
    assert.equal(input.selectionStart, 0);
    assert.equal(input.selectionEnd, input.value.length);
    for (let click = 0; click < 3; click++) {
      input.setSelectionRange(1, 1);
      input.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
      assert.equal(input.selectionStart, 0);
      assert.equal(input.selectionEnd, input.value.length);
    }
    input.setRangeText('2', input.selectionStart, input.selectionEnd, 'end');
    assert.equal(input.value, '2');
  }
});

test('selectable duration fields retain numeric limits and recover after corrections or presets', t => {
  const { $, app, dom } = setup(t);
  $('#settings-open').click();
  const before = app.engine.snapshot();
  const submit = () => $('#settings-form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  for (const [id, invalidValues] of [
    ['main-duration', ['', 'abc', '0', '180.1', '1.25', 'Infinity', '0x10']],
    ['secondary-duration', ['-1', '181']],
    ['overtime-interval', ['0', '1.5', '86401', '1e2']],
  ]) {
    const input = $(`#${id}`);
    const original = input.value;
    for (const value of invalidValues) {
      input.value = value;
      submit();
      assert.equal(input.validity.valid, false, `${id}: ${value}`);
      assert.deepEqual(app.engine.snapshot(), before);
    }
    input.value = original;
    input.dispatchEvent(new dom.window.Event('input'));
    assert.equal(input.validationMessage, '');
  }
  $('#main-duration').value = 'bad'; submit();
  $('[data-preset]').click();
  assert.equal($('#main-duration').validationMessage, '');
  $('#main-duration').value = '.5';
  $('#secondary-duration').value = '180';
  $('#overtime-interval').value = '86400';
  submit();
  assert.equal($('#settings-dialog').open, false);
  assert.equal(app.engine.snapshot().mainSeconds, 30);
  assert.equal(app.engine.snapshot().secondarySeconds, 10800);
  assert.equal(app.engine.snapshot().overtimeSeconds, 86400);
});

test('settings cancel and invalid duration do not mutate an active timer; save resets and persists', async t => {
  const { $, app, time, configure, data } = setup(t);
  $('#primary-action').click(); await flush(); await time(4500);
  $('#settings-open').click(); $('#main-duration').value = '20'; $('#settings-close').click();
  assert.equal(app.engine.snapshot().mainSeconds, 180);
  assert.equal(app.engine.snapshot().status, 'running');
  configure('0', '2');
  assert.equal(app.engine.snapshot().status, 'running');
  assert.equal($('#settings-dialog').open, true);
  configure('10.5', '1.5');
  assert.equal(app.engine.snapshot().status, 'idle');
  assert.equal(app.engine.snapshot().mainSeconds, 630);
  assert.equal(app.engine.snapshot().secondarySeconds, 90);
  assert.equal($('#timer-display').textContent, '10:30');
  assert.equal(JSON.parse(data.get('tide-timer-v1')).timer.mainSeconds, 630);
});

test('drag reset requires crossing threshold, pointer cancellation aborts, keyboard reset works', async t => {
  const { $, app, pointer, time, dom, calls } = setup(t);
  const track = $('#reset-track'); const handle = $('#reset-handle');
  Object.defineProperty(track, 'clientWidth', { value: 300 });
  Object.defineProperty(handle, 'offsetWidth', { value: 38 });
  handle.setPointerCapture = () => {}; handle.releasePointerCapture = () => {};
  $('#primary-action').click(); await flush(); await time(4000);
  pointer('pointerdown', 10); pointer('pointermove', 70); pointer('pointerup', 70);
  assert.equal(app.engine.snapshot().status, 'running');
  pointer('pointerdown', 10); pointer('pointermove', 300); pointer('pointercancel', 300);
  assert.equal(app.engine.snapshot().status, 'running');
  assert.equal(calls.filter(([, text]) => text === '重新开始吧').length, 0);
  pointer('pointerdown', 10); pointer('pointermove', 300); pointer('pointerup', 300);
  assert.equal(app.engine.snapshot().status, 'idle');
  assert.equal($('#timer-display').textContent, '03:00');
  assert.equal($('#speech-cn').textContent, '重新开始吧');
  assert.equal(calls.filter(([, text]) => text === '重新开始吧').length, 1);
  $('#primary-action').click(); await flush(); await time(6000);
  handle.dispatchEvent(new dom.window.KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  assert.equal(app.engine.snapshot().status, 'idle');
  assert.equal(calls.filter(([, text]) => text === '重新开始吧').length, 2);
});

for (const character of ['whale', 'claude', 'chatgpt']) {
  test(`${character} speaks the shortened reset cue and respects mute`, t => {
    const { $, calls } = setup(t, { character, sound: true });
    assert.deepEqual(calls.find(([type]) => type === 'character'), ['character', character]);
    calls.length = 0;
    $('#reset-handle').click();
    assert.deepEqual(calls.filter(([type]) => type === 'silence' || type === 'speak'), [['silence'], ['speak', '重新开始吧']]);
    $('#sound-toggle').click();
    calls.length = 0;
    $('#reset-handle').click();
    assert.equal($('#speech-cn').textContent, '重新开始吧');
    assert.equal(calls.some(([type]) => type === 'speak'), false);
  });
}

test('restored grace session uses its actual phase, caption and expression without repeating bell', async t => {
  let now = 0;
  const timer = new TimerEngine({ mainSeconds: 1, secondarySeconds: 10, now: () => now });
  timer.start(); timer.completePreparation(); now = 1000; timer.tick(); timer.completePreparation();
  const { $, calls } = setup(t, { timer: timer.serialize(), sound: true });
  assert.equal($('#app').dataset.phase, 'grace');
  assert.equal($('#avatar').dataset.expression, 'frustrated');
  assert.match($('#speech-cn').textContent, /时间到了/);
  assert.equal(calls.filter(([type]) => type === 'bell' || type === 'speak').length, 0);
});

test('throwing storage getter does not prevent timer startup', async t => {
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, get() { throw new Error('Storage blocked'); } });
  t.after(() => delete globalThis.localStorage);
  const { $, app } = setup(t, null, { storage: undefined });
  $('#primary-action').click(); await flush();
  assert.equal(app.engine.snapshot().status, 'running');
});

test('secondary final five seconds speak Chinese once per second and finish with the angry reminder', async t => {
  const { $, configure, time, calls } = setup(t);
  configure('0.1', '0.2');
  $('#primary-action').click(); await flush();
  await time(7000);
  calls.length = 0;
  await time(13999);
  assert.equal(calls.filter(([type]) => type === 'speak').length, 0);
  const digits = ['五', '四', '三', '二', '一'];
  for (let index = 0; index < 5; index++) {
    await time(14000 + index * 1000);
    assert.equal($('#speech-cn').textContent, digits[index]);
    assert.equal($('#speech-visual').textContent, digits[index]);
    assert.equal($('#speech-visual').dataset.kind, 'countdown');
    assert.equal($('#speech-visual').classList.contains('is-visible'), true);
    assert.equal($('#app').dataset.countdown, String(5 - index));
    assert.equal($('#speech').classList.contains('is-countdown'), true);
    await time(14099 + index * 1000);
  }
  assert.deepEqual(calls.filter(([type]) => type === 'speak').map(([, text]) => text), digits);
  await time(19000);
  assert.equal($('#app').dataset.phase, 'overdue');
  assert.equal($('#app').dataset.countdown, '');
  assert.equal($('#speech').classList.contains('is-countdown'), false);
  assert.match($('#speech-cn').textContent, /我要生气/);
});

test('muted countdown keeps visible digits without speaking', async t => {
  const { $, configure, time, calls } = setup(t);
  configure('0.1', '0.2');
  $('#sound-toggle').click();
  calls.length = 0; // The earlier settings save speaks its reset cue before mute.
  $('#primary-action').click(); await flush();
  await time(4000); await time(10000); await time(17000);
  assert.equal($('#speech-cn').textContent, '五');
  assert.equal($('#speech-visual').textContent, '五');
  assert.equal(calls.filter(([type]) => type === 'speak').length, 0);
});

test('opening the asset panel pauses the active timer and closing does not silently resume it', async t => {
  const { $, app, time, calls } = setup(t);
  $('#primary-action').click(); await flush();
  await time(5000);
  $('#settings-open').click();
  $('#assets-open').click();
  assert.equal($('#settings-dialog').open, false);
  assert.equal(app.engine.snapshot().status, 'paused');
  assert.ok(calls.some(([type]) => type === 'silence'));
  const pausedTime = app.engine.snapshot().remainingMs;
  await time(9000);
  assert.equal(app.engine.snapshot().remainingMs, pausedTime);
  const panel = document.querySelector('dialog:not(#settings-dialog)');
  assert.equal(panel.open, true);
  panel.close();
  panel.dispatchEvent(new window.Event('close'));
  assert.equal(app.engine.snapshot().status, 'paused');
});


test('focus waits for its countdown, while extra time starts after the reminder without another countdown', async t => {
  const { $, app, configure, time, calls, finishSpeech } = setup(t, null, { deferSpeech: true });
  configure();
  calls.length = 0; // Measure the intro independently of the settings reset cue.
  $('#primary-action').click();
  assert.equal(app.engine.snapshot().status, 'preparing');
  assert.equal($('#speech-cn').textContent, '三、二、一，开始！');
  for (const [elapsed, text] of [[0, '三'], [800, '二'], [1600, '一'], [2400, '开始！']]) {
    await time(1000 + elapsed);
    assert.equal($('#speech-visual').textContent, text);
    assert.equal($('#speech-visual').dataset.kind, 'countdown');
    assert.equal(app.engine.snapshot().elapsedMs, 0);
  }
  await time(10000);
  assert.equal($('#timer-display').textContent, '00:06');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
  // Poking the character must not cut off the starting cue.
  $('#avatar').click();
  assert.equal(calls.filter(([type]) => type === 'speak').length, 1);
  await finishSpeech();
  assert.equal(app.engine.snapshot().status, 'running');
  await time(16000);
  assert.equal(app.engine.snapshot().status, 'preparing');
  assert.equal($('#speech-cn').textContent, '时间到了，我们快一点吧！');
  await time(20000);
  await finishSpeech(); // Extra time starts as soon as the transition reminder finishes.
  assert.equal($('#speech-cn').textContent, '时间到了，我们快一点吧！');
  assert.equal($('#timer-display').textContent, '00:06');
  assert.equal(app.engine.snapshot().status, 'running');
  assert.deepEqual(calls.filter(([type]) => type === 'speak').map(([, text]) => text),
    ['三、二、一，开始！', '时间到了，我们快一点吧！']);
  await time(21000);
  assert.equal($('#timer-display').textContent, '00:05');
  assert.equal(calls.filter(([, text]) => text === '三、二、一，开始！').length, 1);
});

test('pause and reset cancel an unfinished intro; ordinary resume does not replay it', async t => {
  const { $, app, time, calls, finishSpeech } = setup(t, null, { deferSpeech: true });
  $('#primary-action').click();
  $('#primary-action').click(); await flush();
  await time(20000);
  assert.equal(app.engine.snapshot().status, 'paused');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
  $('#primary-action').click(); await finishSpeech();
  await time(22000);
  $('#primary-action').click(); await flush();
  const introCount = calls.filter(([, text]) => text === '三、二、一，开始！').length;
  $('#primary-action').click(); await flush();
  assert.equal(app.engine.snapshot().status, 'running');
  assert.equal(calls.filter(([, text]) => text === '三、二、一，开始！').length, introCount);
  app.reset(); $('#primary-action').click(); app.reset(); await flush();
  await time(30000);
  assert.equal(app.engine.snapshot().status, 'idle');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
});

test('asset studio cancels preparation and a restored intro waits for a user gesture', async t => {
  const timer = new TimerEngine(); timer.start();
  const { $, app, calls } = setup(t, { timer: timer.serialize(), sound: true }, { deferSpeech: true });
  assert.equal(app.engine.snapshot().status, 'paused');
  assert.equal(calls.filter(([type]) => type === 'speak').length, 0);
  $('#primary-action').click();
  $('#settings-open').click(); $('#assets-open').click(); await flush();
  assert.equal(app.engine.snapshot().status, 'paused');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
});


test('muting during speech keeps a silent lead-in and does not leave preparation stuck', async t => {
  const { $, app, time } = setup(t, null, { deferSpeech: true });
  $('#primary-action').click();
  await time(2000);
  $('#sound-toggle').click(); await flush();
  await time(4999);
  assert.equal(app.engine.snapshot().status, 'preparing');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
  await time(5000);
  assert.equal(app.engine.snapshot().status, 'running');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
});

test('failed voice playback falls back to a visible lead-in before counting', async t => {
  const { $, app, time } = setup(t, null, { speechFailure: true });
  $('#primary-action').click(); await flush();
  await time(3999);
  assert.equal(app.engine.snapshot().status, 'preparing');
  assert.equal($('#speech-cn').textContent, '三、二、一，开始！');
  await time(4000);
  assert.equal(app.engine.snapshot().status, 'running');
  assert.equal(app.engine.snapshot().elapsedMs, 0);
});

test('Chinese settings save a custom overtime interval and use it for numbered warnings', async t => {
  const { $, app, dom, data, time } = setup(t);
  $('#settings-open').click();
  assert.equal($('#overtime-interval').value, '30');
  assert.equal($('.settings-note'), null);
  assert.equal($('#settings-title').textContent, '计时设置');
  $('#main-duration').value = '0.1'; $('#secondary-duration').value = '0.1';
  const interval = $('#overtime-interval');
  interval.value = '0';
  $('#settings-form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  assert.equal($('#settings-dialog').open, true);
  assert.match(interval.validationMessage, /整数秒数/);
  interval.value = '10';
  interval.dispatchEvent(new dom.window.Event('input'));
  $('#settings-form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }));
  assert.equal(app.engine.snapshot().overtimeSeconds, 10);
  assert.equal(JSON.parse(data.get('tide-timer-v1')).timer.overtimeSeconds, 10);
  $('#settings-open').click(); assert.equal(interval.value, '10'); $('#settings-close').click();
  $('#primary-action').click(); await flush();
  await time(7000); await time(13000); await time(22999);
  assert.match($('#speech-cn').textContent, /我要生气/);
  await time(23000); assert.equal($('#speech-cn').textContent, '超时了，这是第一次警告！');
  await time(33000); assert.equal($('#speech-cn').textContent, '超时了，这是第二次警告！');
});
