// Keep the screen on only while an active timer is visible. Browsers may deny
// or revoke this request (for example in power-saving mode); timing still works.
export function createScreenWakeLock(doc) {
  const win = doc.defaultView;
  const api = win.navigator.wakeLock;
  let active = false;
  let suspended = false;
  let destroyed = false;
  let eligible = false;
  let generation = 0;
  let pending = false;
  let sentinel = null;

  async function release(lock) {
    try { await lock.release(); } catch { /* The browser may already have released it. */ }
  }

  async function acquire() {
    if (!eligible || pending || sentinel || !api?.request) return;
    pending = true;
    const requestedGeneration = generation;
    try {
      const lock = await api.request('screen');
      // A pause, reset, hidden page, or teardown can happen before it resolves.
      if (!eligible || requestedGeneration !== generation) {
        await release(lock);
      } else if (!lock.released) {
        sentinel = lock;
        lock.addEventListener('release', () => {
          if (sentinel === lock) sentinel = null;
          // Respect system revocation; retry on the next activation, not ticks.
        }, { once: true });
      }
    } catch { /* Unsupported policies and low battery must not stop the timer. */ }
    finally {
      pending = false;
      // If we resumed while an old request was pending, obtain a fresh lock.
      if (requestedGeneration !== generation) void acquire();
    }
  }

  function sync() {
    const next = active && !destroyed && !suspended && doc.visibilityState === 'visible';
    if (next === eligible) return;
    eligible = next;
    generation++;
    if (eligible) void acquire();
    else if (sentinel) {
      const lock = sentinel;
      sentinel = null;
      void release(lock);
    }
  }

  const hide = () => { suspended = true; sync(); };
  const show = () => { suspended = false; sync(); };
  doc.addEventListener('visibilitychange', sync);
  win.addEventListener('pagehide', hide);
  win.addEventListener('pageshow', show);

  return {
    setActive(value) { active = value; sync(); },
    destroy() {
      destroyed = true;
      sync();
      doc.removeEventListener('visibilitychange', sync);
      win.removeEventListener('pagehide', hide);
      win.removeEventListener('pageshow', show);
    },
  };
}
