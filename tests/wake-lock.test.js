import test from 'node:test';
import assert from 'node:assert/strict';
import { createScreenWakeLock } from '../src/wake-lock.js';

const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};
function lock() {
  return Object.assign(new EventTarget(), {
    released: false,
    releases: 0,
    async release() {
      this.releases++;
      this.released = true;
      this.dispatchEvent(new Event('release'));
    },
  });
}
function setup(t, { request, supported = true, visible = true } = {}) {
  const requests = [];
  const locks = [];
  const win = Object.assign(new EventTarget(), { navigator: {} });
  if (supported) win.navigator.wakeLock = { request(type) {
    requests.push(type);
    if (request) return request();
    const result = lock();
    locks.push(result);
    return Promise.resolve(result);
  } };
  const doc = Object.assign(new EventTarget(), {
    defaultView: win, visibilityState: visible ? 'visible' : 'hidden',
  });
  const controller = createScreenWakeLock(doc);
  t.after(() => controller.destroy());
  return { controller, requests, locks, win, visibility(value) {
    doc.visibilityState = value;
    doc.dispatchEvent(new Event('visibilitychange'));
  } };
}

test('holds one screen lock while active and releases on pause and teardown', async t => {
  const { controller, requests, locks } = setup(t);
  assert.deepEqual(requests, []);
  controller.setActive(true);
  for (let i = 0; i < 100; i++) controller.setActive(true);
  await flush();
  assert.deepEqual(requests, ['screen']);
  assert.equal(locks[0].released, false);
  controller.setActive(false);
  await flush();
  assert.equal(locks[0].releases, 1);
  controller.setActive(true);
  await flush();
  assert.equal(requests.length, 2);
  controller.destroy();
  assert.equal(locks[1].releases, 1);
  controller.setActive(true);
  assert.equal(requests.length, 2);
});

test('only reacquires for a visible active timer, including back/forward cache restore', async t => {
  const { controller, requests, locks, visibility, win } = setup(t, { visible: false });
  controller.setActive(true);
  assert.equal(requests.length, 0);
  visibility('visible'); await flush();
  visibility('hidden');
  assert.equal(locks[0].released, true);
  visibility('visible'); await flush();
  assert.equal(requests.length, 2);
  win.dispatchEvent(new Event('pagehide'));
  assert.equal(locks[1].released, true);
  controller.setActive(true);
  assert.equal(requests.length, 2, 'ticks cannot reacquire on a suspended page');
  win.dispatchEvent(new Event('pageshow')); await flush();
  assert.equal(requests.length, 3);
  controller.setActive(false);
  visibility('hidden'); visibility('visible');
  assert.equal(requests.length, 3, 'returning to a paused timer stays unlocked');
  controller.destroy();
  win.dispatchEvent(new Event('pageshow'));
  visibility('visible');
  assert.equal(requests.length, 3);
});

test('unsupported browsers, denied requests, and synchronous failures are harmless', async t => {
  const unsupported = setup(t, { supported: false });
  unsupported.controller.setActive(true); await flush();
  assert.equal(unsupported.requests.length, 0);
  for (const request of [
    () => Promise.reject(new Error('NotAllowedError')),
    () => { throw new Error('SecurityError'); },
  ]) {
    const { controller, requests, visibility } = setup(t, { request });
    controller.setActive(true); await flush();
    for (let i = 0; i < 100; i++) controller.setActive(true);
    await flush();
    assert.equal(requests.length, 1, 'no retry loop after denial');
    visibility('hidden'); visibility('visible'); await flush();
    assert.equal(requests.length, 2, 'returning to the timer can retry');
  }
});

test('system revocation is respected until another activation', async t => {
  const { controller, requests, locks, visibility } = setup(t);
  controller.setActive(true); await flush();
  await locks[0].release();
  for (let i = 0; i < 100; i++) controller.setActive(true);
  await flush();
  assert.equal(requests.length, 1);
  visibility('hidden'); visibility('visible'); await flush();
  assert.equal(requests.length, 2);
  assert.equal(locks[1].released, false);
});

test('late grants are released after pause, hide, navigation, or destruction', async t => {
  for (const stop of [
    state => state.controller.setActive(false),
    state => state.visibility('hidden'),
    state => state.win.dispatchEvent(new Event('pagehide')),
    state => state.controller.destroy(),
  ]) {
    const pending = deferred();
    const state = setup(t, { request: () => pending.promise });
    state.controller.setActive(true);
    stop(state);
    const late = lock();
    pending.resolve(late); await flush();
    assert.equal(late.releases, 1);
    assert.equal(state.requests.length, 1);
  }
});

test('rapid pause/resume replaces a stale pending grant without duplicate requests', async t => {
  const first = deferred();
  const second = deferred();
  const queue = [first, second];
  const { controller, requests } = setup(t, { request: () => queue.shift().promise });
  controller.setActive(true);
  controller.setActive(false);
  controller.setActive(true);
  assert.equal(requests.length, 1);
  const stale = lock();
  first.resolve(stale); await flush();
  assert.equal(stale.released, true);
  assert.equal(requests.length, 2);
  const current = lock();
  second.resolve(current); await flush();
  assert.equal(current.released, false);
  controller.setActive(false);
  assert.equal(current.releases, 1);
});
