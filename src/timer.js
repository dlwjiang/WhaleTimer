const SECOND = 1000;
export const DEFAULT_OVERTIME_SECONDS = 30;

export function validateOvertimeSeconds(value) {
  if (!Number.isInteger(value) || value < 1 || value > 86400) {
    throw new RangeError('超时提醒间隔须为 1 至 86400 秒的整数。');
  }
  return value;
}
const STATUSES = new Set(['idle', 'preparing', 'running', 'paused']);
function validateOvertimeAlerts(value) {
  if (typeof value !== 'boolean') throw new TypeError('重复超时提醒须为开启或关闭。');
  return value;
}

export const DEFAULT_DURATIONS = Object.freeze({ mainSeconds: 180, secondarySeconds: 120 });

/** Durations are whole seconds, from one second through 24 hours each. */
export function validateDurations({ mainSeconds, secondarySeconds }) {
  for (const [name, value] of Object.entries({ mainSeconds, secondarySeconds })) {
    if (!Number.isInteger(value) || value < 1 || value > 86400) {
      throw new RangeError(`${name === 'mainSeconds' ? '专注时长' : '加时时长'}须为 1 至 86400 秒的整数。`);
    }
  }
  return { mainSeconds, secondarySeconds };
}

/**
 * Clock-driven dual timer. UI polling never determines elapsed time.
 * Mutations and tick() return { snapshot, events }; snapshot() never consumes events.
 * Preparation gates freeze elapsed before each timer; late overdue ticks never
 * replay a reminder backlog.
 */
export class TimerEngine {
  constructor({ mainSeconds = 180, secondarySeconds = 120, overtimeSeconds = DEFAULT_OVERTIME_SECONDS, overtimeAlerts = true, now = Date.now } = {}) {
    Object.assign(this, validateDurations({ mainSeconds, secondarySeconds }));
    this.overtimeSeconds = validateOvertimeSeconds(overtimeSeconds);
    this.overtimeAlerts = validateOvertimeAlerts(overtimeAlerts);
    this.now = now;
    this.status = 'idle';
    this.preparationPhase = null;
    this.accumulatedMs = 0;
    this.highWaterMs = 0;
    this.runningSince = null;
    this.announcedStage = 0;
    this.lastReminderIndex = 0;
    this.lastCountdownNumber = 6;
  }

  elapsed(at = this.now()) {
    let measured = this.accumulatedMs + (this.status === 'running'
      ? Math.max(0, at - this.runningSince) : 0);
    // The secondary clock cannot start until its preparation has completed.
    if (this.announcedStage === 0) measured = Math.min(measured, this.mainSeconds * SECOND);
    // A system-clock correction must never refill sand or revisit an earlier phase.
    // After a backwards jump, freeze until the wall clock catches up.
    this.highWaterMs = Math.max(this.highWaterMs, measured);
    return this.highWaterMs;
  }

  snapshot() {
    const elapsedMs = this.elapsed();
    const mainMs = this.mainSeconds * SECOND;
    const secondaryMs = this.secondarySeconds * SECOND;
    const totalDurationMs = mainMs + secondaryMs;
    const phase = elapsedMs < mainMs ? 'focus' : elapsedMs < totalDurationMs ? 'grace' : 'overdue';
    const phaseDurationMs = phase === 'focus' ? mainMs : phase === 'grace' ? secondaryMs : 0;
    const phaseElapsedMs = phase === 'focus' ? elapsedMs : phase === 'grace' ? elapsedMs - mainMs : elapsedMs - totalDurationMs;
    return {
      status: this.status,
      preparationPhase: this.preparationPhase,
      phase,
      mainSeconds: this.mainSeconds,
      secondarySeconds: this.secondarySeconds,
      overtimeSeconds: this.overtimeSeconds,
      overtimeAlerts: this.overtimeAlerts,
      elapsedMs,
      phaseElapsedMs,
      phaseDurationMs,
      totalDurationMs,
      remainingMs: Math.max(0, phaseDurationMs - phaseElapsedMs),
      mainRemainingMs: Math.max(0, mainMs - elapsedMs),
      secondaryRemainingMs: Math.max(0, secondaryMs - Math.max(0, elapsedMs - mainMs)),
      overdueMs: Math.max(0, elapsedMs - totalDurationMs),
      progress: phaseDurationMs ? Math.min(1, phaseElapsedMs / phaseDurationMs) : 1,
    };
  }

  tick() {
    const snapshot = this.snapshot();
    const events = [];
    if (this.status !== 'running') return { snapshot, events };
    const { elapsedMs, totalDurationMs } = snapshot;
    if (elapsedMs >= this.mainSeconds * SECOND && this.announcedStage < 1) {
      events.push({ type: 'main-complete', elapsedMs, message: '时间到了，快一点啦！' });
      this.announcedStage = 1;
      this.accumulatedMs = this.mainSeconds * SECOND;
      this.highWaterMs = this.accumulatedMs;
      this.runningSince = null;
      this.status = 'preparing';
      this.preparationPhase = 'grace';
      return { snapshot: this.snapshot(), events };
    }
    let enteredOverdue = false;
    if (elapsedMs >= totalDurationMs && this.announcedStage < 2) {
      events.push({ type: 'secondary-complete', elapsedMs, message: '时间真的到了！我要生气了！' });
      this.announcedStage = 2;
      enteredOverdue = true;
    }
    if (snapshot.phase === 'grace') {
      const number = Math.ceil(snapshot.remainingMs / SECOND);
      if (number >= 1 && number <= 5 && number < this.lastCountdownNumber) {
        // Speak only the current digit after a delayed callback.
        events.push({ type: 'secondary-countdown', number, elapsedMs });
        this.lastCountdownNumber = number;
      }
    }
    if (elapsedMs >= totalDurationMs && this.overtimeAlerts) {
      const reminderIndex = Math.floor((elapsedMs - totalDurationMs) / (this.overtimeSeconds * SECOND));
      if (reminderIndex > this.lastReminderIndex) {
        // The phase announcement takes priority on the first overdue tick.
        if (!enteredOverdue) events.push({ type: 'overdue-reminder', elapsedMs, reminderIndex });
        this.lastReminderIndex = reminderIndex;
      }
    }
    return { snapshot, events };
  }

  start() {
    if (this.status === 'running') return this.tick();
    if (this.status === 'preparing') return { snapshot: this.snapshot(), events: [] };
    if (this.status === 'idle') this.preparationPhase = 'focus';
    if (this.preparationPhase) {
      this.status = 'preparing';
      return { snapshot: this.snapshot(), events: [] };
    }
    this.status = 'running';
    this.runningSince = this.now();
    return this.tick();
  }

  completePreparation() {
    if (this.status !== 'preparing') return { snapshot: this.snapshot(), events: [] };
    this.preparationPhase = null;
    this.status = 'running';
    this.runningSince = this.now();
    return this.tick();
  }

  pause() {
    const result = this.tick();
    if (this.status === 'running' || this.status === 'preparing') {
      this.accumulatedMs = result.snapshot.elapsedMs;
      this.runningSince = null;
      this.status = 'paused';
    }
    return { snapshot: this.snapshot(), events: result.events };
  }

  resume() {
    return this.start();
  }

  reset() {
    this.status = 'idle';
    this.preparationPhase = null;
    this.accumulatedMs = 0;
    this.highWaterMs = 0;
    this.runningSince = null;
    this.announcedStage = 0;
    this.lastReminderIndex = 0;
    this.lastCountdownNumber = 6;
    return { snapshot: this.snapshot(), events: [] };
  }

  configure(durations) {
    // Validate the complete change before touching the current session.
    const validated = validateDurations(durations);
    const overtimeSeconds = validateOvertimeSeconds(durations.overtimeSeconds === undefined ? this.overtimeSeconds : durations.overtimeSeconds);
    const overtimeAlerts = validateOvertimeAlerts(durations.overtimeAlerts === undefined ? this.overtimeAlerts : durations.overtimeAlerts);
    Object.assign(this, validated, { overtimeSeconds, overtimeAlerts });
    return this.reset();
  }

  serialize() {
    const timestamp = this.now();
    const elapsedMs = this.elapsed(timestamp);
    // Preserve a backwards-clock freeze across reloads. For a running timer this
    // anchor can be in the future until wall time catches its last observed value.
    const savedAt = this.status === 'running'
      ? Math.max(timestamp, this.runningSince + elapsedMs - this.accumulatedMs)
      : timestamp;
    return {
      version: 1,
      mainSeconds: this.mainSeconds,
      secondarySeconds: this.secondarySeconds,
      overtimeSeconds: this.overtimeSeconds,
      overtimeAlerts: this.overtimeAlerts,
      status: this.status,
      preparationPhase: this.preparationPhase,
      elapsedMs,
      savedAt,
      announcedStage: this.announcedStage,
      lastReminderIndex: this.lastReminderIndex,
      lastCountdownNumber: this.lastCountdownNumber,
    };
  }

  /** Invalid/corrupt storage safely restores a fresh default timer. */
  static restore(data, { now = Date.now } = {}) {
    try {
      const saved = typeof data === 'string' ? JSON.parse(data) : data;
      // Version-one sessions saved before spoken countdowns have no marker.
      const lastCountdownNumber = saved?.lastCountdownNumber ?? 6;
      const preparationPhase = saved?.preparationPhase ?? null;
      if (!saved || saved.version !== 1 || !STATUSES.has(saved.status)
        || !Number.isFinite(saved.elapsedMs) || saved.elapsedMs < 0
        || !Number.isFinite(saved.savedAt) || saved.savedAt < 0
        || !Number.isInteger(saved.announcedStage) || saved.announcedStage < 0 || saved.announcedStage > 2
        || !Number.isSafeInteger(saved.lastReminderIndex) || saved.lastReminderIndex < 0
        || !Number.isInteger(lastCountdownNumber) || lastCountdownNumber < 1 || lastCountdownNumber > 6
        || ![null, 'focus', 'grace'].includes(preparationPhase)
        || (saved.status === 'preparing' && !preparationPhase)
        || (preparationPhase && !['preparing', 'paused'].includes(saved.status))) {
        return new TimerEngine({ now });
      }
      const timer = new TimerEngine({ ...validateDurations(saved), overtimeSeconds: saved.overtimeSeconds === undefined ? DEFAULT_OVERTIME_SECONDS : saved.overtimeSeconds, overtimeAlerts: saved.overtimeAlerts === undefined ? true : saved.overtimeAlerts, now });
      const mainMs = timer.mainSeconds * SECOND;
      const totalMs = mainMs + timer.secondarySeconds * SECOND;
      // Reject impossible event markers, including an idle session with elapsed time.
      if ((saved.status === 'idle' && (saved.elapsedMs !== 0 || saved.announcedStage !== 0 || saved.lastReminderIndex !== 0))
        || (saved.announcedStage >= 1 && saved.elapsedMs < mainMs)
        || (saved.announcedStage >= 2 && saved.elapsedMs < totalMs)
        || (preparationPhase === 'focus' && (saved.elapsedMs !== 0 || saved.announcedStage !== 0))
        || (preparationPhase === 'grace' && (saved.elapsedMs !== mainMs || saved.announcedStage !== 1 || lastCountdownNumber !== 6))
        || (lastCountdownNumber < 6 && (saved.elapsedMs < mainMs
          || Math.ceil((totalMs - saved.elapsedMs) / SECOND) > lastCountdownNumber))
        || saved.lastReminderIndex > Math.max(0, Math.floor((saved.elapsedMs - totalMs) / (timer.overtimeSeconds * SECOND)))) {
        return new TimerEngine({ now });
      }
      timer.status = saved.status === 'preparing' ? 'paused' : saved.status;
      timer.preparationPhase = preparationPhase;
      const timestamp = now();
      timer.accumulatedMs = saved.elapsedMs + (saved.status === 'running' ? Math.max(0, timestamp - saved.savedAt) : 0);
      if (saved.announcedStage === 0) timer.accumulatedMs = Math.min(timer.accumulatedMs, mainMs);
      timer.highWaterMs = timer.accumulatedMs;
      timer.runningSince = saved.status === 'running' ? Math.max(timestamp, saved.savedAt) : null;
      timer.announcedStage = saved.announcedStage;
      timer.lastReminderIndex = saved.lastReminderIndex;
      timer.lastCountdownNumber = lastCountdownNumber;
      return timer;
    } catch {
      return new TimerEngine({ now });
    }
  }
}
