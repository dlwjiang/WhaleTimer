/** A 100 Hz RMS envelope of the actual PCM. No extra audio or analysis service. */
export function speechEnvelope(buffer) {
  const step = Math.max(1, Math.round(buffer.sampleRate / 100));
  const values = new Float32Array(Math.ceil(buffer.length / step));
  for (let channel = 0; channel < buffer.numberOfChannels; channel++) {
    const data = buffer.getChannelData(channel);
    for (let block = 0; block < values.length; block++) {
      let energy = 0;
      const start = block * step;
      const end = Math.min(start + step, data.length);
      for (let i = start; i < end; i++) energy += data[i] * data[i];
      values[block] = Math.max(values[block], Math.sqrt(energy / (end - start)));
    }
  }
  const voiced = [...values].filter(value => value > .008).sort((a, b) => a - b);
  const reference = Math.max(.04, voiced[Math.floor(voiced.length * .85)] ?? .04);
  return seconds => {
    if (!Number.isFinite(seconds) || seconds < 0) return 0;
    const rms = values[Math.floor(seconds * buffer.sampleRate / step)] ?? 0;
    return rms < .008 ? 0 : Math.min(1, rms / reference);
  };
}

/** Fast attack, short release and hysteresis avoid buzzing between drawings. */
export function createMouthMeter() {
  let level = 0;
  let shape = 0;
  return {
    update(input, elapsedMs = 16) {
      const target = Math.max(0, Math.min(1, input || 0));
      const time = Math.max(0, Math.min(100, elapsedMs));
      level += (target - level) * (1 - Math.exp(-time / (target > level ? 24 : 42)));
      if (level < .09) shape = 0;
      else if (level > .64) shape = 2;
      else if ((shape === 2 && level < .48) || (shape === 0 && level > .16)) shape = 1;
      return shape;
    },
    reset() { level = 0; shape = 0; },
  };
}
