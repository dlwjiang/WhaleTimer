const base = import.meta.env?.BASE_URL ?? '/';
const ns = 'http://www.w3.org/2000/svg';
let nextId = 0;
const EYES = {
  whale: [[201, 173, 200, 177], [254, 166, 255, 168]],
  claude: [[226, 142, 225, 146], [284, 132, 284, 134]],
  chatgpt: [[227, 155, 228, 160], [283, 145, 284, 147]],
};

// Measured in the original 512px canvases. Each pose gets its own registration
// and skin colors, including the tilted heads and raised-hand expressions.
export const FACE_ANCHORS = {
  whale: {
    idle: [228, 197, '#fee4d4', '#fde4d5'], happy: [228, 197, '#fdded0', '#fde8dd'],
    cute: [229, 197, '#fee9dd', '#fee3d5'], angry: [228, 196, '#fde1d3', '#fee3d5'],
    frustrated: [228, 199, '#fde4d5', '#fde5d7'], bell: [228, 197, '#fee1d3', '#fde7d9'],
  },
  claude: {
    idle: [259, 161, '#fde8db', '#feeadf'], happy: [257, 163, '#fde2d5', '#fee9e0'],
    cute: [259, 166, '#fee9df', '#fde8dd'], angry: [260, 166, '#fee9de', '#feefe7'],
    frustrated: [259, 165, '#fee9de', '#feede4'], bell: [259, 164, '#fee8de', '#feeae1'],
  },
  chatgpt: {
    idle: [258, 175, '#fee8e4', '#fee8e3'], happy: [259, 175, '#fee5e1', '#fdeae7'],
    cute: [260, 175, '#fde7e4', '#fde5e1'], angry: [258, 178, '#fde9e6', '#fde9e6'],
    frustrated: [259, 181, '#fde7e3', '#feebe7'], bell: [259, 177, '#fde6e2', '#fde6e3'],
  },
};

/** SVG registration scales identically to object-fit:contain on the base art. */
export function createPortrait(art, character) {
  const document = art.ownerDocument;
  const id = `portrait-${++nextId}`;
  const svg = document.createElementNS(ns, 'svg');
  svg.classList.add('portrait-features');
  svg.setAttribute('viewBox', '0 0 512 512');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('focusable', 'false');
  svg.innerHTML = `<defs>
    <linearGradient id="${id}-skin"><stop/><stop offset="1"/></linearGradient>
    <radialGradient id="${id}-edge"><stop offset="0.8" stop-color="white"/><stop offset="1" stop-color="white" stop-opacity="0"/></radialGradient>
    <mask id="${id}-mask" maskContentUnits="objectBoundingBox"><rect width="1" height="1" fill="url(#${id}-edge)"/></mask>
    <mask id="${id}-eye" maskUnits="userSpaceOnUse" x="-25" y="-22" width="50" height="44"><ellipse rx="25" ry="22" fill="url(#${id}-edge)"/></mask>
  </defs><g class="portrait-mouth" visibility="hidden">
    <ellipse rx="18" ry="15" fill="url(#${id}-skin)" mask="url(#${id}-mask)"/>
  </g>`;
  const group = svg.querySelector('.portrait-mouth');
  const skin = svg.querySelector(`#${id}-skin`).children;
  let expression = 'idle';
  let shape = 0;
  let ready = 0;
  let disposed = false;
  let blinkReady = false;
  const images = ['friendly', 'stern'].flatMap(mood => ['closed', 'small', 'open'].map((name, index) => {
    const image = document.createElementNS(ns, 'image');
    image.setAttribute('href', `${base}avatars/speech/${mood}-${name}.png`);
    const width = index === 0 ? 26 : index === 1 ? 30 : 34;
    image.setAttribute('x', String(-width / 2)); image.setAttribute('y', String(-width * .375));
    image.setAttribute('width', String(width)); image.setAttribute('height', String(width * .75));
    image.setAttribute('transform', 'rotate(-10)');
    image.setAttribute('visibility', 'hidden');
    image.addEventListener('load', () => {
      if (!disposed && ++ready === 6) group.setAttribute('visibility', 'visible');
    }, { once: true });
    group.append(image);
    return { image, mood, index };
  }));
  const blink = document.createElementNS(ns, 'g');
  blink.classList.add('portrait-blink');
  blink.setAttribute('visibility', 'hidden');
  // Reuse the painted closed eyes from each character's cute pose. Their skin,
  // lashes and hair edges blend more naturally than a flat eyelid cover.
  const cute = `${base}avatars/${character === 'whale' ? '' : `${character}/`}cute.webp`;
  blink.innerHTML = EYES[character].map(([x, y, sourceX, sourceY]) => `<g transform="translate(${x} ${y})">
    <g mask="url(#${id}-eye)"><image href="${cute}" x="${-sourceX}" y="${-sourceY}" width="512" height="512"/></g>
  </g>`).join('');
  let eyesLoaded = 0;
  blink.querySelectorAll('image').forEach(image => image.addEventListener('load', () => { blinkReady = ++eyesLoaded === 2; }, { once: true }));
  svg.append(blink);
  art.append(svg);
  function paint() {
    const [x, y, left, right] = FACE_ANCHORS[character][expression] ?? FACE_ANCHORS[character].idle;
    const mood = ['angry', 'frustrated', 'bell'].includes(expression) ? 'stern' : 'friendly';
    group.setAttribute('transform', `translate(${x} ${y})`);
    skin[0].setAttribute('stop-color', left); skin[1].setAttribute('stop-color', right);
    images.forEach(item => item.image.setAttribute('visibility', item.mood === mood && item.index === shape ? 'inherit' : 'hidden'));
    art.dataset.mouth = String(shape);
  }
  paint();
  return {
    expression(value) { expression = value; blink.setAttribute('visibility', 'hidden'); paint(); },
    mouth(value) { if (value !== shape) { shape = value; paint(); } },
    blink(value) {
      blink.setAttribute('visibility', value && blinkReady && ['idle', 'happy'].includes(expression) ? 'visible' : 'hidden');
    },
    destroy() { disposed = true; svg.remove(); },
  };
}
