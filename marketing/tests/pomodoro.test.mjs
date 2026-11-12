import test from 'node:test';
import assert from 'node:assert/strict';
import { Pomodoro, PRESETS, formatTime } from '../src/pomodoro.js';

function setup(durations = PRESETS.quick) {
  let time = 100_000;
  const now = () => time;
  return { timer: new Pomodoro({ ...durations, now }), now, advance(ms) { time += ms; } };
}

test('focus and break each wait for an explicit start, even after a long background delay', () => {
  const { timer, advance } = setup();
  assert.equal(timer.snapshot().status, 'idle');
  timer.start();
  advance(10_000);
  assert.equal(timer.snapshot().remainingSeconds, 50);
  advance(3_600_000);
  assert.deepEqual(timer.snapshot(), { phase: 'focus', status: 'complete', remainingSeconds: 0, ...PRESETS.quick });
  advance(3_600_000);
  assert.equal(timer.snapshot().phase, 'focus');
  assert.equal(timer.start().phase, 'break');
  assert.equal(timer.snapshot().remainingSeconds, 60);
  advance(60_000);
  assert.equal(timer.snapshot().status, 'complete');
  assert.equal(timer.snapshot().phase, 'break');
  assert.equal(timer.start().phase, 'focus');
  assert.equal(timer.snapshot().remainingSeconds, 60);
});

test('pause freezes elapsed time, resume keeps the remainder, reset returns to focus', () => {
  const { timer, advance } = setup();
  timer.start(); advance(12_500); timer.pause(); advance(600_000);
  assert.equal(timer.snapshot().remainingSeconds, 48);
  timer.start(); advance(47_500);
  assert.equal(timer.snapshot().status, 'complete');
  timer.start(); advance(10_000);
  assert.equal(timer.snapshot().phase, 'break');
  timer.reset();
  assert.deepEqual(timer.snapshot(), { phase: 'focus', status: 'idle', remainingSeconds: 60, ...PRESETS.quick });
});

test('reload restores running, paused, and completed sessions without starting the next phase', () => {
  const { timer, advance, now } = setup();
  timer.start(); advance(10_000);
  const saved = JSON.stringify(timer.serialize());
  advance(20_000);
  const running = Pomodoro.restore(saved, { now });
  assert.equal(running.snapshot().remainingSeconds, 30);
  assert.equal(running.snapshot().status, 'running');
  running.pause();
  const paused = JSON.stringify(running.serialize());
  advance(100_000);
  assert.equal(Pomodoro.restore(paused, { now }).snapshot().remainingSeconds, 30);
  const complete = Pomodoro.restore(saved, { now });
  assert.equal(complete.snapshot().status, 'complete');
  assert.equal(complete.snapshot().phase, 'focus');
  complete.start();
  const breakSaved = complete.serialize();
  advance(10_000);
  const restoredBreak = Pomodoro.restore(breakSaved, { now });
  assert.equal(restoredBreak.snapshot().phase, 'break');
  assert.equal(restoredBreak.snapshot().remainingSeconds, 50);
});

test('invalid storage falls back to 25/5 and original overtime sessions cannot leak into Pomodoro', () => {
  for (const value of [null, '{', {}, { version: 99 }, { version: 1, phase: 'grace' },
    { version: 1, phase: 'focus', durations: { focusMinutes: Infinity, breakMinutes: 5 } }]) {
    assert.equal(Pomodoro.restore(value).snapshot().remainingSeconds, 1500);
  }
  const { timer } = setup();
  const saved = timer.serialize();
  saved.engine.secondarySeconds = 120;
  assert.equal(Pomodoro.restore(saved).snapshot().remainingSeconds, 1500);
});

test('duration changes validate atomically and do not discard an active session', () => {
  const { timer, advance } = setup();
  timer.start(); advance(1000);
  assert.throws(() => timer.configure(PRESETS.deep), /Reset/);
  timer.pause();
  assert.throws(() => timer.configure(PRESETS.deep), /Reset/);
  timer.reset();
  for (const focusMinutes of [0, -1, 1.5, 121, NaN]) {
    assert.throws(() => timer.configure({ focusMinutes, breakMinutes: 5 }), RangeError);
    assert.equal(timer.snapshot().focusMinutes, 1);
  }
  timer.configure({ focusMinutes: 120, breakMinutes: 60 });
  assert.equal(formatTime(timer.snapshot().remainingSeconds), '120:00');
  assert.equal(formatTime(59), '00:59');
});

test('a backward clock adjustment never adds time, including across reloads', () => {
  const { timer, advance, now } = setup();
  timer.start(); advance(20_000);
  assert.equal(timer.snapshot().remainingSeconds, 40);
  advance(-10_000);
  assert.equal(timer.snapshot().remainingSeconds, 40);
  const restored = Pomodoro.restore(timer.serialize(), { now });
  advance(5_000);
  assert.equal(restored.snapshot().remainingSeconds, 40);
  advance(10_000);
  assert.equal(restored.snapshot().remainingSeconds, 35);
});
