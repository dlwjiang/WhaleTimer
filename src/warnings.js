const DIGITS = '零一二三四五六七八九';

/** Mandarin whole-number reading, including zeros between four-digit groups. */
export function chineseNumber(number) {
  if (!Number.isSafeInteger(number) || number < 1) throw new RangeError('Warning number must be a positive safe integer.');
  function small(value) {
    let result = '';
    let zero = false;
    for (const [place, unit] of [[1000, '千'], [100, '百'], [10, '十'], [1, '']]) {
      const digit = Math.floor(value / place) % 10;
      if (digit) {
        if (zero) result += '零';
        result += DIGITS[digit] + unit;
        zero = false;
      } else if (result) zero = true;
    }
    return result;
  }
  const groups = [];
  for (let remaining = number; remaining > 0; remaining = Math.floor(remaining / 10000)) groups.push(remaining % 10000);
  const units = ['', '万', '亿', '万亿'];
  let result = '';
  let zero = false;
  for (let index = groups.length - 1; index >= 0; index--) {
    const group = groups[index];
    if (!group) { if (result) zero = true; continue; }
    if (result && (zero || group < 1000)) result += '零';
    result += small(group) + units[index];
    zero = false;
  }
  return result.replace(/^一十/, '十');
}

export function warningText(number) {
  return `超时了，这是第${chineseNumber(number)}次警告！`;
}

/** Full recorded warnings are preferred; longer numbers use the same voice's tokens. */
export function warningSegments(text) {
  const match = /^超时了，这是第([零一二三四五六七八九十百千万亿]+)次警告！$/.exec(text);
  return match ? ['超时了，这是第', ...match[1], '次警告！'] : null;
}
