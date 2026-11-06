import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { VOICE_SETS } from '../src/voices.js';

test('every character has a complete, distinct set of playable voice assets', () => {
  const hashesByLine = new Map();
  for (const voice of VOICE_SETS) {
    const manifest = JSON.parse(readFileSync(new URL(`../public/voice/${voice.directory}manifest.json`, import.meta.url)));
    assert.equal(manifest.clips.length, voice.clips.length);
    for (const clip of voice.clips) {
      const bytes = readFileSync(new URL(`../public/voice/${clip.file}`, import.meta.url));
      const record = manifest.clips.find(item => item.id === clip.id);
      assert.ok(record, `${voice.id}: ${clip.id}`);
      assert.equal(record.text, clip.text);
      assert.equal(record.bytes, bytes.length);
      assert.ok(record.duration > 0 && record.duration < 15);
      if (clip.id.startsWith('countdown-')) assert.ok(record.duration < .8);
      const hash = createHash('sha256').update(bytes).digest('hex');
      const previous = hashesByLine.get(clip.id) ?? new Set();
      assert.ok(!previous.has(hash), `${clip.id} must use a distinct recording for ${voice.id}`);
      previous.add(hash);
      hashesByLine.set(clip.id, previous);
    }
    const intro = manifest.clips.find(clip => clip.id === 'timer-start');
    assert.deepEqual(intro.assembly.map(part => part.at), [0, .8, 1.6, 2.4]);
    assert.ok(intro.duration <= 3.35, `${voice.id}: intro must fit the caption schedule`);
  }
});
