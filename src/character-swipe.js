/** Horizontal character browsing, leaving vertical scrolling and controls alone. */
export function createCharacterSwipe(surface, { onSwipe, onStart = () => {}, onDrag = () => {}, onRelease = () => {}, canStart = () => true }) {
  let gesture = null;
  let suppressClick = false;
  const cleanups = [];
  const on = (type, listener, options) => {
    surface.addEventListener(type, listener, options);
    cleanups.push(() => surface.removeEventListener(type, listener, options));
  };
  function clear(cancel = true) {
    const current = gesture;
    gesture = null;
    delete surface.dataset.swiping;
    if (cancel && current?.horizontal) onRelease(0);
    if (current) {
      try { surface.releasePointerCapture(current.id); } catch { /* Already released or cancelled. */ }
    }
  }
  on('pointerdown', event => {
    // A second finger cancels browsing so pinch zoom can take over.
    if (gesture) { suppressClick = true; clear(); return; }
    suppressClick = false;
    if (event.isPrimary === false || event.button !== 0 || !canStart(event.target)) return;
    gesture = { id: event.pointerId, x: event.clientX, y: event.clientY, horizontal: false,
      lastX: event.clientX, lastTime: event.timeStamp, velocity: 0,
      travel: Math.max(180, Math.min(360, surface.clientWidth * .55)) };
  });
  on('pointermove', event => {
    if (!gesture || event.pointerId !== gesture.id) return;
    const dx = event.clientX - gesture.x;
    const dy = event.clientY - gesture.y;
    if (!gesture.horizontal) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < 12) return;
      suppressClick = true;
      if (Math.abs(dy) >= Math.abs(dx)) { clear(); return; }
      if (Math.abs(dx) < Math.abs(dy) * 1.3) return;
      gesture.horizontal = true;
      try { surface.setPointerCapture(event.pointerId); } catch { /* Events still bubble within the scene. */ }
      surface.dataset.swiping = 'true';
      onStart();
    }
    if (event.cancelable) event.preventDefault();
    const elapsed = event.timeStamp - gesture.lastTime;
    if (elapsed >= 8) {
      gesture.velocity = (event.clientX - gesture.lastX) / elapsed;
      gesture.lastX = event.clientX;
      gesture.lastTime = event.timeStamp;
    }
    onDrag(Math.max(-1, Math.min(1, -dx / gesture.travel)));
  });
  on('pointerup', event => {
    if (!gesture || event.pointerId !== gesture.id) return;
    const dx = event.clientX - gesture.x;
    const dy = event.clientY - gesture.y;
    const threshold = Math.max(48, Math.min(90, surface.clientWidth * .14));
    const flick = Math.abs(dx) >= 32 && event.timeStamp - gesture.lastTime < 100
      && Math.abs(gesture.velocity) >= .55 && Math.sign(gesture.velocity) === Math.sign(dx);
    const complete = gesture.horizontal && (Math.abs(dx) >= threshold || flick) && Math.abs(dx) > Math.abs(dy) * 1.3;
    const horizontal = gesture.horizontal;
    const direction = complete ? (dx < 0 ? 1 : -1) : 0;
    clear(false);
    if (complete) onSwipe(direction);
    if (horizontal) onRelease(direction);
  });
  on('pointercancel', event => { if (gesture?.id === event.pointerId) clear(); });
  on('lostpointercapture', event => {
    // Touch starts with implicit capture on the avatar. Taking capture on the
    // scene bubbles a loss event from that child; it is a handoff, not a cancel.
    // Only losing the scene's own capture should end an active drag.
    if (event.target === surface && gesture?.id === event.pointerId) clear();
  });
  const view = surface.ownerDocument.defaultView;
  const cancel = () => clear();
  view.addEventListener('blur', cancel);
  cleanups.push(() => view.removeEventListener('blur', cancel));
  // Browsers may dispatch a click after a drag; don't turn it into a greeting.
  on('click', event => {
    if (suppressClick && event.detail !== 0) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
    suppressClick = false;
  }, true);
  return { destroy() { clear(); cleanups.forEach(cleanup => cleanup()); } };
}
