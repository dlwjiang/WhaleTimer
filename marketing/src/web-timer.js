import { Pomodoro, PRESETS, formatTime } from './pomodoro.js';
import { createFlipClock } from './lib/flip-clock.js';

export const STORAGE_KEY = 'tick-and-kin.web-pomodoro.v1';

export function mountTimer(root, { now = Date.now, storage } = {}) {
  const doc = root.ownerDocument;
  const win = doc.defaultView;
  const originalTitle = doc.title;
  // Storage may be unavailable in private/restricted browser contexts.
  try { storage ??= win.localStorage; } catch { /* The timer still works in memory. */ }
  let saved;
  try { saved = storage?.getItem(STORAGE_KEY); } catch { /* Use a fresh session. */ }
  const timer = Pomodoro.restore(saved, { now });
  const get = (selector) => root.querySelector(selector);
  const primary = get('[data-timer-toggle]');
  const reset = get('[data-timer-reset]');
  const label = get('[data-timer-phase]');
  const status = get('[data-timer-status]');
  const announcement = get('[data-timer-announcement]');
  const form = get('form');
  const fields = get('fieldset');
  const preset = get('[name="preset"]');
  const focus = get('[name="focus"]');
  const rest = get('[name="break"]');
  const error = get('[data-timer-error]');
  const settings = get('details');
  const clock = createFlipClock(get('[data-timer-display]'));
  let previousState = '';

  function save() {
    try { storage?.setItem(STORAGE_KEY, JSON.stringify(timer.serialize())); } catch { /* Optional persistence. */ }
  }

  function syncFields() {
    const value = timer.snapshot();
    focus.value = value.focusMinutes;
    rest.value = value.breakMinutes;
    preset.value = Object.keys(PRESETS).find(key => PRESETS[key].focusMinutes === value.focusMinutes
      && PRESETS[key].breakMinutes === value.breakMinutes) || 'custom';
  }

  function render() {
    const value = timer.snapshot();
    const phase = value.phase === 'focus' ? 'Focus' : 'Break';
    const active = value.status === 'running';
    const complete = value.status === 'complete';
    const paused = value.status === 'paused';
    const time = formatTime(value.remainingSeconds);
    const state = `${value.phase}:${value.status}`;
    clock.update(time, { animate: active && !doc.hidden });
    label.textContent = phase;
    status.textContent = complete ? 'Complete' : paused ? 'Paused' : active ? 'In progress' : 'Ready';
    primary.textContent = active ? 'Pause' : paused ? 'Resume' : complete
      ? (value.phase === 'focus' ? 'Start break' : 'Start focusing') : 'Start focusing';
    primary.disabled = false;
    reset.disabled = value.status === 'idle';
    fields.disabled = active || paused;
    root.dataset.state = value.status;
    // Only announce state changes; a screen reader should not speak every second.
    if (state !== previousState) {
      announcement.textContent = complete
        ? `${phase} complete. ${value.phase === 'focus' ? 'Start your break' : 'Start your next focus session'} when you’re ready.`
        : `${phase} ${value.status === 'idle' ? 'timer ready' : paused ? 'paused' : 'started'}.`;
      if (previousState) save();
      previousState = state;
    }
    doc.title = value.status === 'idle' ? originalTitle : complete ? `${phase} complete · Tick & Kin`
      : `${time} · ${phase}${paused ? ' paused' : ''} · Tick & Kin`;
  }

  function toggle() {
    if (timer.snapshot().status === 'running') timer.pause();
    else timer.start();
    settings.open = false;
    render(); save();
  }
  function restart() { timer.reset(); syncFields(); render(); save(); }
  function choosePreset() {
    const selected = PRESETS[preset.value];
    if (selected) { focus.value = selected.focusMinutes; rest.value = selected.breakMinutes; }
  }
  function custom() { preset.value = 'custom'; }
  function configure(event) {
    event.preventDefault();
    if (!form.reportValidity()) return;
    try {
      timer.configure({ focusMinutes: Number(focus.value), breakMinutes: Number(rest.value) });
      error.textContent = '';
      syncFields(); render(); save();
      settings.open = false;
      primary.focus();
    } catch (err) { error.textContent = err.message; }
  }
  function refresh() { render(); }
  function persist() { render(); save(); }
  primary.addEventListener('click', toggle);
  reset.addEventListener('click', restart);
  preset.addEventListener('change', choosePreset);
  focus.addEventListener('input', custom);
  rest.addEventListener('input', custom);
  form.addEventListener('submit', configure);
  doc.addEventListener('visibilitychange', refresh);
  win.addEventListener('pageshow', refresh);
  win.addEventListener('pagehide', persist);
  syncFields(); render();
  get('[data-timer-settings]').hidden = false;
  const interval = win.setInterval(render, 250);

  return { timer, refresh, destroy() {
    save();
    win.clearInterval(interval);
    clock.destroy();
    primary.removeEventListener('click', toggle);
    reset.removeEventListener('click', restart);
    preset.removeEventListener('change', choosePreset);
    focus.removeEventListener('input', custom);
    rest.removeEventListener('input', custom);
    form.removeEventListener('submit', configure);
    doc.removeEventListener('visibilitychange', refresh);
    win.removeEventListener('pageshow', refresh);
    win.removeEventListener('pagehide', persist);
    doc.title = originalTitle;
  } };
}
