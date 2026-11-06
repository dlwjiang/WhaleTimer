import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { CHARACTERS, EXPRESSIONS, characterImage } from '../src/characters.js';

test('every companion ships six distinct expression assets with no idle substitution', () => {
  for (const character of CHARACTERS) {
    assert.deepEqual(Object.keys(character.images), EXPRESSIONS);
    const hashes = EXPRESSIONS.map(expression => {
      assert.ok(characterImage(character, expression).endsWith(`/${expression}.webp`));
      const bytes = readFileSync(new URL(`../public/${character.images[expression]}`, import.meta.url));
      assert.equal(bytes.toString('ascii', 8, 12), 'WEBP');
      return createHash('sha256').update(bytes).digest('hex');
    });
    assert.equal(new Set(hashes).size, 6, `${character.id} must have six different images`);
  }
});
