import test from 'node:test';
import assert from 'node:assert/strict';
import { speechEnvelope, createMouthMeter } from '../src/speech-envelope.js';

function buffer(channels, sampleRate = 1000) {
  return { sampleRate, length: channels[0].length, numberOfChannels: channels.length, getChannelData: i => channels[i] };
}

test('PCM envelope follows silence and syllables on the audio clock, including stereo', () => {
  const data = Float32Array.from({ length: 1000 }, (_, i) => i < 100 || i >= 700 ? 0 : i < 400 ? .03 : .12);
  const sample = speechEnvelope(buffer([new Float32Array(1000), data]));
  assert.equal(sample(0), 0);
  assert.equal(sample(.09), 0);
  assert.ok(Math.abs(sample(.2) - .25) < .001);
  assert.equal(sample(.5), 1);
  assert.equal(sample(.8), 0);
  assert.equal(sample(10), 0);
  assert.equal(sample(-1), 0);
  assert.equal(sample(NaN), 0);
});

test('quiet noise never opens the mouth and loudness normalization preserves quieter voices', () => {
  assert.equal(speechEnvelope(buffer([new Float32Array(100).fill(.004)]))(.02), 0);
  assert.equal(speechEnvelope(buffer([new Float32Array(100).fill(.06)]))(.02), 1);
  assert.equal(speechEnvelope(buffer([new Float32Array(100)]))(.02), 0);
});

test('mouth meter uses three shapes, smooths noisy thresholds and closes through a speech gap', () => {
  const meter = createMouthMeter();
  assert.equal(meter.update(0, 16), 0);
  assert.equal(meter.update(.35, 60), 1);
  assert.equal(meter.update(1, 60), 2);
  for (const input of [.60, .65, .61, .66]) assert.equal(meter.update(input, 16), 2);
  assert.equal(meter.update(0, 80), 1);
  assert.equal(meter.update(0, 80), 0);
  meter.update(1, 60); meter.reset();
  assert.equal(meter.update(0), 0);
});
