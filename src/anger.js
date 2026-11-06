// Head centers within each square, contained character sprite.
const heads = { whale: [.47, .23], claude: [.5, .20], chatgpt: [.5, .21] };
const angles = [-140, -40, -110, -70, -165, -15, -125, -55, -95, -85, -150, -30];

export function createAngerEmojis({ element, avatar, container, character }) {
  let count = -1;
  function position() {
    if (count <= 0) return;
    const bounds = container.getBoundingClientRect();
    const sprite = avatar.getBoundingClientRect();
    const size = Math.min(sprite.width, sprite.height);
    const [x, y] = heads[character()] ?? heads.whale;
    const centerX = sprite.left - bounds.left + (sprite.width - size) / 2 + size * x;
    const centerY = sprite.top - bounds.top + (sprite.height - size) / 2 + size * y;
    Array.from(element.children).forEach((mark, index) => {
      const angle = (angles[index] ?? -90) * Math.PI / 180;
      const outer = index >= 6 ? 1.3 : 1;
      const left = centerX + Math.cos(angle) * size * .23 * outer;
      const top = centerY + Math.sin(angle) * size * .15 * outer;
      mark.style.left = `${Math.max(24, Math.min(bounds.width - 24, left))}px`;
      mark.style.top = `${Math.max(24, top)}px`;
    });
  }
  function update(nextCount, paused = false) {
    element.classList.toggle('is-paused', paused);
    if (count !== nextCount) {
      count = nextCount;
      element.hidden = count === 0;
      element.setAttribute('aria-label', `已超时警告 ${count} 次`);
      const visible = Math.min(count, angles.length);
      // Preserve existing nodes so ordinary ticks and new warnings don't restart their motion.
      element.querySelector('.anger-overflow')?.remove();
      while (element.children.length > visible) element.lastChild.remove();
      while (element.children.length < visible) {
        const index = element.children.length;
        const mark = element.ownerDocument.createElement('span');
        mark.className = 'anger-emoji';
        mark.setAttribute('aria-hidden', 'true');
        mark.style.setProperty('--float-delay', `${-index * .37}s`);
        const glyph = element.ownerDocument.createElement('span');
        glyph.textContent = '💢';
        mark.append(glyph);
        element.append(mark);
      }
      if (count > visible) {
        const extra = element.ownerDocument.createElement('span');
        extra.className = 'anger-emoji anger-overflow';
        extra.setAttribute('aria-hidden', 'true');
        extra.textContent = `+${count - visible}`;
        element.append(extra);
      }
    }
    position();
  }
  return { update, position };
}
