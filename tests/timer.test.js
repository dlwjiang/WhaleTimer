import test from 'node:test';
import assert from 'node:assert/strict';
import { TimerEngine, validateDurations } from '../src/timer.js';

function clockTimer(options = {}) {
  let time = 1000000;
  const now = () => time;
  return { timer: new TimerEngine({ ...options, now }), now, advance: ms => { time += ms; } };
}
const types = result => result.events.map(event => event.type);
const beginFocus = timer => { timer.start(); return timer.completePreparation(); };
function beginGrace(timer, advance) {
  beginFocus(timer); advance(timer.mainSeconds * 1000); timer.tick();
  return timer.completePreparation();
}

test('fresh start waits for focus preparation without consuming time', () => {
  const { timer, advance } = clockTimer();
  assert.equal(timer.snapshot().remainingMs, 180000);
  assert.equal(timer.completePreparation().snapshot.status, 'idle');
  const result = timer.start();
  assert.equal(result.snapshot.status, 'preparing');
  assert.equal(result.snapshot.preparationPhase, 'focus');
  assert.deepEqual(types(result), []);
  advance(600000);
  assert.equal(timer.tick().snapshot.elapsedMs, 0);
  assert.equal(timer.start().snapshot.status, 'preparing');
  assert.equal(timer.completePreparation().snapshot.status, 'running');
  assert.equal(timer.snapshot().preparationPhase, null);
  advance(1000); timer.completePreparation(); advance(1000);
  assert.equal(timer.snapshot().elapsedMs, 2000);
});

test('main boundary gates grace; secondary and overdue begin only after preparation', () => {
  const { timer, advance } = clockTimer();
  beginFocus(timer); advance(179999);
  assert.equal(timer.tick().snapshot.remainingMs, 1);
  advance(1);
  const main = timer.tick();
  assert.deepEqual(types(main), ['main-complete']);
  assert.equal(main.snapshot.status, 'preparing');
  assert.equal(main.snapshot.preparationPhase, 'grace');
  assert.equal(main.snapshot.phase, 'grace');
  assert.equal(main.snapshot.remainingMs, 120000);
  advance(600000);
  assert.equal(timer.tick().snapshot.elapsedMs, 180000);
  assert.deepEqual(types(timer.tick()), []);
  timer.completePreparation(); advance(120000);
  assert.deepEqual(types(timer.tick()), ['secondary-complete']);
  assert.equal(timer.snapshot().phase, 'overdue');
  advance(29999); assert.deepEqual(types(timer.tick()), []);
  advance(1); assert.deepEqual(types(timer.tick()), ['overdue-reminder']);
  assert.deepEqual(types(timer.tick()), []);
});

test('delayed main callback clamps at grace gate; overdue callbacks never burst', () => {
  const { timer, advance } = clockTimer();
  beginFocus(timer); advance(600000);
  assert.equal(timer.snapshot().elapsedMs, 180000);
  const late = timer.tick();
  assert.deepEqual(types(late), ['main-complete']);
  assert.equal(late.events[0].elapsedMs, 180000);
  assert.equal(late.snapshot.status, 'preparing');
  assert.equal(late.snapshot.overdueMs, 0);
  timer.completePreparation(); advance(600000);
  assert.deepEqual(types(timer.tick()), ['secondary-complete']);
  assert.equal(timer.snapshot().overdueMs, 480000);
  assert.deepEqual(types(timer.tick()), []);
  advance(120000); assert.deepEqual(types(timer.tick()), ['overdue-reminder']);
});

test('preparation pause/resume retains the gate; completion while paused is a no-op', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 2, secondarySeconds: 10 });
  timer.start();
  assert.equal(timer.pause().snapshot.preparationPhase, 'focus');
  advance(30000);
  assert.equal(timer.completePreparation().snapshot.status, 'paused');
  assert.equal(timer.resume().snapshot.status, 'preparing');
  assert.equal(timer.snapshot().elapsedMs, 0);
  timer.completePreparation(); advance(2000);
  const paused = timer.pause();
  assert.deepEqual(types(paused), ['main-complete']);
  assert.equal(paused.snapshot.status, 'paused');
  assert.equal(paused.snapshot.preparationPhase, 'grace');
  advance(30000);
  assert.equal(timer.resume().snapshot.status, 'preparing');
  assert.equal(timer.snapshot().remainingMs, 10000);
  timer.completePreparation(); advance(1000);
  assert.equal(timer.snapshot().remainingMs, 9000);
});

test('ordinary pause freezes elapsed and reminder cadence without redoing preparation', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 3, secondarySeconds: 2 });
  beginFocus(timer); advance(2000); timer.pause(); advance(999000);
  assert.equal(timer.snapshot().remainingMs, 1000);
  assert.equal(timer.resume().snapshot.status, 'running');
  advance(1000); timer.tick(); timer.completePreparation(); advance(2000);
  assert.deepEqual(types(timer.pause()), ['secondary-complete']);
  advance(30000); assert.deepEqual(types(timer.tick()), []);
  timer.resume(); advance(30000);
  assert.deepEqual(types(timer.tick()), ['overdue-reminder']);
});

test('reset clears preparation, elapsed and history while retaining configured durations', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 1, secondarySeconds: 1 });
  beginFocus(timer); advance(100000); timer.tick();
  const reset = timer.reset();
  assert.equal(reset.snapshot.status, 'idle');
  assert.equal(reset.snapshot.preparationPhase, null);
  assert.equal(reset.snapshot.phase, 'focus');
  assert.equal(reset.snapshot.remainingMs, 1000);
  assert.equal(timer.start().snapshot.preparationPhase, 'focus');
});

test('duration changes validate atomically and reset the session', () => {
  const { timer, advance } = clockTimer();
  beginFocus(timer); advance(1234);
  for (const value of [0, -1, 0.5, NaN, Infinity, '3', 86401, undefined]) {
    assert.throws(() => timer.configure({ mainSeconds: value, secondarySeconds: 120 }), RangeError);
  }
  assert.equal(timer.snapshot().elapsedMs, 1234);
  assert.equal(timer.snapshot().status, 'running');
  const configured = timer.configure({ mainSeconds: 600, secondarySeconds: 60 });
  assert.equal(configured.snapshot.status, 'idle');
  assert.equal(configured.snapshot.preparationPhase, null);
  assert.equal(configured.snapshot.remainingMs, 600000);
  assert.deepEqual(validateDurations({ mainSeconds: 1, secondarySeconds: 86400 }), { mainSeconds: 1, secondarySeconds: 86400 });
});

test('both preparations restore paused and require user-gesture replay', () => {
  for (const phase of ['focus', 'grace']) {
    const { timer, advance, now } = clockTimer({ mainSeconds: 1, secondarySeconds: 10 });
    timer.start();
    if (phase === 'grace') { timer.completePreparation(); advance(1000); timer.tick(); }
    const saved = JSON.stringify(timer.serialize()); advance(600000);
    const restored = TimerEngine.restore(saved, { now });
    assert.equal(restored.snapshot().status, 'paused');
    assert.equal(restored.snapshot().preparationPhase, phase);
    assert.equal(restored.snapshot().elapsedMs, phase === 'focus' ? 0 : 1000);
    assert.equal(restored.completePreparation().snapshot.status, 'paused');
    assert.equal(restored.resume().snapshot.status, 'preparing');
    assert.equal(restored.completePreparation().snapshot.status, 'running');
  }
});

test('running focus restoration counts time away but still stops at the grace gate', () => {
  const { timer, advance, now } = clockTimer();
  beginFocus(timer); advance(1000);
  const saved = timer.serialize(); advance(600000);
  const restored = TimerEngine.restore(saved, { now });
  assert.equal(restored.snapshot().elapsedMs, 180000);
  const result = restored.tick();
  assert.deepEqual(types(result), ['main-complete']);
  assert.equal(result.snapshot.status, 'preparing');
  assert.equal(result.snapshot.preparationPhase, 'grace');
});

test('running grace restoration counts time away and preserves consumed reminders', () => {
  const { timer, advance, now } = clockTimer({ mainSeconds: 3, secondarySeconds: 10 });
  beginGrace(timer, advance);
  const saved = JSON.stringify(timer.serialize()); advance(10000);
  const restored = TimerEngine.restore(saved, { now });
  assert.equal(restored.snapshot().elapsedMs, 13000);
  assert.deepEqual(types(restored.tick()), ['secondary-complete']);
  advance(30000); restored.tick();
  const again = TimerEngine.restore(restored.serialize(), { now });
  assert.deepEqual(types(again.tick()), []);
  advance(30000); assert.deepEqual(types(again.tick()), ['overdue-reminder']);
});

test('serialization never consumes announcements and paused restoration excludes time away', () => {
  const { timer, advance, now } = clockTimer();
  beginFocus(timer); advance(180000);
  const restored = TimerEngine.restore(timer.serialize(), { now });
  assert.deepEqual(types(restored.tick()), ['main-complete']);
  restored.completePreparation(); advance(1000); restored.pause();
  const saved = restored.serialize(); advance(999999);
  const paused = TimerEngine.restore(saved, { now });
  assert.equal(paused.snapshot().status, 'paused');
  assert.equal(paused.snapshot().preparationPhase, null);
  assert.equal(paused.snapshot().elapsedMs, 181000);
  assert.deepEqual(types(paused.tick()), []);
});

test('corrupt storage and impossible preparation markers fall back safely', () => {
  const { timer, now } = clockTimer();
  const valid = timer.serialize();
  for (const data of [null, '{', {}, { ...valid, version: 99 }, { ...valid, mainSeconds: -1 },
    { ...valid, elapsedMs: Infinity }, { ...valid, elapsedMs: 12 }, { ...valid, status: 'finished' },
    { ...valid, announcedStage: 2 }, { ...valid, lastReminderIndex: 1 },
    { ...valid, status: 'preparing' }, { ...valid, status: 'preparing', preparationPhase: 'overdue' },
    { ...valid, status: 'running', preparationPhase: 'focus' },
    { ...valid, status: 'paused', preparationPhase: 'grace' }]) {
    const restored = TimerEngine.restore(data, { now }).snapshot();
    assert.equal(restored.status, 'idle');
    assert.equal(restored.mainSeconds, 180);
    assert.equal(restored.elapsedMs, 0);
  }
});

test('overdue reminders continue for many hours without replay bursts', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 1, secondarySeconds: 1 });
  beginGrace(timer, advance); advance(1000); timer.tick();
  for (let hour = 0; hour < 48; hour++) {
    advance(3600000);
    assert.deepEqual(types(timer.tick()), ['overdue-reminder']);
    assert.deepEqual(types(timer.tick()), []);
  }
});

test('backwards clock correction freezes grace until catch-up and survives reload', () => {
  const { timer, advance, now } = clockTimer();
  beginGrace(timer, advance); advance(10000); timer.tick(); advance(-5000);
  assert.equal(timer.snapshot().elapsedMs, 190000);
  const restored = TimerEngine.restore(timer.serialize(), { now });
  assert.equal(restored.snapshot().elapsedMs, 190000);
  advance(4000); assert.equal(restored.snapshot().elapsedMs, 190000);
  advance(2000); assert.equal(restored.snapshot().elapsedMs, 191000);
  assert.deepEqual(types(restored.tick()), []);
});

test('pause/resume preserve clock high-water; reset starts fresh without negative elapsed', () => {
  const { timer, advance, now } = clockTimer();
  beginFocus(timer); advance(10000); timer.tick(); advance(-5000);
  assert.equal(timer.pause().snapshot.elapsedMs, 10000);
  const restored = TimerEngine.restore(timer.serialize(), { now });
  advance(20000); assert.equal(restored.snapshot().elapsedMs, 10000);
  restored.resume(); advance(1000);
  assert.equal(restored.snapshot().elapsedMs, 11000);
  advance(-5000); restored.reset();
  assert.equal(restored.snapshot().elapsedMs, 0);
  beginFocus(restored); advance(-500);
  assert.equal(restored.snapshot().elapsedMs, 0);
  advance(1500); assert.equal(restored.snapshot().elapsedMs, 1000);
});

test('secondary countdown stays silent at five and four, then emits three through one exactly once', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 10, secondarySeconds: 10 });
  beginFocus(timer); advance(5000); assert.deepEqual(types(timer.tick()), []);
  advance(5000); assert.deepEqual(types(timer.tick()), ['main-complete']);
  timer.completePreparation();
  for (const delta of [5000, 1000, 999]) {
    advance(delta); assert.deepEqual(types(timer.tick()), []);
  }
  advance(1);
  for (let number = 3; number >= 1; number--) {
    assert.deepEqual(timer.tick().events, [{ type: 'secondary-countdown', number, elapsedMs: 20000 - number * 1000 }]);
    assert.deepEqual(types(timer.tick()), []);
    advance(999); assert.deepEqual(types(timer.tick()), []); advance(1);
  }
  assert.deepEqual(types(timer.tick()), ['secondary-complete']);
});

test('late grace ticks emit only the current countdown digit', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 1, secondarySeconds: 10 });
  beginGrace(timer, advance); advance(7001);
  assert.equal(timer.tick().events[0].number, 3); advance(2000);
  assert.equal(timer.tick().events[0].number, 1); advance(2000);
  assert.deepEqual(types(timer.tick()), ['secondary-complete']);
});

test('short secondary countdowns emit nothing until grace preparation completes', () => {
  for (const secondarySeconds of [3, 2, 1]) {
    const { timer, advance } = clockTimer({ mainSeconds: 1, secondarySeconds });
    beginFocus(timer); advance(600000);
    assert.deepEqual(types(timer.tick()), ['main-complete']);
    advance(60000); assert.deepEqual(types(timer.tick()), []);
    assert.equal(timer.completePreparation().events[0].number, secondarySeconds);
    assert.deepEqual(types(timer.tick()), []);
  }
});

test('countdown pause and reload dedupe digits while legacy saves remain compatible', () => {
  const { timer, advance, now } = clockTimer({ mainSeconds: 1, secondarySeconds: 10 });
  beginGrace(timer, advance); advance(7000);
  assert.equal(timer.tick().events[0].number, 3);
  let restored = TimerEngine.restore(timer.serialize(), { now });
  assert.deepEqual(types(restored.tick()), []);
  restored.pause(); const saved = restored.serialize(); advance(60000);
  restored = TimerEngine.restore(saved, { now });
  assert.deepEqual(types(restored.tick()), []);
  assert.deepEqual(types(restored.resume()), []); advance(1000);
  assert.equal(restored.tick().events[0].number, 2);
  const legacy = restored.serialize();
  delete legacy.lastCountdownNumber; delete legacy.preparationPhase;
  const fromLegacy = TimerEngine.restore(legacy, { now });
  assert.equal(fromLegacy.snapshot().phase, 'grace');
  assert.equal(fromLegacy.tick().events[0].number, 2);
  assert.deepEqual(types(fromLegacy.tick()), []);
  for (const marker of [0, 7, 2.5, '4']) {
    assert.equal(TimerEngine.restore({ ...legacy, lastCountdownNumber: marker }, { now }).snapshot().status, 'idle');
  }
});

test('reset and configure clear countdown history', () => {
  const { timer, advance } = clockTimer({ mainSeconds: 1, secondarySeconds: 10 });
  const reachThree = () => {
    beginGrace(timer, advance); advance(7000);
    assert.equal(timer.tick().events[0].number, 3);
  };
  reachThree(); timer.reset();
  assert.equal(timer.serialize().lastCountdownNumber, 6);
  reachThree(); timer.configure({ mainSeconds: 1, secondarySeconds: 10 });
  assert.equal(timer.serialize().lastCountdownNumber, 6); reachThree();
});

test('custom overtime interval controls warning numbers through pause, restore and late ticks', () => {
  const { timer, advance, now } = clockTimer({ mainSeconds: 1, secondarySeconds: 1, overtimeSeconds: 10 });
  beginGrace(timer, advance); advance(1000); timer.tick();
  advance(9999); assert.deepEqual(types(timer.tick()), []);
  advance(1); assert.equal(timer.tick().events[0].reminderIndex, 1);
  timer.pause(); const saved = timer.serialize(); advance(90000);
  const restored = TimerEngine.restore(saved, { now });
  assert.equal(restored.snapshot().overtimeSeconds, 10);
  restored.resume(); advance(10000);
  assert.equal(restored.tick().events[0].reminderIndex, 2);
  advance(30000); assert.equal(restored.tick().events[0].reminderIndex, 5);
  assert.deepEqual(types(restored.tick()), []);
  restored.reset(); assert.equal(restored.snapshot().overtimeSeconds, 10);
});

test('overtime configuration validates atomically and legacy sessions default to 30 seconds', () => {
  const { timer, now } = clockTimer();
  timer.configure({ mainSeconds: 6, secondarySeconds: 12, overtimeSeconds: 45 });
  for (const value of [0, -1, 1.5, Infinity, NaN, '30', null, 86401]) {
    assert.throws(() => timer.configure({ mainSeconds: 10, secondarySeconds: 20, overtimeSeconds: value }), RangeError);
    assert.equal(timer.snapshot().mainSeconds, 6);
    assert.equal(timer.snapshot().overtimeSeconds, 45);
    assert.equal(TimerEngine.restore({ ...timer.serialize(), overtimeSeconds: value }, { now }).snapshot().overtimeSeconds, 30);
  }
  const legacy = timer.serialize(); delete legacy.overtimeSeconds;
  delete legacy.overtimeAlerts;
  assert.equal(TimerEngine.restore(legacy, { now }).snapshot().overtimeAlerts, true);
  assert.equal(TimerEngine.restore(legacy, { now }).snapshot().overtimeSeconds, 30);
});

test('disabled overtime alerts preserve completion and elapsed time through reset and restore', () => {
  const { timer, advance, now } = clockTimer({ mainSeconds: 1, secondarySeconds: 1, overtimeAlerts: false });
  beginGrace(timer, advance);
  advance(1000);
  assert.deepEqual(types(timer.tick()), ['secondary-complete']);
  advance(90000);
  assert.deepEqual(types(timer.tick()), []);
  assert.equal(timer.snapshot().overdueMs, 90000);
  assert.equal(timer.lastReminderIndex, 0);
  const restored = TimerEngine.restore(timer.serialize(), { now });
  assert.equal(restored.snapshot().overtimeAlerts, false);
  advance(60000);
  assert.deepEqual(types(restored.tick()), []);
  restored.reset();
  assert.equal(restored.snapshot().overtimeAlerts, false);
  restored.configure({ mainSeconds: 1, secondarySeconds: 1, overtimeAlerts: true });
  beginGrace(restored, advance); advance(1000); restored.tick();
  advance(30000);
  assert.equal(restored.tick().events[0].reminderIndex, 1);
});
