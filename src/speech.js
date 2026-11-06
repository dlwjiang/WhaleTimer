// Mouth positions in the square character artwork; placement accounts for contain sizing.
const mouths = { whale: [.44, .39], claude: [.50, .32], chatgpt: [.50, .34] };
export function createSpeechCaption({ element, avatar, container, now = Date.now, character = () => 'whale' }) {
  let expiresAt = 0;
  let visible = false;
  let intro = null;
  function position() {
    if (!visible) return;
    const bounds = container.getBoundingClientRect();
    const sprite = avatar.getBoundingClientRect();
    const size = Math.min(sprite.width, sprite.height);
    const [x, y] = mouths[character()] ?? mouths.whale;
    const mouthX = sprite.left + (sprite.width - size) / 2 + size * x;
    const mouthY = sprite.top + (sprite.height - size) / 2 + size * y;
    const viewportWidth = container.ownerDocument.documentElement.clientWidth || globalThis.window?.innerWidth || bounds.right;
    const edge = Math.min(bounds.right, viewportWidth) - 16;
    const desiredLeft = mouthX + size * .055 - 20;
    const width = element.dataset.kind === 'countdown' && element.dataset.finish !== 'true' ? 98 : 224;
    const left = Math.max(bounds.left + 12, Math.min(desiredLeft, edge - Math.min(width, 146)));
    element.style.left = `${left - bounds.left}px`;
    element.style.top = `${mouthY - bounds.top + 8}px`;
    element.style.width = `${Math.max(0, Math.min(width, edge - left))}px`;
  }
  function show(text) {
    intro = null;
    const countdown = /^[一二三四五]$/.test(text) || text === '开始！';
    element.dataset.finish = String(text === '开始！');
    element.dataset.kind = countdown ? 'countdown' : /超时|生气|警告/.test(text) ? 'warning' : 'speech';
    const line = element.ownerDocument.createElement('span');
    line.className = 'speech-line';
    // textContent keeps caption text safe and allows each glyph to enter independently.
    Array.from(text).forEach((glyph, index, glyphs) => {
      const span = element.ownerDocument.createElement('span');
      span.className = 'speech-glyph';
      span.textContent = glyph;
      span.style.setProperty('--glyph-delay', `${Math.min(index * 32, 480)}ms`);
      span.style.setProperty('--glyph-tilt', `${(index % 3 - 1) * 3}deg`);
      line.append(span);
      if ((glyph === '，' || glyph === ',') && index < glyphs.length - 1) {
        line.append(element.ownerDocument.createElement('br'));
      }
    });
    element.replaceChildren(line);
    expiresAt = now() + (countdown ? 950 : Math.min(8000, Math.max(4200, text.length * 170)));
    visible = true;
    element.classList.add('is-visible');
    position();
  }
  function clear() {
    intro = null;
    visible = false;
    element.classList.remove('is-visible');
  }
  function startIntro(elapsedMs) {
    const startedAt = now();
    show('三');
    intro = { elapsedMs: elapsedMs ?? (() => now() - startedAt), beat: 0 };
  }
  function update() {
    if (intro) {
      const sequence = intro;
      const elapsed = Math.max(0, sequence.elapsedMs());
      // The bundled start clip has onsets at 0, .8, 1.6 and 2.4 seconds.
      if (elapsed >= 3350) clear();
      else {
        const beat = Math.min(3, Math.floor(elapsed / 800));
        if (beat !== sequence.beat) {
          show(['三', '二', '一', '开始！'][beat]);
          sequence.beat = beat;
          intro = sequence;
        }
      }
    }
    if (visible && !intro && now() >= expiresAt) {
      visible = false;
      element.classList.remove('is-visible');
    }
    position();
  }
  const observer = globalThis.ResizeObserver ? new ResizeObserver(position) : null;
  observer?.observe(avatar);
  observer?.observe(container);
  globalThis.window?.addEventListener('resize', position);
  return { show, startIntro, clear, update, position, destroy() {
    clear();
    observer?.disconnect();
    globalThis.window?.removeEventListener('resize', position);
    element.replaceChildren();
    element.classList.remove('is-visible');
  } };
}
