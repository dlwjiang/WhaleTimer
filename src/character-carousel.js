import { CHARACTERS, characterImage } from './characters.js';
import { sceneBackground } from './scene.js';

const wrap = value => ((value % CHARACTERS.length) + CHARACTERS.length) % CHARACTERS.length;
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

/** Three equally spaced stops around a cylinder; angles stay continuous across the seam. */
export function carouselFrame(position) {
  const start = Math.floor(position);
  const mix = position - start;
  return CHARACTERS.map((_, index) => {
    const offset = wrap(index - position + 1.5) - 1.5;
    const angle = offset * 2 * Math.PI / 3;
    const depth = Math.cos(angle);
    return {
      x: Math.sin(angle) * .3,
      z: (depth - 1) * .48,
      yaw: offset * 54,
      opacity: clamp((depth + .25) / .75, 0, 1),
      // Keep the lower scene opaque so a crossfade never exposes blank paper.
      backgroundOpacity: index === wrap(start) ? 1 : index === wrap(start + 1) ? mix : 0,
      backgroundLayer: index === wrap(start + 1) ? -2 : -3,
    };
  });
}

export function createCharacterCarousel(avatar, { index = 0 } = {}) {
  const document = avatar.ownerDocument;
  const view = document.defaultView;
  const motion = view.matchMedia?.('(prefers-reduced-motion: reduce)');
  let position = index;
  let target = index;
  let origin = index;
  let frame = null;
  let expression = 'idle';
  let disposed = false;
  const viewport = document.createElement('span');
  viewport.className = 'character-cylinder';
  avatar.append(viewport);
  const faces = CHARACTERS.map(character => {
    const backdrop = document.createElement('img');
    backdrop.className = 'scene-backdrop';
    backdrop.src = sceneBackground(character.id);
    backdrop.alt = '';
    backdrop.draggable = false;
    backdrop.setAttribute('aria-hidden', 'true');
    avatar.append(backdrop);
    const face = document.createElement('span');
    face.className = 'character-face';
    face.dataset.character = character.id;
    const images = Object.keys(character.images).map(name => {
      const image = document.createElement('img');
      image.dataset.expression = name;
      image.src = characterImage(character, name);
      image.draggable = false;
      face.append(image);
      return image;
    });
    viewport.append(face);
    return { face, images, backdrop };
  });

  function updateExpressions() {
    faces.forEach(({ face, images }, i) => {
      const active = i === wrap(target);
      face.setAttribute('aria-hidden', String(!active));
      images.forEach(image => {
        const visible = image.dataset.expression === expression;
        image.className = `${active ? 'avatar-image' : 'character-preview'}${visible ? ' is-visible' : ''}`;
        image.setAttribute('aria-hidden', String(!active || !visible));
        image.alt = active && visible ? CHARACTERS[i].description : '';
      });
    });
  }
  function paint() {
    const width = avatar.getBoundingClientRect().width || 360;
    carouselFrame(position).forEach((state, i) => {
      const { face, backdrop } = faces[i];
      face.style.transform = `translate3d(${state.x * width}px, 0, ${state.z * width}px) rotateY(${state.yaw}deg)`;
      face.style.opacity = String(state.opacity);
      face.style.visibility = state.opacity < .001 ? 'hidden' : 'visible';
      backdrop.style.opacity = String(state.backgroundOpacity);
      backdrop.style.zIndex = String(state.backgroundLayer);
    });
  }
  function stop() {
    if (frame !== null) view.cancelAnimationFrame(frame);
    frame = null;
  }
  function finish() {
    stop();
    position = target = wrap(target);
    delete avatar.dataset.rotating;
    paint();
  }
  function snap() {
    stop();
    if (motion?.matches || !view.requestAnimationFrame || Math.abs(target - position) < .001) {
      finish();
      return;
    }
    avatar.dataset.rotating = 'true';
    const from = position;
    const started = view.performance.now();
    const duration = 280;
    const animate = time => {
      if (disposed) return;
      const t = clamp((time - started) / duration, 0, 1);
      position = from + (target - from) * (1 - (1 - t) ** 4);
      paint();
      if (t < 1) frame = view.requestAnimationFrame(animate);
      else finish();
    };
    frame = view.requestAnimationFrame(animate);
  }
  function onMotionChange() { if (motion.matches) finish(); }
  motion?.addEventListener('change', onMotionChange);
  view.addEventListener('resize', paint);
  updateExpressions();
  paint();
  return {
    begin() { stop(); origin = position; avatar.dataset.rotating = 'true'; },
    drag(offset) {
      // Reduced motion retains the scene blend without rotating the sprites.
      position = origin + clamp(offset, -1, 1);
      if (!motion?.matches) paint();
      else carouselFrame(position).forEach((state, i) => {
        faces[i].backdrop.style.opacity = String(state.backgroundOpacity);
        faces[i].backdrop.style.zIndex = String(state.backgroundLayer);
      });
    },
    snap,
    select(nextIndex) {
      const delta = wrap(nextIndex - wrap(target) + 1) - 1;
      target += delta;
      updateExpressions();
      snap();
    },
    updateExpression(next) { expression = next; updateExpressions(); },
    destroy() {
      disposed = true;
      stop();
      view.removeEventListener('resize', paint);
      motion?.removeEventListener('change', onMotionChange);
      viewport.remove();
      faces.forEach(({ backdrop }) => backdrop.remove());
      delete avatar.dataset.rotating;
    },
  };
}
