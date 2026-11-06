import { createMouthMeter } from './speech-envelope.js';

/** Animate only during recorded speech; never animate from a bell or a caption. */
export function createSpeaking({ avatar, audio, carousel }) {
  const document = avatar.ownerDocument;
  const view = document.defaultView;
  const motion = view.matchMedia?.('(prefers-reduced-motion: reduce)');
  const meter = createMouthMeter();
  let frame = null;
  let previous = 0;
  let speaker;
  let disposed = false;
  let blinkTimer;
  let blinkEnd;
  function scheduleBlink() {
    view.clearTimeout(blinkTimer);
    view.clearTimeout(blinkEnd);
    carousel.blink(false);
    if (disposed || motion?.matches || document.hidden) return;
    blinkTimer = view.setTimeout(() => {
      if (!avatar.closest('[data-status="paused"]') && !avatar.dataset.rotating) carousel.blink(true);
      blinkEnd = view.setTimeout(() => { carousel.blink(false); scheduleBlink(); }, 130);
    }, 3800 + Math.random() * 2200);
  }
  function stop() {
    if (frame !== null) view.cancelAnimationFrame(frame);
    frame = null;
    previous = 0;
    speaker = undefined;
    meter.reset();
    carousel.speak(null, 0);
  }
  function tick(time) {
    frame = null;
    if (disposed || motion?.matches || document.hidden) { stop(); return; }
    const state = audio.getSpeechFrame?.();
    if (!state?.active) { stop(); return; }
    if (speaker !== state.character) { meter.reset(); speaker = state.character; }
    const shape = meter.update(state.level, previous ? time - previous : 16);
    previous = time;
    carousel.speak(speaker, shape);
    frame = view.requestAnimationFrame(tick);
  }
  function refresh() {
    stop();
    if (!disposed && view.requestAnimationFrame && !motion?.matches && !document.hidden && audio.getSpeechFrame?.().active) {
      frame = view.requestAnimationFrame(tick);
    }
  }
  function preferenceChanged() { refresh(); scheduleBlink(); }
  const unsubscribe = audio.subscribeSpeech?.(refresh);
  document.addEventListener('visibilitychange', preferenceChanged);
  motion?.addEventListener('change', preferenceChanged);
  refresh();
  scheduleBlink();
  return {
    destroy() {
      disposed = true;
      stop();
      scheduleBlink();
      unsubscribe?.();
      document.removeEventListener('visibilitychange', preferenceChanged);
      motion?.removeEventListener('change', preferenceChanged);
    },
  };
}
