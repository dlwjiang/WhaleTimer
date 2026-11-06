import { CHARACTER_CLIPS } from './voices.js';
import { warningSegments } from './warnings.js';

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
  let voices = [];
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
      if (AudioContext && !context) context = new AudioContext();
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
    stopSpeech();
    for (const { oscillator, gain } of bellTones) {
      try { oscillator.stop(); } catch { /* Already ended. */ }
      oscillator.disconnect();
      gain.disconnect();
    }
    bellTones.clear();
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
          const startedAt = context.currentTime;
          source.start();
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
    unlock, bell, speak,
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
      abortController.abort();
      synth?.removeEventListener('voiceschanged', loadVoices);
      context?.close().catch(() => {});
      pendingFiles.clear();
      decodedFiles.clear();
    },
  };
}
