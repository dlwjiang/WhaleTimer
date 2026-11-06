import test from 'node:test';
import assert from 'node:assert/strict';
import { createAudio } from '../src/audio.js';

function setup(t, options = {}) {
  const old = Object.fromEntries(['AudioContext', 'speechSynthesis', 'SpeechSynthesisUtterance'].map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]));
  const sources = [];
  const spoken = [];
  const contexts = [];
  const tones = [];
  const filters = [];
  const gains = [];
  let decoding = 0;
  class Context {
    state = 'suspended';
    destination = {};
    currentTime = 0;
    constructor() { contexts.push(this); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
    async close() { this.state = 'closed'; }
    async decodeAudioData(bytes) { decoding++; return options.decode ? options.decode(bytes) : this.createBuffer(1, bytes.byteLength, 24000); }
    createBuffer(channels, length, sampleRate) {
      const data = Array.from({ length: channels }, () => new Float32Array(length));
      return { length, sampleRate, numberOfChannels: channels, getChannelData: channel => data[channel] };
    }
    createOscillator() {
      const tone = { frequency: {}, connect() {}, disconnect() {}, start() {}, stop(at) { if (at === undefined) this.cancelled = true; } };
      tones.push(tone);
      return tone;
    }
    createGain() {
      const node = { connect(target) { this.target = target; }, disconnect() { this.disconnected = true; }, gain: { setValueAtTime() {}, linearRampToValueAtTime() {}, exponentialRampToValueAtTime() {} } };
      gains.push(node);
      return node;
    }
    createBiquadFilter() {
      if (options.effectsFail) throw new Error('Effects unavailable');
      const node = { frequency: {}, Q: {}, gain: {}, connect(target) { this.target = target; }, disconnect() { this.disconnected = true; } };
      filters.push(node);
      return node;
    }
    createBufferSource() {
      const source = { playbackRate: { value: 1 }, detune: { value: 0 }, connect(target) { this.target = target; }, disconnect() {}, start() { this.started = true; }, stop() { this.stopped = true; } };
      sources.push(source);
      return source;
    }
  }
  globalThis.AudioContext = Context;
  globalThis.SpeechSynthesisUtterance = class { constructor(text) { this.text = text; } };
  globalThis.speechSynthesis = {
    getVoices: () => [{ lang: 'zh-CN', name: 'Mandarin fallback' }],
    addEventListener() {}, removeEventListener() {}, cancel() {},
    speak: utterance => spoken.push(utterance),
  };
  let fetchCount = 0;
  const audio = createAudio({ clips: options.characterClips ? undefined : options.clips ?? { '开始啦': 'start.m4a', '快一点': 'nudge.m4a' }, characterClips: options.characterClips, fetcher: async (...args) => {
    fetchCount++;
    return options.fetcher ? options.fetcher(...args) : { ok: true, arrayBuffer: async () => new ArrayBuffer(4) };
  } });
  t.after(() => {
    audio.destroy();
    for (const key of Object.keys(old)) {
      if (old[key]) Object.defineProperty(globalThis, key, old[key]);
      else delete globalThis[key];
    }
  });
  return { audio, sources, contexts, spoken, tones, filters, gains, get fetchCount() { return fetchCount; }, get decoding() { return decoding; } };
}

test('muting cancels bell tones so enabling sound cannot resume an old chime', async t => {
  const env = setup(t);
  await env.audio.unlock();
  env.audio.bell();
  assert.equal(env.tones.length, 6);
  env.audio.setEnabled(false);
  assert.equal(env.tones.every(tone => tone.cancelled), true);
  env.audio.setEnabled(true);
  await env.audio.unlock();
  assert.equal(env.tones.length, 6);
});

test('bundled voice starts after gesture unlock, caches decoded audio, and replaces earlier speech', async t => {
  const env = setup(t);
  assert.equal(env.contexts.length, 0, 'preloading does not create an autoplay context');
  assert.equal(await env.audio.speak('开始啦'), true);
  assert.equal(env.sources[0].started, true);
  assert.equal(env.spoken.length, 0, 'local recording takes precedence over system voice');
  assert.equal(await env.audio.speak('开始啦'), true);
  assert.equal(env.sources[0].stopped, true);
  assert.equal(env.decoding, 1);
  assert.equal(env.fetchCount, 2, 'each of the two files is preloaded once');
  env.audio.setEnabled(false);
  assert.equal(env.sources[1].stopped, true);
  assert.equal(await env.audio.speak('快一点'), false);
});

test('pause or reset cancels pending decoded speech before it can play', async t => {
  let release;
  const decoding = new Promise(resolve => { release = resolve; });
  const env = setup(t, { decode: () => decoding });
  const pending = env.audio.speak('开始啦');
  await new Promise(resolve => setImmediate(resolve));
  env.audio.silence();
  release({ length: 4 });
  assert.equal(await pending, false);
  assert.equal(env.sources.length, 0);
  assert.equal(env.spoken.length, 0);
});

test('a newer reminder wins even if an earlier file finishes loading later', async t => {
  let release;
  const held = new Promise(resolve => { release = resolve; });
  const env = setup(t, { fetcher: async url => ({ ok: true, arrayBuffer: async () => url.endsWith('start.m4a') ? held : new ArrayBuffer(8) }) });
  const first = env.audio.speak('开始啦');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(await env.audio.speak('快一点'), true);
  release(new ArrayBuffer(4));
  assert.equal(await first, false);
  assert.equal(env.sources.length, 1);
  assert.equal(env.sources[0].buffer.length, 8);
});

test('missing or undecodable recording uses Mandarin browser fallback', async t => {
  const env = setup(t, { fetcher: async () => ({ ok: false, status: 404 }) });
  assert.equal(await env.audio.speak('开始啦'), true);
  assert.equal(env.sources.length, 0);
  assert.equal(env.spoken[0].text, '开始啦');
  assert.equal(env.spoken[0].voice.lang, 'zh-CN');
  env.audio.setEnabled(false);
  assert.equal(await env.audio.speak('快一点'), false);
  assert.equal(env.spoken.length, 1);
});

test('destroy prevents a pending load from playing or falling back', async t => {
  let release;
  const held = new Promise(resolve => { release = resolve; });
  const env = setup(t, { fetcher: async () => { await held; return { ok: false, status: 404 }; } });
  const pending = env.audio.speak('开始啦');
  await new Promise(resolve => setImmediate(resolve));
  env.audio.destroy();
  release();
  assert.equal(await pending, false);
  assert.equal(env.sources.length, 0);
  assert.equal(env.spoken.length, 0);
});

test('higher warning numbers join recorded fragments as one cancellable utterance', async t => {
  const env = setup(t, { clips: {
    '超时了，这是第': 'prefix.m4a', '一': 'one.m4a', '十': 'ten.m4a', '次警告！': 'suffix.m4a',
  } });
  assert.equal(await env.audio.speak('超时了，这是第十一次警告！'), true);
  assert.equal(env.spoken.length, 0, 'same voice recordings, not system TTS');
  assert.equal(env.sources.length, 1);
  assert.equal(env.sources[0].buffer.length, 16);
  env.audio.silence();
  assert.equal(env.sources[0].stopped, true);
});

test('a complete warning recording takes priority over composable fragments', async t => {
  const env = setup(t, { clips: {
    '超时了，这是第一次警告！': 'warning-1.m4a',
    '超时了，这是第': 'prefix.m4a', '一': 'one.m4a', '次警告！': 'suffix.m4a',
  } });
  assert.equal(await env.audio.speak('超时了，这是第一次警告！'), true);
  assert.equal(env.sources[0].buffer.length, 4);
  assert.equal(env.decoding, 1);
});

test('waitUntilEnd stays pending after a recording starts and succeeds only at natural end', async t => {
  const env = setup(t);
  let result;
  const completion = env.audio.speak('开始啦', { waitUntilEnd: true }).then(value => { result = value; return value; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(env.sources[0].started, true);
  assert.equal(result, undefined, 'starting playback is not completion');
  env.sources[0].onended();
  assert.equal(await completion, true);
  env.audio.silence();
  assert.equal(result, true, 'later cancellation does not change a completed result');
});

for (const action of ['silence', 'mute', 'destroy']) {
  test(`${action} settles an active recording wait even when stop never fires ended`, async t => {
    const env = setup(t);
    const completion = env.audio.speak('开始啦', { waitUntilEnd: true });
    await new Promise(resolve => setImmediate(resolve));
    if (action === 'mute') env.audio.setEnabled(false);
    else env.audio[action]();
    assert.equal(await completion, false);
    assert.equal(env.sources[0].stopped, true);
    env.sources[0].onended();
    assert.equal(await completion, false, 'late ended cannot turn cancellation into success');
  });
}

test('silence settles a wait while loading without waiting for the network or decoding', async t => {
  let release;
  const loading = new Promise(resolve => { release = resolve; });
  const env = setup(t, { fetcher: async () => { await loading; return { ok: true, arrayBuffer: async () => new ArrayBuffer(4) }; } });
  const completion = env.audio.speak('开始啦', { waitUntilEnd: true });
  await new Promise(resolve => setImmediate(resolve));
  env.audio.silence();
  assert.equal(await completion, false, 'cancellation resolves before loading is released');
  release();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(env.sources.length, 0);
});

test('replacing a waited recording cancels it and its stale ended cannot clear newer speech', async t => {
  const env = setup(t);
  const first = env.audio.speak('开始啦', { waitUntilEnd: true });
  await new Promise(resolve => setImmediate(resolve));
  const oldSource = env.sources[0];
  const second = env.audio.speak('快一点', { waitUntilEnd: true });
  assert.equal(await first, false);
  await new Promise(resolve => setImmediate(resolve));
  oldSource.onended();
  env.audio.silence();
  assert.equal(await second, false);
  assert.equal(env.sources[1].stopped, true, 'new source remains owned after the old end event');
});

test('waitUntilEnd also waits for fallback TTS end and reports speech errors', async t => {
  const env = setup(t, { fetcher: async () => ({ ok: false, status: 404 }) });
  let result;
  const completion = env.audio.speak('开始啦', { waitUntilEnd: true }).then(value => { result = value; return value; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(env.spoken.length, 1);
  assert.equal(result, undefined);
  env.spoken[0].onend();
  assert.equal(await completion, true);
  const failed = env.audio.speak('没有录音的文字', { waitUntilEnd: true });
  env.spoken[1].onerror({ error: 'synthesis-failed' });
  assert.equal(await failed, false);
});

test('cancelled TTS settles without an end event and stale callbacks preserve the next wait', async t => {
  const env = setup(t);
  const first = env.audio.speak('第一句', { waitUntilEnd: true });
  const second = env.audio.speak('第二句', { waitUntilEnd: true });
  assert.equal(await first, false);
  env.spoken[0].onend();
  env.spoken[0].onerror({ error: 'canceled' });
  env.audio.silence();
  assert.equal(await second, false);
  const third = env.audio.speak('第三句', { waitUntilEnd: true });
  env.spoken[2].onend();
  assert.equal(await third, true);
});

test('waitUntilEnd returns false when no playback route is available or sound is disabled', async t => {
  const env = setup(t);
  delete globalThis.SpeechSynthesisUtterance;
  assert.equal(await env.audio.speak('没有录音的文字', { waitUntilEnd: true }), false);
  env.audio.setEnabled(false);
  assert.equal(await env.audio.speak('开始啦', { waitUntilEnd: true }), false);
  env.audio.destroy();
  assert.equal(await env.audio.speak('开始啦', { waitUntilEnd: true }), false);
});


test('character effects reuse decoded recordings and preserve playback rate and completion', async t => {
  const env = setup(t);
  const profiles = [];
  for (const character of ['whale', 'claude', 'chatgpt']) {
    env.audio.setCharacter(character);
    const completion = env.audio.speak('开始啦', { waitUntilEnd: true });
    await new Promise(resolve => setImmediate(resolve));
    const source = env.sources.at(-1);
    const graph = env.filters.slice(-3);
    profiles.push(graph.map(node => node.gain.value));
    assert.equal(source.target, graph[0]);
    assert.equal(source.playbackRate.value, 1);
    assert.equal(source.detune.value, 0);
    source.onended();
    assert.equal(await completion, true);
    assert.ok(graph.every(node => node.disconnected));
    assert.equal(env.gains.at(-1).disconnected, true);
  }
  assert.equal(env.decoding, 1);
  assert.equal(env.fetchCount, 2);
  assert.ok(profiles[0][1] > profiles[1][1]);
  assert.deepEqual(profiles[1], [0, 0, 0]);
  assert.deepEqual(profiles[2], [0, 0, 0]);
});

test('distinct character recordings are selected and cached independently without interrupting active speech', async t => {
  const urls = [];
  const characterClips = Object.fromEntries(['whale', 'claude', 'chatgpt'].map(id => [id, { '开始啦': `${id}/start.m4a` }]));
  const env = setup(t, { characterClips, fetcher: async url => {
    urls.push(url);
    return { ok: true, arrayBuffer: async () => new ArrayBuffer(url.includes('claude') ? 8 : url.includes('chatgpt') ? 12 : 4) };
  } });
  await env.audio.speak('开始啦');
  const whale = env.sources.at(-1);
  env.audio.setCharacter('claude');
  assert.equal(whale.stopped, undefined);
  await env.audio.speak('开始啦');
  assert.equal(env.sources.at(-1).buffer.length, 8);
  env.audio.setCharacter('chatgpt');
  await env.audio.speak('开始啦');
  assert.equal(env.sources.at(-1).buffer.length, 12);
  env.audio.setCharacter('whale');
  await env.audio.speak('开始啦');
  assert.equal(env.sources.at(-1).buffer, whale.buffer);
  assert.equal(env.decoding, 3);
  assert.deepEqual(urls.sort(), ['/voice/chatgpt/start.m4a', '/voice/claude/start.m4a', '/voice/whale/start.m4a']);
});

test('composed warnings use only the selected character, including a switch during loading', async t => {
  let release;
  const held = new Promise(resolve => { release = resolve; });
  const parts = ['超时了，这是第', '十', '一', '次警告！'];
  const characterClips = Object.fromEntries(['whale', 'claude', 'chatgpt'].map(id => [id,
    Object.fromEntries(parts.map((text, index) => [text, `${id}/${index}.m4a`])),
  ]));
  const env = setup(t, { characterClips, fetcher: async url => ({ ok: true,
    arrayBuffer: async () => url.includes('claude') ? held : new ArrayBuffer(2),
  }) });
  env.audio.setCharacter('claude');
  const speech = env.audio.speak('超时了，这是第十一次警告！');
  env.audio.setCharacter('chatgpt');
  release(new ArrayBuffer(7));
  assert.equal(await speech, true);
  assert.equal(env.sources.at(-1).buffer.length, 28);
  await env.audio.speak('超时了，这是第十一次警告！');
  assert.equal(env.sources.at(-1).buffer.length, 8);
});

test('character changes affect the next phrase without interrupting the current one; mute releases effects', async t => {
  const env = setup(t);
  await env.audio.speak('开始啦');
  const first = env.sources[0];
  env.audio.setCharacter('claude');
  assert.equal(first.stopped, undefined);
  await env.audio.speak('快一点');
  assert.equal(first.stopped, true);
  assert.ok(env.filters.slice(0, 3).every(node => node.disconnected));
  env.audio.setEnabled(false);
  assert.ok(env.filters.every(node => node.disconnected));
  assert.ok(env.gains.every(node => node.disconnected));
});

test('effect failure plays the original clip and playback-start timing follows the audio clock', async t => {
  const env = setup(t, { effectsFail: true });
  let timing;
  assert.equal(await env.audio.speak('开始啦', { onStart: value => { timing = value; } }), true);
  assert.equal(env.sources[0].target, env.contexts[0].destination);
  assert.equal(env.spoken.length, 0);
  assert.equal(timing.elapsedMs(), 0);
  env.contexts[0].currentTime = .8;
  assert.equal(timing.elapsedMs(), 800);
});

test('speech activity follows PCM and the audio clock, retains its speaker, and cancels synchronously', async t => {
  const pcm = Float32Array.from({ length: 1000 }, (_, i) => i >= 100 && i < 500 ? .12 : 0);
  const env = setup(t, { decode: () => ({ length: pcm.length, sampleRate: 1000, numberOfChannels: 1, getChannelData: () => pcm }) });
  const notifications = [];
  const unsubscribe = env.audio.subscribeSpeech(() => notifications.push(env.audio.getSpeechFrame()));
  assert.deepEqual(env.audio.getSpeechFrame(), { active: false, level: 0 });
  await env.audio.speak('开始啦');
  assert.deepEqual(env.audio.getSpeechFrame(), { active: true, character: 'whale', level: 0 });
  env.contexts[0].currentTime = .2;
  assert.equal(env.audio.getSpeechFrame().level, 1);
  env.audio.setCharacter('claude');
  assert.equal(env.audio.getSpeechFrame().character, 'whale', 'switching companions does not give the new face the old voice');
  env.contexts[0].currentTime = .7;
  assert.equal(env.audio.getSpeechFrame().level, 0, 'silence inside a recording closes the mouth');
  const old = env.sources[0];
  await env.audio.speak('快一点');
  assert.equal(env.audio.getSpeechFrame().character, 'claude');
  old.onended();
  assert.equal(env.audio.getSpeechFrame().character, 'claude', 'stale ended cannot clear the new meter');
  env.audio.silence();
  assert.deepEqual(notifications.at(-1), { active: false, level: 0 });
  const count = notifications.length;
  unsubscribe();
  await env.audio.speak('开始啦');
  env.sources.at(-1).onended();
  assert.deepEqual(env.audio.getSpeechFrame(), { active: false, level: 0 });
  assert.equal(notifications.length, count);
});

test('bell tones, suspended audio and system speech never produce a fabricated PCM mouth signal', async t => {
  const env = setup(t);
  await env.audio.unlock(); env.audio.bell();
  assert.deepEqual(env.audio.getSpeechFrame(), { active: false, level: 0 });
  await env.audio.speak('开始啦');
  env.contexts[0].state = 'suspended';
  assert.equal(env.audio.getSpeechFrame().active, false);
  env.contexts[0].state = 'running';
  assert.equal(env.audio.getSpeechFrame().active, true);
  await env.audio.speak('没有本地录音');
  assert.equal(env.spoken.length, 1);
  assert.deepEqual(env.audio.getSpeechFrame(), { active: false, level: 0 });
  env.audio.setEnabled(false);
  assert.equal(env.audio.getSpeechFrame().active, false);
});
