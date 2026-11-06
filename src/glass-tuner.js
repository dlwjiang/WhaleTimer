export const GLASS_PARAMS = [
  { key: 'blurPx', label: '模糊 · Blur', min: 0, max: 24, step: .5, value: 1, unit: 'px', css: '--glass-blur' },
  { key: 'saturationPct', label: '饱和度 · Saturation', min: 50, max: 200, step: 5, value: 130, unit: '%', css: '--glass-saturation' },
  { key: 'tintPct', label: '磨砂浓度 · Tint', min: 0, max: 80, step: 1, value: 32, unit: '%', css: '--glass-tint' },
  { key: 'sheenPct', label: '反光 · Sheen', min: 0, max: 80, step: 1, value: 33, unit: '%', css: '--glass-sheen' },
  { key: 'edgeHighlightPct', label: '顶部高光 · Edge', min: 0, max: 100, step: 1, value: 69, unit: '%', css: '--glass-edge' },
  { key: 'refractionPx', label: '顶部折射 · Refraction', min: 0, max: 60, step: 1, value: 27, unit: 'px' },
];
// A new preset starts fresh instead of restoring drafts from before approval.
const STORAGE_KEY = 'banke-glass-draft-v1-preset-2';
export function normalizeGlass(values = {}) {
  return Object.fromEntries(GLASS_PARAMS.map(param => {
    const value = values?.[param.key];
    return [param.key, typeof value === 'number' && Number.isFinite(value)
      ? Math.max(param.min, Math.min(param.max, Math.round(value / param.step) * param.step)) : param.value];
  }));
}

export function createGlassTuner(root, { storage, onClose = () => {} } = {}) {
  let values = normalizeGlass();
  let saved;
  try { saved = JSON.parse(storage?.getItem(STORAGE_KEY)); } catch { /* Invalid drafts use defaults. */ }
  if (saved?.version === 1) values = normalizeGlass(saved);
  const document = root.ownerDocument;
  const panel = document.createElement('aside');
  panel.className = 'glass-tuner';
  panel.hidden = true;
  panel.setAttribute('aria-label', '磨砂玻璃实时调节');
  panel.innerHTML = `
    <div class="glass-tuner-heading"><strong>磨砂玻璃调节</strong><button type="button" data-close aria-label="关闭玻璃调节">×</button></div>
    <p>实时预览 · 自动保存草稿</p>
    <div class="glass-tuner-scroll">
      ${GLASS_PARAMS.map(p => `<label class="glass-tuner-param" for="glass-${p.key}"><span>${p.label}</span><output for="glass-${p.key}"></output><input id="glass-${p.key}" data-param="${p.key}" type="range" min="${p.min}" max="${p.max}" step="${p.step}"></label>`).join('')}
      <details><summary>查看 JSON</summary><textarea aria-label="玻璃效果 JSON" readonly spellcheck="false" rows="9"></textarea></details>
    </div>
    <div class="glass-tuner-actions"><button type="button" data-reset>恢复默认</button><button type="button" data-copy>复制 JSON</button></div>
    <span class="glass-tuner-status" role="status" aria-live="polite"></span>`;
  root.append(panel);
  const json = panel.querySelector('textarea');
  const status = panel.querySelector('[role=status]');
  const listeners = [];
  const on = (element, event, fn) => { element.addEventListener(event, fn); listeners.push(() => element.removeEventListener(event, fn)); };
  function render() {
    for (const p of GLASS_PARAMS) {
      panel.querySelector(`[data-param="${p.key}"]`).value = values[p.key];
      panel.querySelector(`output[for="glass-${p.key}"]`).textContent = `${values[p.key]}${p.unit}`;
    }
    json.value = JSON.stringify({ version: 1, ...values }, null, 2);
  }
  function apply() {
    root.dataset.glassTuned = 'true';
    for (const p of GLASS_PARAMS) {
      if (p.css) root.style.setProperty(p.css, p.key === 'blurPx' ? `${values[p.key]}px`
        : p.key === 'saturationPct' ? `${values[p.key]}%` : String(values[p.key] / 100));
    }
    root.querySelector('#timer-glass-lens feDisplacementMap')?.setAttribute('scale', values.refractionPx);
    render();
  }
  function save() {
    try { storage?.setItem(STORAGE_KEY, json.value); } catch { /* Live preview still works without storage. */ }
  }
  function close(restoreFocus = true) {
    panel.hidden = true;
    if (restoreFocus) onClose();
  }
  on(panel, 'input', event => {
    const key = event.target.dataset.param;
    if (!key) return;
    values = normalizeGlass({ ...values, [key]: Number(event.target.value) });
    apply(); save(); status.textContent = '';
  });
  on(panel.querySelector('[data-reset]'), 'click', () => {
    values = normalizeGlass(); apply(); save(); status.textContent = '已恢复默认参数';
  });
  on(panel.querySelector('[data-close]'), 'click', () => close());
  on(panel, 'keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); close(); }
  });
  on(panel.querySelector('[data-copy]'), 'click', async () => {
    const text = json.value;
    try {
      await document.defaultView.navigator.clipboard.writeText(text);
      status.textContent = 'JSON 已复制，可以粘贴发送';
    } catch {
      panel.querySelector('details').open = true;
      json.focus(); json.select();
      status.textContent = '请复制已选中的 JSON';
    }
  });
  apply();
  return {
    open() { panel.hidden = false; apply(); panel.querySelector('input').focus({ preventScroll: true }); },
    close,
    destroy() { listeners.forEach(fn => fn()); panel.remove(); },
  };
}
