/** A split-flap display. The timer remains the source of truth; no animation timers. */
export function createFlipClock(element) {
  const document = element.ownerDocument;
  const readable = document.createElement('span');
  readable.className = 'sr-only';
  const face = document.createElement('span');
  face.className = 'flip-clock-face';
  face.setAttribute('aria-hidden', 'true');
  element.replaceChildren(readable, face);
  let previous = '';
  let slots = [];

  function settle(card) {
    card.classList.remove('is-flipping');
    card.querySelectorAll('.flip-moving').forEach(half => half.remove());
    const bottom = card.querySelector('.flip-bottom');
    if (bottom) bottom.dataset.value = card.dataset.value;
  }
  function half(className, value) {
    const node = document.createElement('span');
    node.className = className;
    node.dataset.value = value;
    return node;
  }
  function paint(card, value, oldValue, animate) {
    card.replaceChildren(half('flip-half flip-top', value), half('flip-half flip-bottom', animate ? oldValue : value));
    card.dataset.value = value;
    card.classList.toggle('is-flipping', animate);
    if (animate) {
      card.append(half('flip-half flip-top flip-moving flip-leave', oldValue),
        half('flip-half flip-bottom flip-moving flip-land', value));
    }
  }
  function onAnimationEnd(event) {
    if (event.target.classList.contains('flip-land')) settle(event.target.parentElement);
  }
  face.addEventListener('animationend', onAnimationEnd);

  return {
    update(value, { animate = true } = {}) {
      animate = animate && !document.defaultView?.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
      // Pausing or reduced motion reveals the current value immediately.
      if (!animate) slots.forEach(slot => { if (slot.classList.contains('flip-digit')) settle(slot); });
      if (value === previous) return;
      readable.textContent = value;
      element.dataset.time = value;
      const structure = text => text.replace(/\d/g, '#');
      const rebuild = structure(value) !== structure(previous);
      if (rebuild) {
        face.replaceChildren();
        slots = [...value].map(character => {
          const slot = document.createElement('span');
          slot.className = /\d/.test(character) ? 'flip-digit' : 'flip-separator';
          slot.dataset.value = character;
          face.append(slot);
          return slot;
        });
        face.style.setProperty('--flip-count', String(value.replace(/\D/g, '').length));
      }
      [...value].forEach((character, index) => {
        if (/\d/.test(character) && (rebuild || character !== previous[index])) {
          paint(slots[index], character, previous[index], animate && !rebuild);
        }
      });
      previous = value;
    },
    destroy() {
      face.removeEventListener('animationend', onAnimationEnd);
      slots.forEach(slot => { if (slot.classList.contains('flip-digit')) settle(slot); });
    },
  };
}
