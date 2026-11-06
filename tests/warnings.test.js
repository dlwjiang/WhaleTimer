import test from 'node:test';
import assert from 'node:assert/strict';
import { chineseNumber, warningText, warningSegments } from '../src/warnings.js';

test('warning numbers use Mandarin ordinals through tens, hundreds and large groups', () => {
  for (const [number, expected] of [
    [1, '一'], [2, '二'], [9, '九'], [10, '十'], [11, '十一'], [20, '二十'],
    [21, '二十一'], [99, '九十九'], [100, '一百'], [101, '一百零一'], [110, '一百一十'],
    [1001, '一千零一'], [1010, '一千零一十'], [1100, '一千一百'],
    [10000, '一万'], [10001, '一万零一'], [10010, '一万零一十'],
    [11000, '一万一千'], [100000, '十万'], [100000001, '一亿零一'],
    [100010001, '一亿零一万零一'], [1000000000000, '一万亿'],
  ]) assert.equal(chineseNumber(number), expected, String(number));
  assert.equal(warningText(1), '超时了，这是第一次警告！');
  assert.equal(warningText(12), '超时了，这是第十二次警告！');
});

test('longer warnings split into reusable recorded speech in correct order', () => {
  assert.deepEqual(warningSegments(warningText(101)), ['超时了，这是第', '一', '百', '零', '一', '次警告！']);
  assert.equal(warningSegments('时间真的到了！我要生气啦！'), null);
  for (const invalid of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) assert.throws(() => warningText(invalid), RangeError);
});
