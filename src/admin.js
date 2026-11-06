import voiceLines from '../design/voice/lines.json' with { type: 'json' };
import { VOICE_SETS } from './voices.js';
import { CHARACTERS, characterImage } from './characters.js';

const EXPRESSIONS = [
  ['idle', '安静陪伴', 'breathe'],
  ['happy', '加油鼓励', 'happy-bounce'],
  ['cute', '可爱招呼', 'sway'],
  ['angry', '生气提醒', 'stomp'],
  ['frustrated', '着急催促', 'huff'],
  ['bell', '摇铃提醒', 'ring'],
];
const IMAGES = CHARACTERS.flatMap(character => Object.keys(character.images).map(expression => ({
  id: character.id === 'whale' ? expression : `${character.id}-${expression}`,
  name: `${character.name} · ${EXPRESSIONS.find(([name]) => name === expression)[1]}`,
  label: EXPRESSIONS.find(([name]) => name === expression)[1],
  motion: EXPRESSIONS.find(([name]) => name === expression)[2],
  url: characterImage(character, expression),
  alt: `${character.description}，${EXPRESSIONS.find(([name]) => name === expression)[1]}`,
})));
const escape = value => String(value).replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
let nextPanelId = 0;

/** Local asset browser; the timer owner controls pause/resume through callbacks. */
export function createAssetPanel(root, { onOpen, onClose } = {}) {
  const document = root.ownerDocument;
  const id = `asset-studio-${++nextPanelId}`;
  const base = import.meta.env?.BASE_URL ?? '/';
  const dialog = document.createElement('dialog');
  dialog.className = 'asset-studio';
  dialog.setAttribute('aria-labelledby', `${id}-title`);
  dialog.setAttribute('aria-describedby', `${id}-note`);
  dialog.innerHTML = `
    <div class="asset-studio-heading">
      <div><span class="asset-studio-eyebrow">伙伴素材</span><h2 id="${id}-title">素材面板</h2></div>
      <button type="button" class="asset-studio-close" aria-label="关闭素材面板" autofocus>×</button>
    </div>
    <p class="asset-studio-intro" id="${id}-note">在这里查看伙伴的造型、试听每位伙伴的独立声线。计时已暂停，关闭后请手动继续。</p>
    <div class="asset-studio-tabs" aria-label="素材分类">
      <button type="button" data-asset-tab="voices" aria-pressed="true" aria-controls="${id}-voices">语音 <span>${voiceLines.clips.length}</span></button>
      <button type="button" data-asset-tab="images" aria-pressed="false" aria-controls="${id}-images">图片 <span>${IMAGES.length}</span></button>
    </div>
    <section id="${id}-voices" class="asset-studio-section" data-asset-section="voices" aria-label="语音片段">
      <label class="asset-voice-selector">伙伴声线<select aria-label="选择试听声线">${VOICE_SETS.map(voice => `<option value="${voice.id}">${voice.name} · ${voice.description}</option>`).join('')}</select></label>
      <div class="asset-voice-toolbar">
        <label class="asset-search">查找语音<input type="search" placeholder="搜索语音内容或编号……" autocomplete="off"></label>
        <button type="button" class="asset-stop-all">停止播放</button>
      </div>
      <div class="asset-voice-summary"><span class="asset-voice-count">共 ${voiceLines.clips.length} 段语音</span><span class="asset-playback-status" role="status" aria-live="polite">暂无播放</span></div>
      <div class="asset-voice-list">${voiceLines.clips.map((clip, index) => `
        <article class="asset-voice-row" data-voice-id="${escape(clip.id)}">
          <div class="asset-voice-copy"><strong>语音 ${index + 1}</strong><p lang="zh-CN">${escape(clip.text)}</p></div>
          <audio controls preload="none" aria-label="播放：${escape(clip.text)}" src="${escape(`${base}voice/${clip.file}`)}"></audio>
          <p class="asset-load-error" hidden>这段语音加载失败。 <a href="${escape(`${base}voice/${clip.file}`)}" target="_blank" rel="noopener">打开音频文件</a></p>
        </article>`).join('')}</div>
      <p class="asset-no-results" hidden>未找到匹配的语音，请尝试其他关键词或清空搜索。</p>
    </section>
    <section id="${id}-images" class="asset-studio-section" data-asset-section="images" aria-label="角色图片" hidden>
      <div class="asset-image-toolbar">
        <div class="asset-background-options" aria-label="预览背景"><button type="button" data-background="checker" aria-pressed="true">棋盘格</button><button type="button" data-background="light" aria-pressed="false">浅色</button><button type="button" data-background="dark" aria-pressed="false">深色</button></div>
        <label class="asset-motion-toggle"><input type="checkbox">预览动作</label>
      </div>
      <figure class="asset-image-preview" data-background="checker" data-animate="false" data-motion="breathe"><img src="${base}avatars/idle.webp" alt="鲸鱼女仆安静陪伴的表情"><figcaption><strong>鲸鱼女仆</strong><span>安静陪伴</span></figcaption></figure>
      <p class="asset-image-error asset-load-error" hidden>图片加载失败。 <a href="${base}avatars/idle.webp" target="_blank" rel="noopener">打开图片文件</a></p>
      <div class="asset-image-grid" aria-label="选择角色图片">${IMAGES.map((item, index) => `<button type="button" data-expression="${item.id}" aria-pressed="${index === 0}" aria-label="预览：${item.name}"><img src="${item.url}" alt="" loading="lazy"><span>${item.name}</span></button>`).join('')}</div>
      <p class="asset-image-note">每位伙伴都有六种表情：安静、开心、可爱、生气、着急和摇铃。动作预览会遵循设备的减少动态效果设置。</p>
    </section>`;
  root.append(dialog);
  const $ = selector => dialog.querySelector(selector);
  const all = selector => [...dialog.querySelectorAll(selector)];
  const cleanups = [];
  const on = (element, event, handler) => {
    element.addEventListener(event, handler);
    cleanups.push(() => element.removeEventListener(event, handler));
  };
  const rows = all('.asset-voice-row');
  const players = all('audio');
  const status = $('.asset-playback-status');
  let activePlayer = null;
  let opened = false;
  let destroyed = false;
  let returnFocus = null;

  function stopAll() {
    activePlayer = null;
    players.forEach(player => {
      if (!player.paused) player.pause();
      try { player.currentTime = 0; } catch { /* An unloaded clip may not be seekable. */ }
    });
    rows.forEach(row => row.classList.remove('is-playing'));
    status.textContent = '暂无播放';
  }

  players.forEach(player => {
    const row = player.closest('.asset-voice-row');
    on(player, 'play', () => {
      if (!opened) { player.pause(); return; }
      activePlayer = player;
      players.forEach(other => {
        if (other !== player) {
          if (!other.paused) other.pause();
          try { other.currentTime = 0; } catch { /* Not loaded yet. */ }
        }
      });
      rows.forEach(other => other.classList.toggle('is-playing', other === row));
      status.textContent = `正在播放：${row.querySelector('p').textContent}`;
    });
    const markStopped = () => {
      row.classList.remove('is-playing');
      if (activePlayer === player) {
        activePlayer = null;
        status.textContent = '暂无播放';
      }
    };
    on(player, 'pause', markStopped);
    on(player, 'ended', markStopped);
    on(player, 'error', () => {
      markStopped();
      row.querySelector('.asset-load-error').hidden = false;
    });
  });
  on($('.asset-stop-all'), 'click', stopAll);
  on($('.asset-voice-selector select'), 'change', event => {
    stopAll();
    const voice = VOICE_SETS.find(item => item.id === event.target.value) ?? VOICE_SETS[0];
    rows.forEach((row, index) => {
      const clip = voice.clips[index];
      const url = `${base}voice/${clip.file}`;
      const player = row.querySelector('audio');
      player.src = url;
      player.setAttribute('aria-label', `${voice.name}：${clip.text}`);
      row.querySelector('.asset-load-error').hidden = true;
      row.querySelector('.asset-load-error a').href = url;
    });
  });
  on($('.asset-search input'), 'input', event => {
    const query = event.target.value.trim().toLocaleLowerCase();
    let count = 0;
    rows.forEach((row, index) => {
      const clip = voiceLines.clips[index];
      row.hidden = !`${index + 1} ${clip.id} ${clip.label || ''} ${clip.id.replaceAll('-', ' ')} ${clip.text}`.toLocaleLowerCase().includes(query);
      if (!row.hidden) count += 1;
      else if (row.querySelector('audio') === activePlayer) stopAll();
    });
    $('.asset-voice-count').textContent = `显示 ${count} 段，共 ${rows.length} 段语音`;
    $('.asset-no-results').hidden = count !== 0;
  });

  all('[data-asset-tab]').forEach(button => on(button, 'click', () => {
    const tab = button.dataset.assetTab;
    stopAll();
    all('[data-asset-tab]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    all('[data-asset-section]').forEach(section => { section.hidden = section.dataset.assetSection !== tab; });
  }));

  const preview = $('.asset-image-preview');
  const previewImage = preview.querySelector('img');
  const imageError = $('.asset-image-error');
  all('[data-expression]').forEach(button => on(button, 'click', () => {
    const name = button.dataset.expression;
    const item = IMAGES.find(image => image.id === name);
    const { label, motion, url } = item;
    all('[data-expression]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    previewImage.src = url;
    previewImage.alt = item.alt;
    preview.querySelector('strong').textContent = item.name;
    preview.querySelector('figcaption span').textContent = label;
    preview.dataset.motion = motion;
    imageError.hidden = true;
    imageError.querySelector('a').href = url;
  }));
  on(previewImage, 'error', () => { imageError.hidden = false; });
  on(previewImage, 'load', () => { imageError.hidden = true; });
  all('.asset-background-options button').forEach(button => on(button, 'click', () => {
    preview.dataset.background = button.dataset.background;
    all('.asset-background-options button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  }));
  on($('.asset-motion-toggle input'), 'change', event => { preview.dataset.animate = String(event.target.checked); });

  function finishClose() {
    stopAll();
    if (!opened) return;
    opened = false;
    preview.dataset.animate = 'false';
    $('.asset-motion-toggle input').checked = false;
    if (returnFocus?.isConnected && !returnFocus.closest('dialog:not([open]), [hidden]')) returnFocus.focus();
    onClose?.();
  }

  function close() {
    if (destroyed) return;
    if (dialog.open) dialog.close();
    finishClose();
  }

  on($('.asset-studio-close'), 'click', close);
  on(dialog, 'cancel', event => { event.preventDefault(); close(); });
  on(dialog, 'close', finishClose);

  return {
    open() {
      if (destroyed || opened) return;
      returnFocus = document.activeElement;
      onOpen?.();
      opened = true;
      dialog.showModal();
      $('.asset-studio-close').focus();
    },
    close,
    destroy() {
      if (destroyed) return;
      close();
      destroyed = true;
      cleanups.forEach(cleanup => cleanup());
      dialog.remove();
    },
  };
}
