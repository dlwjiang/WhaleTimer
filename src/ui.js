import { createSpeechCaption } from './speech.js';
import { createAngerEmojis } from './anger.js';
import { createCharacterSwipe } from './character-swipe.js';
import { createGlassTuner } from './glass-tuner.js';
import { createGlassLens } from './glass-lens.js';
import { GLASS_DISPLACEMENT_MAP } from './glass-map.js';
import { createCharacterCarousel } from './character-carousel.js';
import { createSpeaking } from './speaking.js';
import { createFlipClock } from './flip-clock.js';
import { TimerEngine, SECONDARY_COUNTDOWN_SECONDS } from './timer.js';
import { createAudio } from './audio.js';
import { createAssetPanel } from './admin.js';
import { warningText } from './warnings.js';
import { CHARACTERS, getCharacter, characterImage } from './characters.js';

const STORAGE_KEY = 'tide-timer-v1';
const START_CUE = '三、二、一，开始！';
const ICONS = {
  settings: '<path d="m9 3 1-2h4l1 2 2 1 2-.2 2 3-1.2 2v3l1.2 2-2 3-2-.2-2 1-1 2h-4l-1-2-2-1-2 .2-2-3L4.2 12V9L3 7l2-3 2 .2Z"/><circle cx="12" cy="10.5" r="3"/>',
  sound: '<path d="M4 9h4l5-4v14l-5-4H4Z"/><path d="M17 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14"/>',
  mute: '<path d="M4 9h4l5-4v14l-5-4H4Z"/><path d="m17 9 5 6m0-6-5 6"/>',
  play: '<path d="m9 5 10 7-10 7Z"/>',
  pause: '<path d="M8 5v14M16 5v14"/>',
  arrow: '<path d="M5 12h14m-5-5 5 5-5 5"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
};
const icon = name => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;
export function formatTime(ms) {
  const seconds = Math.max(0, Math.ceil(ms / 1000));
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}

export function mountApp(root, { now = Date.now, storage, audio = createAudio(), autoTick = true } = {}) {
  if (storage === undefined) {
    try { storage = globalThis.localStorage; } catch { storage = null; }
  }
  let saved;
  try { saved = JSON.parse(storage?.getItem(STORAGE_KEY)); } catch { /* Storage can be unavailable. */ }
  let engine;
  try {
    // Migrate preferences from older saves, without restoring an active session.
    const { mainSeconds, secondarySeconds, overtimeSeconds, overtimeAlerts } = saved?.timer ?? {};
    engine = new TimerEngine({ mainSeconds, secondarySeconds, overtimeSeconds, overtimeAlerts, now });
  } catch { engine = new TimerEngine({ now }); }
  let character = getCharacter(saved?.character);
  let sound = saved?.sound !== false;
  audio.setEnabled(sound);
  let expression = 'idle';
  let expressionUntil = 0;
  let ambientAt = now() + 12000;
  let lastAnnouncement = '';
  let renderedSound;
  let destroyed = false;
  let preparation = null;

  root.innerHTML = `
    <svg class="glass-filter-defs" aria-hidden="true" focusable="false" width="0" height="0">
      <defs>
        <filter id="timer-glass-lens" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB">
          <feImage href="${GLASS_DISPLACEMENT_MAP}" x="0" y="0" width="440" height="224" preserveAspectRatio="none" result="lens"/>
          <feDisplacementMap in="SourceGraphic" in2="lens" scale="27" xChannelSelector="R" yChannelSelector="G"/>
        </filter>
        <filter id="glass-refraction" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">
          <feTurbulence type="fractalNoise" baseFrequency="0.012 0.018" numOctaves="1" seed="8" result="ripples"/>
          <feDisplacementMap in="SourceGraphic" in2="ripples" scale="14" xChannelSelector="R" yChannelSelector="G"/>
        </filter>
      </defs>
    </svg>
    <div class="app-shell">
      <header class="topbar glass-panel">
        <a class="brand" href="./" aria-label="伴刻首页"><img class="brand-logo" src="${import.meta.env?.BASE_URL ?? '/'}brand/companion-hourglass-128.png" alt="" width="40" height="40"><span class="brand-copy"><span class="brand-title">伴刻</span><span class="brand-caption">你的专注伙伴</span></span></a>
        <div class="header-actions"><button id="sound-toggle" class="icon-button" aria-label="关闭声音" title="关闭声音"></button><button id="settings-open" class="icon-button" aria-label="计时设置" title="计时设置">${icon('settings')}</button></div>
      </header>
      <main class="main-layout">
        <section class="companion" aria-label="你的专注伙伴">
          <div id="speech" class="sr-only" role="status" aria-live="polite" aria-atomic="true"><p id="speech-cn" lang="zh-CN">准备好了吗？我会陪着你哦。</p></div>
          <span id="character-swipe-help" class="sr-only">左右拖动切换伙伴；也可使用两侧按钮，或聚焦角色后按左右方向键。点击角色打招呼。</span>
          <button id="character-previous" class="character-step character-previous" aria-label="上一位伙伴" title="上一位伙伴">${icon('arrow')}</button>
          <button id="character-next" class="character-step character-next" aria-label="下一位伙伴" title="下一位伙伴">${icon('arrow')}</button>
          <button id="avatar" class="avatar-wrap" title="点击打招呼，左右拖动切换伙伴" aria-describedby="character-swipe-help" aria-keyshortcuts="ArrowLeft ArrowRight"><span class="avatar-shadow" aria-hidden="true"></span></button>
          <div id="speech-visual" class="speech-caption" lang="zh-CN" aria-hidden="true"></div>
          <div id="anger-emojis" class="anger-emojis" role="img" hidden></div>
        </section>
        <section class="timer-panel glass-panel" aria-label="双阶段计时器">
          <div class="clock-block"><div id="timer-display" class="timer-display" role="timer" aria-label="专注计时">03:00</div></div>
          <div class="progress-sections">
            <div id="extra-progress" class="progress-track" role="progressbar" aria-label="加时剩余时间" aria-valuemin="0" aria-valuemax="100" aria-valuenow="100"><div></div></div>
            <div id="focus-progress" class="progress-track" role="progressbar" aria-label="专注剩余时间" aria-valuemin="0" aria-valuemax="100" aria-valuenow="100"><div></div></div>
          </div>
          <button id="primary-action" class="primary-button"><span class="timer-action-icon" aria-hidden="true">${icon('play')}</span><span class="timer-action-label">开始专注</span></button>
          <div id="reset-track" class="reset-track"><span class="reset-label">右滑重新开始</span><button id="reset-handle" class="reset-handle" aria-label="重置计时器。向右拖动，或按回车键或空格键。" title="右滑或按回车键重置">${icon('arrow')}</button></div>
          <p id="audio-note" class="audio-note" hidden>此浏览器无法播放中文语音，计时和角色状态仍会正常更新。</p>
        </section>
      </main>
      <footer class="footer"><a class="about-link" href="#about-timer">关于伴刻 · Timer guide</a><a class="about-link" href="https://dj.theory-a.com" target="_blank" rel="noopener noreferrer" aria-label="关于作者：打开个人作品集（新标签页）">关于作者 · About <span aria-hidden="true">↗</span></a><span>按自己的节奏来 <span aria-hidden="true">✧</span></span></footer>
    </div>
    <dialog id="settings-dialog" aria-labelledby="settings-title"><form id="settings-form">
      <div class="dialog-heading"><h2 id="settings-title">计时设置</h2><button type="button" id="settings-close" class="icon-button" aria-label="关闭设置">${icon('close')}</button></div>
      <fieldset class="character-picker" aria-describedby="character-note">
        <legend>选择伙伴</legend>
        <div class="character-options">${CHARACTERS.map(item => `<button type="button" class="character-option" data-character="${item.id}" aria-pressed="${item.id === character.id}" aria-label="选择${item.name}"><img src="${characterImage(item)}" alt="" draggable="false"><span>${item.name}</span></button>`).join('')}</div>
        <p id="character-note" class="sr-only">随时切换，自动保存，不影响当前计时。</p>
        <p id="character-status" class="character-status sr-only" role="status" aria-live="polite"></p>
      </fieldset>
      <div class="settings-durations">
      <label class="duration-field" for="main-duration"><span><strong>专注时长</strong><small>第一阶段的倒计时</small></span><span class="number-input"><input id="main-duration" name="main" type="text" required inputmode="decimal" autocomplete="off" spellcheck="false"><span>分钟</span></span></label>
      <label class="duration-field" for="secondary-duration"><span><strong>加时时长</strong><small>设为 0 可关闭加时</small></span><span class="number-input"><input id="secondary-duration" name="secondary" type="text" required inputmode="decimal" autocomplete="off" spellcheck="false"><span>分钟</span></span></label>
      </div>
      <div class="settings-overtime">
      <label class="duration-field overtime-toggle" for="overtime-alerts"><span><strong>重复超时提醒</strong><small>关闭后仅在计时结束时提醒一次</small></span><input id="overtime-alerts" name="overtime-alerts" type="checkbox" role="switch" checked></label>
      <label class="duration-field" for="overtime-interval"><span><strong>超时提醒间隔</strong><small>计时结束后的提醒频率</small></span><span class="number-input"><input id="overtime-interval" name="overtime" type="text" required inputmode="numeric" autocomplete="off" spellcheck="false"><span>秒</span></span></label>
      </div>
      <div class="preset-row" aria-label="计时预设"><button type="button" data-preset="3,2">短暂专注 <b>3 + 2</b></button><button type="button" data-preset="25,5">深度专注 <b>25 + 5</b></button><button type="button" data-preset="0.1,0.2">快速体验 <b>6 秒 + 12 秒</b></button></div>
      <p id="settings-error" class="form-error" role="alert"></p>
      <button class="primary-button" type="submit">${icon('check')}<span>保存并重置计时</span></button>
      <div class="settings-links">
      <button type="button" id="assets-open" class="asset-panel-link">语音与图片 <span aria-hidden="true">↗</span></button>
      <a class="about-link" href="https://dj.theory-a.com" target="_blank" rel="noopener noreferrer" aria-label="关于作者：打开个人作品集（新标签页）">关于作者 · About <span aria-hidden="true">↗</span></a>
      </div>
    </form></dialog>
    <div id="announcer" class="sr-only" role="status" aria-live="polite"></div>`;

  const $ = selector => root.querySelector(selector);
  const attribute = (element, name, value) => {
    if (element.getAttribute(name) !== String(value)) element.setAttribute(name, value);
  };
  const flipClock = createFlipClock($('#timer-display'));
  const dialog = $('#settings-dialog');
  const glassLens = createGlassLens(root);
  const glassTuner = createGlassTuner(root, { storage, onClose: () => $('#settings-open').focus() });
  const avatar = $('#avatar');
  const characterCarousel = createCharacterCarousel(avatar, { index: CHARACTERS.indexOf(character) });
  const speaking = createSpeaking({ avatar, audio, carousel: characterCarousel });
  const speechCaption = createSpeechCaption({ element: $('#speech-visual'), avatar, container: $('.companion'), now, character: () => character.id });
  const angerEmojis = createAngerEmojis({ element: $('#anger-emojis'), avatar, container: $('.companion'), character: () => character.id });
  const cleanups = [];
  const on = (target, type, fn, options) => { target.addEventListener(type, fn, options); cleanups.push(() => target.removeEventListener(type, fn, options)); };
  function persist() {
    const { mainSeconds, secondarySeconds, overtimeSeconds, overtimeAlerts } = engine;
    const timer = { mainSeconds, secondarySeconds, overtimeSeconds, overtimeAlerts };
    try { storage?.setItem(STORAGE_KEY, JSON.stringify({ timer, sound, character: character.id })); } catch { /* Private browsing and full storage don't stop the timer. */ }
  }
  function announce(text) {
    if (text !== lastAnnouncement) { $('#announcer').textContent = text; lastAnnouncement = text; }
  }
  function updateExpression() {
    const visibleExpression = character.images[expression] ? expression : 'idle';
    characterCarousel.updateExpression(visibleExpression);
  }
  function renderCharacter() {
    characterCarousel.select(CHARACTERS.indexOf(character));
    root.dataset.character = character.id;
    audio.setCharacter?.(character.id);
    avatar.setAttribute('aria-label', `和${character.name}打个招呼`);
    $('.companion').setAttribute('aria-label', `你的伙伴：${character.name}`);
    root.querySelectorAll('.character-option').forEach(button => {
      button.setAttribute('aria-pressed', String(button.dataset.character === character.id));
    });
    $('#character-status').textContent = `已选择${character.name}。 六种表情造型，搭配动态反应。`;
    updateExpression();
    angerEmojis.position();
  }
  function selectCharacter(id) {
    const selected = getCharacter(id);
    if (selected.id === character.id) return;
    character = selected;
    renderCharacter();
    persist();
    announce(`已切换为${character.name}。`);
  }
  function cycleCharacter(direction) {
    const index = CHARACTERS.findIndex(item => item.id === character.id);
    selectCharacter(CHARACTERS[(index + direction + CHARACTERS.length) % CHARACTERS.length].id);
  }
  function setExpression(name, animation = 'breathe', duration = 0) {
    expression = name;
    expressionUntil = duration ? now() + duration : 0;
    avatar.dataset.motion = animation;
    avatar.dataset.expression = name;
    updateExpression();
  }
  function say(cn, name, animation, speak = true) {
    $('#speech').classList.remove('is-countdown');
    $('#speech-cn').textContent = cn;
    speechCaption.show(cn);
    setExpression(name, animation, 5200);
    if (speak && sound) audio.speak(cn);
  }
  function handleEvents(events, audible = true) {
    if (!events.length) return;
    if (audible && sound && events.some(event => event.type === 'main-complete')) audio.bell();
    const latest = events.at(-1);
    if (latest.type === 'main-complete') {
      say('时间到了，我们快一点吧！', 'bell', 'ring', false);
    } else if (latest.type === 'secondary-complete') {
      say('时间真的到了！我要生气啦！', 'angry', 'stomp', audible);
    } else if (latest.type === 'overdue-reminder') {
      const number = latest.reminderIndex;
      say(warningText(number), number % 2 ? 'angry' : 'frustrated', number % 2 ? 'stomp' : 'huff', audible);
    } else if (latest.type === 'secondary-countdown') {
      const digit = ['', '一', '二', '三', '四', '五'][latest.number];
      say(digit, 'frustrated', 'huff', audible);
      $('#speech').classList.add('is-countdown');
    }
    persist();
  }
  function render(snapshot = engine.snapshot()) {
    speechCaption.update();
    const { status, phase, remainingMs, overdueMs } = snapshot;
    const overdue = phase === 'overdue';
    angerEmojis.update(overdue && snapshot.overtimeAlerts ? engine.lastReminderIndex : 0, status === 'paused');
    const grace = phase === 'grace';
    const preparing = status === 'preparing';
    const active = status === 'running' || preparing;
    attribute(root, 'data-phase', phase);
    attribute(root, 'data-status', status);
    attribute(root, 'data-countdown', grace && status === 'running' && remainingMs <= SECONDARY_COUNTDOWN_SECONDS * 1000 ? String(Math.ceil(remainingMs / 1000)) : '');
    const time = overdue ? `+${formatTime(overdueMs)}` : formatTime(remainingMs);
    flipClock.update(time, { animate: status === 'running' && !document.hidden });
    attribute($('#timer-display'), 'aria-label', `${overdue ? '已超时' : grace ? '加时剩余' : '专注剩余'} ${time}`);
    const action = active ? 'pause' : 'play';
    const actionButton = $('#primary-action');
    if (actionButton.dataset.action !== action) {
      actionButton.dataset.action = action;
      actionButton.querySelector('.timer-action-icon').innerHTML = icon(action);
    }
    const label = actionButton.querySelector('.timer-action-label');
    const actionText = active ? '暂停' : status === 'paused' ? '继续' : '开始专注';
    if (label.textContent !== actionText) label.textContent = actionText;
    // Focus drains first from the far right, followed by extra time on the left.
    const progressStyle = $('.progress-sections').style;
    const columns = snapshot.secondarySeconds === 0 ? '1fr'
      : `minmax(0, ${snapshot.secondarySeconds}fr) minmax(0, ${snapshot.mainSeconds}fr)`;
    if (progressStyle.gridTemplateColumns !== columns) progressStyle.gridTemplateColumns = columns;
    $('#extra-progress').hidden = snapshot.secondarySeconds === 0;
    for (const [id, remaining, seconds] of [
      ['focus-progress', snapshot.mainRemainingMs, snapshot.mainSeconds],
      ['extra-progress', snapshot.secondaryRemainingMs, snapshot.secondarySeconds],
    ]) {
      const percentage = seconds ? Math.min(100, Math.max(0, remaining / (seconds * 1000) * 100)) : 0;
      const track = $(`#${id}`);
      const width = `${percentage}%`;
      if (track.firstElementChild.style.width !== width) track.firstElementChild.style.width = width;
      attribute(track, 'aria-valuenow', Math.round(percentage));
    }
    if (renderedSound !== sound) {
      renderedSound = sound;
      $('#sound-toggle').innerHTML = icon(sound ? 'sound' : 'mute');
      $('#sound-toggle').setAttribute('aria-label', sound ? '关闭声音' : '开启声音');
      $('#sound-toggle').title = sound ? '关闭声音' : '开启声音';
      $('#sound-toggle').setAttribute('aria-pressed', String(sound));
    }
    const hideAudioNote = audio.supported || !sound;
    if ($('#audio-note').hidden !== hideAudioNote) $('#audio-note').hidden = hideAudioNote;
    if (expressionUntil && now() >= expressionUntil) {
      setExpression(overdue ? 'angry' : grace ? 'frustrated' : 'idle');
      ambientAt = now() + 12000;
    }
    if (!expressionUntil && now() >= ambientAt && status !== 'paused') {
      setExpression(overdue ? 'frustrated' : grace ? 'cute' : Math.random() > 0.5 ? 'cute' : 'happy', overdue ? 'huff' : 'sway', 3200);
      ambientAt = now() + 15000;
    }
  }
  function cancelPreparation() {
    preparation = null;
    audio.silence();
  }
  function finishPreparation(run) {
    if (destroyed || preparation !== run || engine.snapshot().status !== 'preparing') return;
    preparation = null;
    const result = engine.completePreparation();
    handleEvents(result.events);
    announce('计时已开始。');
    persist(); render();
  }
  function beginPreparation(withReminder = false) {
    if (preparation || engine.snapshot().status !== 'preparing') return;
    const run = {};
    preparation = run;
    const current = () => !destroyed && preparation === run && engine.snapshot().status === 'preparing';
    const speakToEnd = async (text, onStart) => {
      try { return await audio.speak(text, { waitUntilEnd: true, onStart }); } catch { return false; }
    };
    void (async () => {
      if (withReminder && sound) await speakToEnd('时间到了，我们快一点吧！');
      if (!current()) return;
      if (engine.snapshot().preparationPhase === 'grace') {
        finishPreparation(run);
        return;
      }
      say(START_CUE, 'happy', 'bounce', false);
      speechCaption.clear();
      announce('准备好，三、二、一。');
      if (sound && await speakToEnd(START_CUE, timing => {
        if (current()) speechCaption.startIntro(timing?.elapsedMs);
      })) {
        finishPreparation(run);
      } else if (current()) {
        // Muted or unavailable audio still gets a visible three-second lead-in.
        speechCaption.startIntro();
        run.silentUntil = now() + 3000;
      }
    })();
  }
  function tick() {
    if (destroyed) return;
    if (preparation?.silentUntil <= now()) finishPreparation(preparation);
    const result = engine.tick();
    handleEvents(result.events);
    beginPreparation(result.events.some(event => event.type === 'main-complete'));
    render();
  }
  function reset() {
    cancelPreparation();
    engine.reset();
    say('重新开始吧', 'happy', 'bounce');
    announce('计时已重置，准备重新开始。');
    persist(); render();
    void audio.click?.('pause');
  }
  on($('#primary-action'), 'click', () => {
    audio.unlock();
    const status = engine.snapshot().status;
    const actionButton = $('#primary-action');
    delete actionButton.dataset.feedback;
    // Restart even after a reset or a rapid second click; never delay the timer.
    void actionButton.offsetWidth;
    actionButton.dataset.feedback = status === 'running' || status === 'preparing' ? 'pause' : 'play';
    let result;
    if (status === 'running' || status === 'preparing') {
      result = engine.pause();
      handleEvents(result.events, false);
      result.events = [];
      cancelPreparation();
      say('休息一下，我等你。', 'cute', 'breathe');
      announce('计时已暂停。');
    } else if (status === 'paused') {
      result = engine.resume(); announce('计时已继续。');
      say('好，继续加油！', 'happy', 'bounce', false);
    } else {
      result = engine.start();
      announce('准备开始专注计时。');
    }
    handleEvents(result.events); beginPreparation(); persist(); render();
    void audio.click?.(actionButton.dataset.feedback);
  });
  on($('#sound-toggle'), 'click', () => {
    sound = !sound; audio.setEnabled(sound);
    if (sound && engine.snapshot().status !== 'preparing') audio.speak('我会提醒你的哦。');
    persist(); render();
  });
  on(avatar, 'click', () => {
    if (engine.snapshot().status === 'preparing') return;
    const phase = engine.snapshot().phase;
    if (phase === 'overdue') say('别戳我啦，快去收尾！', 'angry', 'stomp');
    else say('嘿嘿，我在呢。一起加油吧！', 'cute', 'bounce');
  });
  root.querySelectorAll('.character-option').forEach(button => on(button, 'click', () => {
    selectCharacter(button.dataset.character);
  }));
  const characterSwipe = createCharacterSwipe($('.main-layout'), {
    onSwipe: cycleCharacter,
    onStart: () => characterCarousel.begin(),
    onDrag: offset => characterCarousel.drag(offset),
    onRelease: direction => { if (!direction) characterCarousel.snap(); },
    canStart: target => !target.closest('.timer-panel, a, input, select, textarea, button:not(#avatar)'),
  });
  on($('#character-previous'), 'click', () => cycleCharacter(-1));
  on($('#character-next'), 'click', () => cycleCharacter(1));
  on(avatar, 'keydown', event => {
    if (!['ArrowLeft', 'ArrowRight'].includes(event.key) || event.altKey || event.ctrlKey || event.metaKey) return;
    event.preventDefault();
    cycleCharacter(event.key === 'ArrowLeft' ? -1 : 1);
  });
  on($('#settings-open'), 'click', () => {
    glassTuner.close(false);
    const snapshot = engine.snapshot();
    $('#main-duration').value = snapshot.mainSeconds / 60;
    $('#secondary-duration').value = snapshot.secondarySeconds / 60;
    $('#overtime-interval').value = snapshot.overtimeSeconds;
    $('#overtime-alerts').checked = snapshot.overtimeAlerts;
    syncOvertimeSetting();
    $('#settings-error').textContent = '';
    durationInputs.forEach(input => input.setCustomValidity(''));
    dialog.showModal();
  });
  on($('#settings-close'), 'click', () => dialog.close());
  const assetPanel = createAssetPanel(root, {
    onOpen() {
      if (['running', 'preparing'].includes(engine.snapshot().status)) {
        engine.pause();
        say('休息一下，我等你。', 'cute', 'breathe', false);
        announce('浏览语音与图片期间，计时已暂停。');
      }
      cancelPreparation();
      persist();
      render();
    },
    onClose() { $('#settings-open').focus(); },
  });
  on($('#assets-open'), 'click', () => { dialog.close(); assetPanel.open(); });
  on(dialog, 'click', event => { if (event.target === dialog) { const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close(); } });
  root.querySelectorAll('[data-preset]').forEach(button => on(button, 'click', () => {
    const [main, extra] = button.dataset.preset.split(',');
    $('#main-duration').value = main; $('#secondary-duration').value = extra;
    durationInputs.slice(0, 2).forEach(input => input.setCustomValidity(''));
  }));
  const durationInputs = ['#main-duration', '#secondary-duration', '#overtime-interval'].map($);
  function syncOvertimeSetting() {
    const input = $('#overtime-interval');
    input.disabled = !$('#overtime-alerts').checked;
    input.setCustomValidity('');
    input.closest('.duration-field').classList.toggle('is-disabled', input.disabled);
  }
  on($('#overtime-alerts'), 'change', syncOvertimeSetting);
  const durationError = input => input.id === 'overtime-interval'
    ? '请输入 1 至 86400 之间的整数秒数。'
    : `请输入 ${input.id === 'secondary-duration' ? '0' : '0.1'} 至 180 之间的分钟数，最多保留一位小数。`;
  durationInputs.forEach(input => {
    // Select after pointer placement as well as keyboard focus, including repeat taps.
    on(input, 'focus', () => input.select());
    on(input, 'click', () => input.select());
    on(input, 'input', () => input.setCustomValidity(''));
    on(input, 'invalid', () => input.setCustomValidity(durationError(input)));
  });
  on($('#settings-form'), 'submit', event => {
    event.preventDefault();
    durationInputs.forEach(input => {
      if (input.disabled) { input.setCustomValidity(''); return; }
      const value = input.value.trim();
      const overtime = input.id === 'overtime-interval';
      const minimum = input.id === 'secondary-duration' ? 0 : 0.1;
      const valid = overtime
        ? /^[0-9]+$/.test(value) && Number(value) >= 1 && Number(value) <= 86400
        : /^(?:[0-9]+(?:\.[0-9])?|\.[0-9])$/.test(value) && Number(value) >= minimum && Number(value) <= 180;
      input.setCustomValidity(valid ? '' : durationError(input));
    });
    if (!$('#settings-form').reportValidity()) return;
    try {
      engine.configure({
        mainSeconds: Math.round(Number($('#main-duration').value) * 60),
        secondarySeconds: Math.round(Number($('#secondary-duration').value) * 60),
        overtimeAlerts: $('#overtime-alerts').checked,
        overtimeSeconds: $('#overtime-alerts').checked ? Number($('#overtime-interval').value) : engine.snapshot().overtimeSeconds,
      });
      reset(); dialog.close(); announce('设置已保存，计时已重置。');
    } catch (error) { $('#settings-error').textContent = error.message; }
  });

  let drag = null;
  const handle = $('#reset-handle');
  const track = $('#reset-track');
  const moveDrag = event => {
    if (!drag || drag.id !== event.pointerId) return;
    const dx = Math.max(0, Math.min(drag.distance, event.clientX - drag.start));
    drag.fraction = drag.distance > 0 ? dx / drag.distance : 0;
    track.style.setProperty('--drag-x', `${dx}px`);
  };
  const finishDrag = (event, cancelled = false) => {
    if (!drag || event.pointerId !== drag.id) return;
    if (!cancelled) moveDrag(event);
    const complete = !cancelled && drag.fraction >= 0.88;
    const pointerId = drag.id;
    drag = null;
    try { handle.releasePointerCapture(pointerId); } catch { /* Pointer may have been released by the browser. */ }
    track.classList.remove('dragging'); track.style.setProperty('--drag-x', '0px');
    if (complete) reset();
  };
  on(handle, 'pointerdown', event => {
    if (event.button !== 0 || event.isPrimary === false || drag) return;
    drag = { id: event.pointerId, start: event.clientX, fraction: 0, distance: Math.max(0, track.clientWidth - handle.offsetWidth - 2 * (handle.offsetLeft || 6)) };
    try { handle.setPointerCapture(event.pointerId); } catch { /* Capture can be unavailable after interruption. */ }
    track.classList.add('dragging');
  });
  on(handle, 'pointermove', moveDrag);
  on(handle, 'pointerup', event => finishDrag(event));
  on(handle, 'pointercancel', event => finishDrag(event, true));
  on(handle, 'lostpointercapture', event => finishDrag(event, true));
  on(handle, 'click', event => { if (event.detail === 0) reset(); });
  on(handle, 'keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); if (!event.repeat) reset(); } });
  const cancelDrag = () => { if (drag) finishDrag({ pointerId: drag.id }, true); };
  on(globalThis.window, 'blur', cancelDrag);
  on(document, 'visibilitychange', () => { if (!document.hidden) tick(); else cancelDrag(); });
  on(globalThis.window, 'pagehide', persist);
  const interval = autoTick ? setInterval(tick, 100) : null;
  renderCharacter();
  setExpression('idle');
  tick();
  persist();
  return { tick, reset, engine, destroy() { destroyed = true; cancelPreparation(); clearInterval(interval); cleanups.forEach(fn => fn()); assetPanel.destroy(); glassTuner.destroy(); glassLens.destroy(); speechCaption.destroy(); characterSwipe.destroy(); speaking.destroy(); characterCarousel.destroy(); flipClock.destroy(); audio.destroy(); } };
}
