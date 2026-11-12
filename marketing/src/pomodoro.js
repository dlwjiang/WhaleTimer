import { TimerEngine } from './lib/timer.js';

export const PRESETS = Object.freeze({
  gentle: { focusMinutes: 15, breakMinutes: 3 },
  classic: { focusMinutes: 25, breakMinutes: 5 },
  deep: { focusMinutes: 50, breakMinutes: 10 },
  quick: { focusMinutes: 1, breakMinutes: 1 },
});

function validate({ focusMinutes, breakMinutes }) {
  if (!Number.isInteger(focusMinutes) || focusMinutes < 1 || focusMinutes > 120
    || !Number.isInteger(breakMinutes) || breakMinutes < 1 || breakMinutes > 60) {
    throw new RangeError('Use 1–120 minutes for focus and 1–60 minutes for breaks.');
  }
  return { focusMinutes, breakMinutes };
}

// The original engine's secondary phase is overtime, not a Pomodoro break.
// Reuse its clock, pause, and persistence logic for one explicitly started phase
// at a time; never convert time away from the page into completed work cycles.
export class Pomodoro {
  constructor({ now = Date.now, ...durations } = {}) {
    this.now = now;
    this.durations = validate({ ...PRESETS.classic, ...durations });
    this.phase = 'focus';
    this.engine = this.newEngine();
  }

  newEngine() {
    return new TimerEngine({
      mainSeconds: this.durations[this.phase === 'focus' ? 'focusMinutes' : 'breakMinutes'] * 60,
      secondarySeconds: 0, overtimeAlerts: false, now: this.now,
    });
  }

  snapshot() {
    let { snapshot } = this.engine.tick();
    const complete = snapshot.remainingMs === 0;
    if (complete && snapshot.status === 'running') snapshot = this.engine.pause().snapshot;
    return { phase: this.phase, status: complete ? 'complete' : snapshot.status,
      remainingSeconds: Math.ceil(snapshot.remainingMs / 1000), ...this.durations };
  }

  start() {
    if (this.snapshot().status === 'complete') {
      this.phase = this.phase === 'focus' ? 'break' : 'focus';
      this.engine = this.newEngine();
    }
    this.engine.start();
    this.engine.completePreparation();
    return this.snapshot();
  }

  pause() { this.engine.pause(); return this.snapshot(); }

  reset() {
    this.phase = 'focus';
    this.engine = this.newEngine();
    return this.snapshot();
  }

  configure(durations) {
    if (['running', 'paused'].includes(this.snapshot().status)) {
      throw new Error('Reset the timer before changing its durations.');
    }
    this.durations = validate(durations);
    return this.reset();
  }

  serialize() {
    this.snapshot();
    return { version: 1, phase: this.phase, durations: this.durations, engine: this.engine.serialize() };
  }

  static restore(data, { now = Date.now } = {}) {
    try {
      const saved = typeof data === 'string' ? JSON.parse(data) : data;
      if (saved?.version !== 1 || !['focus', 'break'].includes(saved.phase)) throw new Error('Invalid session');
      const timer = new Pomodoro({ ...validate(saved.durations), now });
      timer.phase = saved.phase;
      const engine = TimerEngine.restore(saved.engine, { now });
      if (engine.mainSeconds !== timer.newEngine().mainSeconds || engine.secondarySeconds !== 0
        || engine.overtimeAlerts || engine.preparationPhase !== null) throw new Error('Invalid timer');
      timer.engine = engine;
      timer.snapshot();
      return timer;
    } catch {
      return new Pomodoro({ now });
    }
  }
}

export function formatTime(seconds) {
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}
