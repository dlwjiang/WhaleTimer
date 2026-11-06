import { CHARACTER_CLIPS } from './voices.js';
import { warningSegments } from './warnings.js';
import { speechEnvelope } from './speech-envelope.js';

// Retain the original whale's tone; new characters have their own generated voices.
const VOICE_PROFILES = {
  whale: { low: -.5, presence: 1.2, high: .6 },
  claude: { low: 0, presence: 0, high: 0 },
  chatgpt: { low: 0, presence: 0, high: 0 },
};

/** Pre-generated local-model clips; no model service is needed at runtime. */
export function createAudio({ clips, characterClips = CHARACTER_CLIPS, fetcher = globalThis.fetch } = {}) {
  let context;
  let enabled = true;
  let disposed = false;
  let speechSource;
  let activeSpeech;
  let characterId = 'whale';
  let revision = 0;
  let clickRevision = 0;
  let voices = [];
  let speechActivity;
  const speechListeners = new Set();
  const envelopes = new WeakMap();
  const pendingFiles = new Map();
  const decodedFiles = new Map();
  const bellTones = new Set();
  const abortController = new AbortController();
  const synth = globalThis.speechSynthesis;
  const AudioContext = globalThis.AudioContext || globalThis.webkitAudioContext;
  const loadVoices = () => { voices = synth?.getVoices() ?? []; };
  const base = import.meta.env?.BASE_URL ?? '/';
  loadVoices();
  synth?.addEventListener('voiceschanged', loadVoices);

  function notifySpeech() {
    for (const listener of speechListeners) {
      try { listener(); } catch { /* Animation cannot interrupt audio. */ }
    }
  }

  function fetchClip(file) {
    if (!pendingFiles.has(file)) {
      const request = Promise.resolve().then(async () => {
        if (!fetcher) throw new Error('Audio loading is unavailable.');
        const response = await fetcher(`${base}voice/${file}`, { signal: abortController.signal });
        if (!response.ok) throw new Error(`Audio unavailable: ${response.status}`);
        return response.arrayBuffer();
      }).catch(error => { pendingFiles.delete(file); throw error; });
      pendingFiles.set(file, request);
    }
    return pendingFiles.get(file);
  }

  // Preload files silently. The first user gesture unlocks the audio context.
  const clipsFor = id => clips ?? characterClips[id] ?? characterClips.whale;
  function preloadVoice() {
    if (AudioContext && !disposed) Object.values(clipsFor(characterId)).forEach(file => { void fetchClip(file).catch(() => {}); });
  }
  preloadVoice();

  function unlock() {
    if (!enabled || disposed) return;
    try {
      if (AudioContext && !context) {
        context = new AudioContext();
        context.addEventListener?.('statechange', notifySpeech);
      }
      const resuming = context?.resume();
      resuming?.catch(() => {});
      return resuming;
    } catch { /* Captions and browser speech remain available. */ }
  }

  function stopSpeech() {
    revision += 1;
    // Settle before stopping: browsers may fire ended synchronously, later, or
    // not at all after cancellation. A cancelled utterance never finishes true.
    activeSpeech?.finish(false);
    if (speechSource) {
      const previous = speechSource;
      speechSource = undefined;
      try { previous.stop(); } catch { /* The source may already have ended. */ }
      previous.disconnect();
    }
    try { synth?.cancel(); } catch { /* Completion has already been cancelled. */ }
  }

  function silence() {
    clickRevision += 1;
    stopSpeech();
    for (const { oscillator, gain } of bellTones) {
      try { oscillator.stop(); } catch { /* Already ended. */ }
      oscillator.disconnect();
      gain.disconnect();
    }
    bellTones.clear();
  }

  // Weighted switch: low body, audible midrange knock, and a broadband snap.
  // Fast pitch drops remove the musical ring; the bass decays without a hard cut.
  async function click(action) {
    if (!enabled || disposed) return;
    const request = ++clickRevision;
    await unlock();
    if (!enabled || disposed || request !== clickRevision || context?.state !== 'running') return;
    const start = context.currentTime;
    // [initial Hz, settled Hz, peak, decay seconds, delay, waveform]
    const layers = action === 'play'
      ? [[145, 72, .34, .16, 0, 'sine'], [480, 220, .28, .075, 0, 'triangle'], [1800, 850, .12, .022, .014, 'square']]
      : [[185, 90, .34, .18, 0, 'sine'], [620, 280, .28, .085, 0, 'triangle'], [2400, 1100, .12, .018, 0, 'square']];
    try {
      for (const [frequency, settledFrequency, volume, duration, delay, type] of layers) {
        const oscillator = context.createOscillator();
        const gain = context.createGain();
        oscillator.type = type;
        oscillator.frequency.setValueAtTime(frequency, start + delay);
        oscillator.frequency.exponentialRampToValueAtTime(settledFrequency, start + delay + Math.min(.025, duration * .5));
        gain.gain.setValueAtTime(0, start + delay);
        gain.gain.linearRampToValueAtTime(volume, start + delay + .0005);
        gain.gain.setValueAtTime(volume, start + delay + .003);
        gain.gain.exponentialRampToValueAtTime(.0001, start + delay + duration);
        oscillator.connect(gain);
        gain.connect(context.destination);
        const tone = { oscillator, gain };
        bellTones.add(tone);
        oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); bellTones.delete(tone); };
        oscillator.start(start + delay);
        oscillator.stop(start + delay + duration + .01);
      }
      // A crisp, non-tonal impact makes the contact audible on phone speakers.
      const rate = context.sampleRate || 44100;
      const duration = action === 'play' ? .028 : .022;
      const buffer = context.createBuffer(1, Math.ceil(rate * duration), rate);
      const samples = buffer.getChannelData(0);
      let seed = 731;
      let previous = 0;
      for (let i = 0; i < samples.length; i++) {
        seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
        const noise = seed / 2147483648 - 1;
        samples[i] = (noise - previous) * .5;
        previous = noise;
      }
      const oscillator = context.createBufferSource();
      const gain = context.createGain();
      oscillator.buffer = buffer;
      gain.gain.setValueAtTime(0, start);
      gain.gain.linearRampToValueAtTime(.24, start + .0003);
      gain.gain.setValueAtTime(.24, start + .002);
      gain.gain.exponentialRampToValueAtTime(.0001, start + duration);
      oscillator.connect(gain);
      gain.connect(context.destination);
      const tone = { oscillator, gain };
      bellTones.add(tone);
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); bellTones.delete(tone); };
      oscillator.start(start);
      oscillator.stop(start + duration);
    } catch { /* Feedback must never interfere with the timer. */ }
  }

  function bell() {
    if (!enabled || disposed) return;
    unlock();
    if (!context || context.state !== 'running') return;
    const start = context.currentTime;
    for (const delay of [0, 0.26]) {
      for (const [frequency, volume] of [[1175, 0.11], [2350, 0.035], [3525, 0.015]]) {
        const oscillator = context.createOscillator();
        const gain = context.createGain();
        oscillator.type = 'sine';
        oscillator.frequency.value = frequency;
        gain.gain.setValueAtTime(0, start + delay);
        gain.gain.linearRampToValueAtTime(volume, start + delay + 0.005);
        gain.gain.exponentialRampToValueAtTime(0.0001, start + delay + 1.5);
        oscillator.connect(gain);
        gain.connect(context.destination);
        const tone = { oscillator, gain };
        bellTones.add(tone);
        oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); bellTones.delete(tone); };
        oscillator.start(start + delay);
        oscillator.stop(start + delay + 1.6);
      }
    }
  }

  function connectVoice(source, profile) {
    const nodes = [];
    try {
      for (const [type, frequency, gain] of [
        ['lowshelf', 320, profile.low],
        ['peaking', 2400, profile.presence],
        ['highshelf', 4800, profile.high],
      ]) {
        const filter = context.createBiquadFilter();
        nodes.push(filter);
        filter.type = type;
        filter.frequency.value = frequency;
        filter.Q.value = .7;
        filter.gain.value = gain;
      }
      const output = context.createGain();
      nodes.push(output);
      output.gain.value = .8; // Headroom for the small tone boosts.
      source.connect(nodes[0]);
      nodes.forEach((node, index) => node.connect(nodes[index + 1] ?? context.destination));
    } catch {
      source.disconnect();
      nodes.forEach(node => node.disconnect());
      nodes.length = 0;
      source.connect(context.destination); // Playback still works without effects.
    }
    return () => { nodes.splice(0).forEach(node => node.disconnect()); };
  }

  function fallbackSpeech(text, onEnd, onError, onStart) {
    if (!synth || !globalThis.SpeechSynthesisUtterance) return false;
    try {
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'zh-CN';
      utterance.voice = voices.find(v => /zh[-_]CN|cmn/i.test(v.lang)) ?? voices.find(v => /^zh/i.test(v.lang)) ?? null;
      utterance.rate = 1.05;
      utterance.pitch = 1.2;
      utterance.onstart = onStart;
      utterance.onend = onEnd;
      utterance.onerror = onError;
      synth.speak(utterance);
      return true;
    } catch { return false; }
  }

  /** By default resolves at playback start; waitUntilEnd resolves at natural end. */
  function speak(text, { waitUntilEnd = false, onStart } = {}) {
    if (!enabled || disposed) return Promise.resolve(false);
    stopSpeech();
    const requestRevision = revision;
    const speakingCharacter = characterId;
    const profile = VOICE_PROFILES[characterId];
    const selectedClips = clipsFor(characterId);
    let releaseEffects = () => {};
    const notifyStart = info => { if (current()) { try { onStart?.(info); } catch { /* UI callbacks must not interrupt speech. */ } } };
    const current = () => enabled && !disposed && requestRevision === revision;
    let resolve;
    let settled = false;
    const completion = new Promise(done => { resolve = done; });
    const settle = value => {
      if (!settled) { settled = true; resolve(value); }
    };
    const request = {
      finish(value) {
        releaseEffects();
        settle(value);
        if (speechActivity?.request === request) {
          speechActivity = undefined;
          notifySpeech();
        }
        if (activeSpeech === request) activeSpeech = undefined;
      },
    };
    activeSpeech = request;

    async function play() {
      const resuming = unlock();
      const segments = warningSegments(text);
      const files = selectedClips[text] ? [selectedClips[text]] : segments?.map(segment => selectedClips[segment]);
      if (files?.length && files.every(Boolean) && context) {
        let source;
        try {
          await resuming;
          if (!current()) { request.finish(false); return; }
          if (context.state !== 'running') throw new Error('Audio needs a user gesture.');
          const buffers = await Promise.all(files.map(async file => {
            let buffer = decodedFiles.get(file);
            if (!buffer) {
              const bytes = await fetchClip(file);
              buffer = await context.decodeAudioData(bytes.slice(0));
              if (!disposed) decodedFiles.set(file, buffer);
            }
            return buffer;
          }));
          if (!current()) { request.finish(false); return; }
          let buffer = buffers[0];
          if (buffers.length > 1) {
            // Join before playing so a composed warning has one end event and
            // cancels as one utterance, just like a complete recording.
            const channels = Math.max(...buffers.map(part => part.numberOfChannels));
            buffer = context.createBuffer(channels, buffers.reduce((sum, part) => sum + part.length, 0), buffers[0].sampleRate);
            let offset = 0;
            for (const part of buffers) {
              for (let channel = 0; channel < channels; channel++) {
                buffer.getChannelData(channel).set(part.getChannelData(Math.min(channel, part.numberOfChannels - 1)), offset);
              }
              offset += part.length;
            }
          }
          source = context.createBufferSource();
          source.buffer = buffer;
          releaseEffects = connectVoice(source, profile);
          source.onended = () => {
            source.disconnect();
            if (speechSource === source) speechSource = undefined;
            request.finish(current());
          };
          speechSource = source;
          let envelope = envelopes.get(buffer);
          if (!envelope) { envelope = speechEnvelope(buffer); envelopes.set(buffer, envelope); }
          const startedAt = context.currentTime;
          source.start();
          speechActivity = { request, character: speakingCharacter, sample: () => envelope(context.currentTime - startedAt) };
          notifySpeech();
          notifyStart({ elapsedMs: () => Math.max(0, (context.currentTime - startedAt) * 1000) });
          if (!waitUntilEnd) settle(true);
          return;
        } catch {
          releaseEffects();
          // Missing files/codec or a failed start can still use browser speech.
          if (source) {
            source.onended = null;
            try { source.disconnect(); } catch { /* Not connected. */ }
            if (speechSource === source) speechSource = undefined;
          }
        }
      }
      if (!current()) { request.finish(false); return; }
      const started = fallbackSpeech(text, () => request.finish(current()), () => request.finish(false), () => notifyStart());
      if (!started) request.finish(false);
      else if (!waitUntilEnd) settle(true);
    }

    // Cancellation settles completion independently of an unresolved fetch,
    // decode, or context.resume(). Their later callbacks are generation-guarded.
    void play().catch(() => request.finish(false));
    return completion;
  }

  return {
    unlock, bell, speak, click,
    getSpeechFrame() {
      if (!speechActivity || context?.state !== 'running') return { active: false, level: 0 };
      return { active: true, character: speechActivity.character, level: speechActivity.sample() };
    },
    subscribeSpeech(listener) {
      speechListeners.add(listener);
      return () => speechListeners.delete(listener);
    },
    setCharacter(id) {
      characterId = Object.hasOwn(VOICE_PROFILES, id) ? id : 'whale';
      preloadVoice();
    },
    get supported() { return Boolean(AudioContext || (synth && globalThis.SpeechSynthesisUtterance)); },
    setEnabled(value) {
      enabled = value;
      if (!enabled) {
        silence();
        context?.suspend().catch(() => {});
      }
    },
    silence,
    destroy() {
      disposed = true;
      silence();
      speechListeners.clear();
      abortController.abort();
      synth?.removeEventListener('voiceschanged', loadVoices);
      context?.removeEventListener?.('statechange', notifySpeech);
      context?.close().catch(() => {});
      pendingFiles.clear();
      decodedFiles.clear();
    },
  };
}
