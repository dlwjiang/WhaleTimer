/** SVG image percentages resolve against the defs viewport, not the HTML pane.
 * Size the map in CSS pixels so refraction stays registered when the dock resizes. */
export function createGlassLens(root) {
  const pane = root.querySelector('.timer-panel');
  const map = root.querySelector('#timer-glass-lens feImage');
  const view = root.ownerDocument.defaultView;
  function resize() {
    const { width, height } = pane.getBoundingClientRect();
    if (width <= 0 || height <= 0) return;
    map.setAttribute('width', width);
    map.setAttribute('height', height);
  }
  const observer = view.ResizeObserver ? new view.ResizeObserver(resize) : null;
  observer?.observe(pane);
  view.addEventListener('resize', resize);
  resize();
  return { destroy() { observer?.disconnect(); view.removeEventListener('resize', resize); } };
}
